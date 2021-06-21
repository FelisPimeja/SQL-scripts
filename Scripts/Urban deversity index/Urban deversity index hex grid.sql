/* Индекс разнообразия среды (Urban Diversity (UD) Sub-Index) 
-- Ориентировочное время расчёта ~ 33 мин. на все города РФ.
-- Показывает функциональное разнообразие города
-- Считаем на сетке 500x500 м. Исходники - OSM, типология жилых кварталов, "благоустроенное озеленение"
-- см. CPI_Metadata 2016 стр. 99(101)
*/

-- Функция для генерации квадратной сетки (в итоге использованы гексагоны, см. ниже)
/* Функция для построения квадратной сетки на старых версиях PostGIS 
CREATE OR REPLACE FUNCTION public.makegrid_2d (
  bound_polygon public.geometry,
  grid_step integer,
  metric_srid integer = 28408 --metric SRID (this particular is optimal for the Western Russia)
)
RETURNS public.geometry AS
$body$
DECLARE
  BoundM public.geometry; --Bound polygon transformed to the metric projection (with metric_srid SRID)
  Xmin DOUBLE PRECISION;
  Xmax DOUBLE PRECISION;
  Ymax DOUBLE PRECISION;
  X DOUBLE PRECISION;
  Y DOUBLE PRECISION;
  sectors public.geometry[];
  i INTEGER;
BEGIN
  BoundM := ST_Transform($1, $3); --From WGS84 (SRID 4326) to the metric projection, to operate with step in meters
  Xmin := ST_XMin(BoundM);
  Xmax := ST_XMax(BoundM);
  Ymax := ST_YMax(BoundM);

  Y := ST_YMin(BoundM); --current sector's corner coordinate
  i := -1;
  <<yloop>>
  LOOP
    IF (Y > Ymax) THEN  --Better if generating polygons exceeds the bound for one step. You always can crop the result. But if not you may get not quite correct data for outbound polygons (e.g. if you calculate frequency per sector)
        EXIT;
    END IF;

    X := Xmin;
    <<xloop>>
    LOOP
      IF (X > Xmax) THEN
          EXIT;
      END IF;

      i := i + 1;
      sectors[i] := ST_GeomFromText('POLYGON(('||X||' '||Y||', '||(X+$2)||' '||Y||', '||(X+$2)||' '||(Y+$2)||', '||X||' '||(Y+$2)||', '||X||' '||Y||'))', $3);

      X := X + $2;
    END LOOP xloop;
    Y := Y + $2;
  END LOOP yloop;

  RETURN ST_Transform(ST_Collect(sectors), ST_SRID($1));
END;
$body$
LANGUAGE 'plpgsql';
*/


--Функция для генерации гексагональной сетки (пошла в итоговый вариант расчёта индекса)

/*
The default SRID is EPSG 3857 (web mercator -- https://epsg.io/3857). However
you can use any SRID you want. All input parameters should be interpreted as
coordinates and distances in whatever the SRID is set to.
SRID 3857 units are [very approximately] meters, and using this projection will
create hex cells that "look right" on a web map (most of which use a web mercator
projection).
If you have bounds in lat/lng degrees, you can convert those into web mercator.
To use EPSG 4326 (geodetic latitude and longitude -- https://epsg.io/4326)
degrees as the bounds, you can do the following:
    SELECT gid, ST_Transform(geom, 4326) AS geom
    FROM generate_hexgrid(
      -- Width of cell, in meters
      8192,
      -- Minimum x and y
      ST_X(ST_Transform(ST_SetSRID(ST_GeomFromText('POINT(-75.60447692871092 39.782685009007075)'), 4326), 3857)),
      ST_Y(ST_Transform(ST_SetSRID(ST_GeomFromText('POINT(-75.60447692871092 39.782685009007075)'), 4326), 3857)),
      -- Maximum x and y
      ST_X(ST_Transform(ST_SetSRID(ST_GeomFromText('POINT(-74.78736877441406 40.159459579477925)'), 4326), 3857)),
      ST_Y(ST_Transform(ST_SetSRID(ST_GeomFromText('POINT(-74.78736877441406 40.159459579477925)'), 4326), 3857)),
      -- The input SRID, default 3857
      3857
    );
The geometry returned from this function also uses EPSG 3857 coordinates, or
whatever the input SRID is, hence the use of an additional ST_Transform in the
SELECT above.
The gid should be unique for (and characteristic to) each cell. In other words,
If you run this function twice with two distinct but overlapping bounding boxes
using the same cell width, the cells that overlap should have the same gid. So,
if you INSERT these cells into a table with a unique gid column, you should be
able to ignore conflicts (ON CONFLICT DO NOTHING).
Adapted from http://rexdouglass.com/spatial-hexagon-binning-in-postgis/
Snapping inspired by https://medium.com/@goldrydigital/hex-grid-algorithm-for-postgis-4ac45f61d093
*/

/*CREATE OR REPLACE FUNCTION generate_hexgrid(width float, xmin float, ymin float, xmax float, ymax float, srid int default 3857)
RETURNS TABLE(
  gid text,
  geom geometry(Polygon)
) AS $grid$
declare
  b float := width / 2;
  a float := tan(radians(30)) * b;  -- tan(30) = 0.577350269
  c float := 2 * a;

  -- NOTE: The height of one cell is (2a + c), or about 1.154700538 * width.
  --       however, for each row, we shift vertically by (2[a + c]) to properly
  --       tesselate the hexagons. Thus, to determine the number of rows needed,
  --       we use the latter formula as the height of a row.
  height float := 2 * (a + c);

  -- Snap the min/max coords to a global grid according to the cell width, so
  -- that we minimize the chances of generating misaligned grids for overlapping
  -- regions.
  index_xmin int := floor(xmin / width);
  index_ymin int := floor(ymin / height);
  index_xmax int := ceil(xmax / width);
  index_ymax int := ceil(ymax / height);

  snap_xmin float := index_xmin * width;
  snap_ymin float := index_ymin * height;
  snap_xmax float := index_xmax * width;
  snap_ymax float := index_ymax * height;

  -- Calculate the total number of columns and rows. Note that the number of
  -- rows is actually half the number of rows, since each vertical iteration
  -- accounts for two "rows".
  ncol int := abs(index_xmax - index_xmin);
  nrow int := abs(index_ymax - index_ymin);

  polygon_string varchar := 'POLYGON((' ||
                                      0 || ' ' || 0         || ' , ' ||
                                      b || ' ' || a         || ' , ' ||
                                      b || ' ' || a + c     || ' , ' ||
                                      0 || ' ' || a + c + a || ' , ' ||
                                 -1 * b || ' ' || a + c     || ' , ' ||
                                 -1 * b || ' ' || a         || ' , ' ||
                                      0 || ' ' || 0         ||
                              '))';
BEGIN
  RETURN QUERY
  SELECT

    -- gid is made of the global x index of the cell, the global y index of the
    -- cell, and the cell width.
    format('%s %s %s',
           width,
           x_offset + (1 * x_series + index_xmin),
           y_offset + (2 * y_series + index_ymin)),

    -- geom is transformed using the width and height of a series, and set to
    -- the SRID specified.
    ST_SetSRID(ST_Translate(two_hex.geom,
                            x_series * width + snap_xmin,
                            y_series * height + snap_ymin), srid)

  FROM
    generate_series(0, ncol, 1) AS x_series,
    generate_series(0, nrow, 1) AS y_series,

    -- two_hex is a pair of hex cells, one roughly below the other. Thus, both
    -- have an x_offset of 0, but the second has a y_offset of 1.
    (
      -- Series cell #1
      SELECT
        0 AS x_offset,
        0 AS y_offset,
        polygon_string::geometry AS geom

      UNION
      
       -- Series cell #2
      SELECT
        0 AS x_offset,
        1 AS y_offset,
        ST_Translate(polygon_string::geometry, b , a + c)  AS geom
    ) AS two_hex;
END;
$grid$ LANGUAGE plpgsql;
*/


/* Выбираем город(а) */
drop table if exists t_city;
create temp table t_city as select * from russia.city
--where id_gis <= 500 -- дебаг
;
create index on t_city(id_gis);
create index on t_city using gist(geom);
;
/* Генерируем гексагональную сетку на выбранный город(а) */
drop table if exists grid_f;
create temp table grid_f as 
select (row_number() over())::int id, b.id_gis, st_transform(g.geom, 4326) geom
from t_city b
left join lateral generate_hexgrid(
--	268.6425, -- высота гексагона, площадь которого соответствует квадрату со стороной 250 м.
	537.2850, -- высота гексагона, площадь которого соответствует квадрату со стороной 250 м.
	(select st_xmin(st_transform(geom, ('326' || utm_zone)::int)) from t_city where id_gis = b.id_gis),
	(select st_ymin(st_transform(geom, ('326' || utm_zone)::int)) from t_city where id_gis = b.id_gis),
	(select st_xmax(st_transform(geom, ('326' || utm_zone)::int)) from t_city where id_gis = b.id_gis),
	(select st_ymax(st_transform(geom, ('326' || utm_zone)::int)) from t_city where id_gis = b.id_gis),
	(select ('326' || utm_zone)::int from t_city where id_gis = b.id_gis)
) g on true;
create index on grid_f using gist(geom);
create index on grid_f(id_gis)
;
/* Выбираем из сетки всё, что лежит в границах города */
drop table if exists grid;
create temp table grid as
select g.* 
from t_city b 
left join grid_f g
	on g.id_gis = b.id_gis
		and st_intersects(g.geom, b.geom)
;
create index on grid(id_gis);
create index on grid using gist(geom)
;
/* Расчёт разнообразия в ячейках */
drop table if exists russia.urban_diversity_index;
create table russia.urban_diversity_index as
select 
	*,
	round(-1 * (residential_share * coalesce(ln(nullif(residential_share, 0)), 0) + commercial_share * coalesce(ln(nullif(commercial_share, 0)), 0) + industrial_share * coalesce(ln(nullif(industrial_share, 0)), 0) + public_facilities_share * coalesce(ln(nullif(public_facilities_share, 0)), 0) + public_spaces_share * coalesce(ln(nullif(public_spaces_share, 0)), 0)), 3) urban_diversity_index
from (
	select
		*,
		coalesce(round(residential_area_ha / nullif(total_area_used_ha, 0), 2), 0) residential_share,
		coalesce(round(commercial_area_ha / nullif(total_area_used_ha, 0), 2), 0) commercial_share,
		coalesce(round(industrial_area_ha / nullif(total_area_used_ha, 0), 2), 0) industrial_share,
		coalesce(round(public_facilities_area_ha / nullif(total_area_used_ha, 0), 2), 0) public_facilities_share,
		coalesce(round(public_spaces_area_ha / nullif(total_area_used_ha, 0), 2), 0) public_spaces_share
	from (
		select
			g.*,
			coalesce(round((sum(st_area(st_intersection(g.geom, l.geom)::geography)) filter(where l.class = 'residential'      ))::numeric / 10000, 2), 0) residential_area_ha,
			coalesce(round((sum(st_area(st_intersection(g.geom, l.geom)::geography)) filter(where l.class = 'commercial'       ))::numeric / 10000, 2), 0) commercial_area_ha,
			coalesce(round((sum(st_area(st_intersection(g.geom, l.geom)::geography)) filter(where l.class = 'industrial'       ))::numeric / 10000, 2), 0) industrial_area_ha,
			coalesce(round((sum(st_area(st_intersection(g.geom, l.geom)::geography)) filter(where l.class = 'public facilities'))::numeric / 10000, 2), 0) public_facilities_area_ha,
			coalesce(round((sum(st_area(st_intersection(g.geom, l.geom)::geography)) filter(where l.class = 'public spaces'    ))::numeric / 10000, 2), 0) public_spaces_area_ha,
			coalesce(round(st_area(g.geom::geography)::numeric / 10000), 0) total_area_ha,
			coalesce(round((sum(st_area(st_intersection(g.geom, l.geom)::geography)))::numeric / 10000, 2), 0) total_area_used_ha			
		from grid g
		left join russia.urban_diversity_landuse l 
			on g.id_gis = l.id_gis 
				and st_intersects(g.geom, l.geom)
		group by g.id, g.id_gis, g.geom
	) s
) s
;
/* Индексы */
create index on russia.urban_diversity_index(id_gis);
create index on russia.urban_diversity_index(urban_diversity_index);
create index on russia.urban_diversity_index using gist(geom)
;
comment on table russia.urban_diversity_index is 'Индекс разнообразия городской среды (Urban Diversity (UD) Sub-Index). 
Показывает функциональное разнообразие города.
Считаем на гексагонах высотой 537.2850 м (площадью 25 га).
Исходники - OSM, типология жилых кварталов, "благоустроенное озеленение"
-- см. CPI_Metadata 2016 стр. 99(101)';
comment on column russia.urban_diversity_index.id is 'Первичный ключ (сквозной, наследован от изначальной таблицы гексагонов)';
comment on column russia.urban_diversity_index.id_gis is 'id_gis города';
comment on column russia.urban_diversity_index.geom is 'Геометрия';
comment on column russia.urban_diversity_index.residential_area_ha is 'Суммарная площадь жилой зоны в границах ячейки, га';
comment on column russia.urban_diversity_index.commercial_area_ha is 'Суммарная площадь коммерческой зоны в границах ячейки, га';
comment on column russia.urban_diversity_index.industrial_area_ha is 'Суммарная площадь производственной зоны в границах ячейки, га';
comment on column russia.urban_diversity_index.public_facilities_area_ha is 'Суммарная площадь зоны социальных объектов в границах ячейки, га';
comment on column russia.urban_diversity_index.public_spaces_area_ha is 'Суммарная площадь общественных пространств в границах ячейки, га';
comment on column russia.urban_diversity_index.total_area_ha is 'Суммарная площадь ячейки (по умолчанию 25 га), га';
comment on column russia.urban_diversity_index.total_area_used_ha is 'Суммарная площадь зоны участвующих в расчётах в границах ячейки, га';
comment on column russia.urban_diversity_index.residential_share is 'Доля жилой зоны от общей площади, участвующей в расчётах, га';
comment on column russia.urban_diversity_index.commercial_share is 'Доля коммерческой зоны от общей площади, участвующей в расчётах, га';
comment on column russia.urban_diversity_index.industrial_share is 'Доля производственной зоны от общей площади, участвующей в расчётах, га';
comment on column russia.urban_diversity_index.public_facilities_share is 'Доля зоны социальных объектов от общей площади, участвующей в расчётах, га';
comment on column russia.urban_diversity_index.public_spaces_share is 'Доля зоны общественных пространств от общей площади, участвующей в расчётах, га';
comment on column russia.urban_diversity_index.urban_diversity_index is 'Индекс разнообразия среды расчитанный по методу Шеннона';
