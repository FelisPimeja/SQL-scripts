/* Индекс разнообразия среды (Urban Diversity (UD) Sub-Index) 
-- Ориентировочное время расчёта ~ 33 мин. на все города РФ.
-- Показывает функциональное разнообразие города
-- Считаем на сетке 500x500 м. Исходники - OSM, типология жилых кварталов, "благоустроенное озеленение"
-- см. CPI_Metadata 2016 стр. 99(101)
*/
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
LANGUAGE 'plpgsql';*/

/* Задаём рабочую выборку городов */
drop table if exists t_city;
create temp table t_city as
select * from russia.city 
where id_gis <= 1118
-- select * from t_city
;
create index on t_city using gist(geom); -- на случай если в выборке много городов
;
/* Генерим сетку 500x500 по экстенту города */
drop table if exists grid_f;
create temp table grid_f as 
select
	c.id_gis,
	st_transform((st_dump(makegrid_2d(c.geom, 500, ('326' || utm_zone)::int))).geom, 4326) geom
from t_city c 
--where c.id_gis = 1121
-- select * from grid_f
;
create index on grid_f(id_gis);
create index on grid_f using gist(geom)
;
/* Выбираем из сетки всё, что лежит в границах города */
drop table if exists grid;
create temp table grid as 
select
	(row_number() over())::int id,
	g.id_gis,
	case 
		when st_within(g.geom, c.geom) then g.geom
		else st_multi(st_collectionextract((st_intersection(g.geom, c.geom)), 3))
	end geom
from t_city c
left join grid_f g 
	on c.id_gis = g.id_gis 
		and st_intersects(c.geom, g.geom)
-- select * from grid
;
create index on grid(id_gis);
create index on grid using gist(geom)
;
/* Выбираем из osm landuse всё, что лежит в границах города */ 
-- todo: Добавить префильтрацию по type, чтобы не затягивать в расчёт всякий мусор
drop table if exists osm_s;
create temp table osm_s as
select
	o.id,
	o.id_gis,
	o.area_ha,
	case -- реклассификация под методику расчёта
		when o.type in ('residential','allotments')
			then 'residential'
		when o.type in (
			'commercial',
			'retail',
			'service',
			'services',
			'marketplace',
			'cafe',
			'restaurant',
			'food_court'
		)
			then 'commercial'
		when o.type in (
			'industrial',
			'fuel',
			'railway',
			'fire_station',
			'bus_station',
			'ferry_terminal',
			'car_wash',
			'fishfarm',
			'depot',
			'waste_transfer_station'
		)
			then 'industrial'
		when o.type in (
			'kindergarten',
			'school',
			'hospital',
			'college',
			'religious',
			'place_of_worship',
			'university',
			'clinic',
			'social_facility',
			'post_office',
			'doctors',
			'zoo',
			'community_centre',
			'education',
			'arts_centre',
			'theatre',
			'bank',
			'library',
			'music_school',
			'public_building'
		)
			then 'public facilities'
		when o.type in (
			'park',
			'stadium',
			'pedestrian',
			'garden',
			'fountain',
			'nature_reserve',
			'square',
			'recreation_ground',
			'rest_area',
			'playground',
			'pitch',
			'winter_sports'
		)
			then 'public spaces'
	end "class",
	o.geom
from t_city c 
left join russia.landuse_osm o 
	on c.id_gis = o.id_gis
		and o.type in (
			-- residential
			'residential',
			'allotments',
			-- commercial + services
			'commercial',
			'retail',
			'service',
			'services',
			'marketplace',
			'cafe',
			'restaurant',
			'food_court',
			-- industrial
			'industrial',
			'fuel',
			'railway',
			'fire_station',
			'bus_station',
			'ferry_terminal',
			'car_wash',
			'fishfarm',
			'depot',
			'waste_transfer_station',
			-- public facilities
			'kindergarten',
			'school',
			'hospital',
			'college',
			'religious',
			'place_of_worship',
			'university',
			'clinic',
			'social_facility',
			'post_office',
			'doctors',
			'zoo',
			'community_centre',
			'education',
			'arts_centre',
			'theatre',
			'bank',
			'library',
			'music_school',
			'public_building',
			-- public spaces
			'park',
			'stadium',
			'pedestrian',
			'garden',
			'fountain',
			'nature_reserve',
			'square',
			'recreation_ground',
			'rest_area',
			'playground',
			'pitch',
			'winter_sports'
		)
-- select * from osm
;
create index on osm_s using gist(geom);
create index on osm_s(class);
create index on osm_s(id_gis);
;
/* Топологическое приведение слоя osm (вычитаем большее из меньшего при наложении полигонов) */
drop table if exists osm_r;
create temp table osm_r as
select
	o1.id,
	o1.id_gis,
	o1."class",
--	o1.geom o1_geom,
--	st_union(o2.geom) o2_geom,
	case 
		when max(o2.id) is null then o1.geom
		else st_multi(st_collectionextract(st_difference(o1.geom, st_union(o2.geom)), 3))
	end geom
from osm_s o1 
left join osm_s o2
	on o1.id_gis = o2.id_gis 
		and o1.id <> o2.id
		and st_intersects(o1.geom, o2.geom)
		and o1.area_ha >= o2.area_ha
group by
	o1.id,
	o1.id_gis,
	o1."class",
	o1.geom
-- select * from osm_r
;
create index on osm_r using gist(geom);
create index on osm_r(class);
create index on osm_r(id_gis);
;
/* Генерация объектов обрезки для слоя osm */
drop table if exists diff;
create temp table diff as 
/* Начинаем с буферов от дорог */ 
select
	r.id_gis,
	st_buffer((st_dump(r.geom)).geom::geography, case when r.type in ('track', 'path', 'service', 'footway', 'living_street') then 3 when r.type in ('residential', 'tertiary', 'unclassified') then 5 else 7.5 end, 'endcap=square join=mitre')::geometry geom
from t_city c
join index2020.data_road r
	on r.id_gis = c.id_gis
		and (r.type != all('{track,path,footway,cycleway,steps,service}') -- фильтруем по типу
			or r.type = 'service' and name is not null
		)
union all
/* Собираем площадные водоёмы */ 
select b.id_gis, w.geom
from t_city b
join russia.water_osm w
	on st_intersects(b.geom, w.geom)
		and st_area(w.geom::geography) > 20000 -- отбрасываем водоёмы меньше 2 га
		and st_isvalid(w.geom) -- check geometry
union all
/* Добавляем линейные водоёмы с фиксированным буфером */ 
select b.id_gis, st_buffer(w.geom::geography, 10)::geometry geom
from t_city b
join russia.waterway_osm w
	on st_intersects(b.geom, w.geom)
--		and w.tunnel = '' -- check for waterways in tunnels
		and st_isvalid(w.geom) -- check geometry
union all
/* + буффер от ЖД дорог и трамвая */ 
select b.id_gis, (st_buffer(r.geom::geography, (case when r.type = 'tram' then 5 else 10 end)))::geometry geom -- разной ширины буфер для трамвая и железной дороги
from t_city b
join russia.railway_osm r
	on st_intersects(b.geom, r.geom)	
		and r.type not in ('subway','monorail','funicular') -- отбрасываем метро, монорельс и фуникулёр
--		and r.tunnel != 1 and r.bridge != 1 -- отбрасываем мосты и туннели -- Надо бы добавить в выгрузку!!!
		and st_isvalid(r.geom) -- check geometry
;
create index on diff(id_gis);
create index on diff using gist(geom)
-- select * from diff
;
/* вырезаем всё вышесобранное из слоя OSM */
drop table if exists osm;
create temp table osm as 
select
	o.id,
	o.id_gis,
	o."class",
	'OpenStreetMap'::text source,
	case 
		when max(d.id_gis) is null then o.geom
		else st_collectionextract(st_difference(o.geom, st_buffer(st_collect(d.geom), 0)), 3)
	end geom
from osm_r o
left join diff d
	on o.id_gis = d.id_gis 
		and st_intersects(o.geom, d.geom)
group by 
	o.id,
	o.id_gis,
	o."class",
	o.geom
;
create index on osm(id_gis);
create index on osm(class);
create index on osm(source);
create index on osm using gist(geom)
-- select * from osm
;
/* Выбираем из предрасчитанных кварталов все жилые в границах города */
drop table if exists quater;
create temp table quater as
select
	q.id,
	q.id_gis,
	'residential' "class",
	'Quater Classification'::text "source",
	q.geom
from t_city c 
left join russia.city_quater_type q
	on c.id_gis = q.id_gis
		and q.quater_class != 'Нежилая городская среда'
-- select * from quater
;
create index on quater(id_gis);
create index on quater(class);
create index on quater(source);
create index on quater using gist(geom);
;
/* Пересекаем классифицированные кварталы и обработанный OSM, чтобы получить финальную таблицу */
drop table if exists russia.urban_diversity_landuse;
create table russia.urban_diversity_landuse as
select
	(row_number() over())::int id, b.*
from (
	select
		a.id_gis,
		a.class,
		a.source,
		(st_dump(a.geom)).geom -- Разбивка на части
	from (
		select
			q.id_gis,
			q.class,
			q.source,
			case 
				when max(o.id_gis) is null
					then q.geom
				else st_multi(st_collectionextract(st_difference(q.geom, st_buffer(st_collect(o.geom),0)), 3))
			end geom
		from quater q 
		left join osm o 
			on o.id_gis = q.id_gis 
				and st_intersects(o.geom, q.geom)
				and o.class <> 'residential'
		group by 
			q.id_gis,
			q.class,
			q.source,
			q.geom
		union all 
		select 
			o.id_gis,
			o.class,
			o.source,
			case 
				when o.class <> 'residential'
					or (o.class = 'residential' and max(q.id_gis) is null)
					then o.geom
				else st_multi(st_collectionextract(st_difference(o.geom, st_buffer(st_collect(q.geom),0)), 3))
			end geom
		from osm o 
		left join quater q 
			on o.id_gis = q.id_gis 
				and st_intersects(o.geom, q.geom)
		group by 
			o.id_gis,
			o.class,
			o.source,
			o.geom
	) a
) b
where st_area(geom::geography) > 100  -- Отсев по минимальной площади
;
-- select * from landuse
/* Индексы */
alter table russia.urban_diversity_landuse add primary key(id);
create index on russia.urban_diversity_landuse(id_gis);
create index on russia.urban_diversity_landuse(class);
create index on russia.urban_diversity_landuse(source);
create index on russia.urban_diversity_landuse using gist(geom);
;
/* Комментарии */
comment on table russia.urban_diversity_landuse is
'Индекс Сбалансированности характера землепользования. 
Разнообразие землепользования на км2 (жилье, сервисы, пром, общественные функции, обществ. пространства, исключая УДС).
Расчитывается с помощью Shannon-Wienner diversity index Land Use Mix; UN Habitat City Prosperity index
https://drive.google.com/file/d/13zrK5fvYYL6UWK5WAVKLc4XRJ6mAB9N8/view?usp=sharing';
comment on column russia.urban_diversity_landuse.id is 'Первичный ключ';
comment on column russia.urban_diversity_landuse.id_gis is 'id_gis города';
comment on column russia.urban_diversity_landuse.class is
'Класс землепользования:
- жилая зона,
- коммерческая зона,
- производственная зона,
- зона общественных учреждений,
- зона общедоступных пространств';
comment on column russia.urban_diversity_landuse.source is
'Первоначальный источник из которого взят объект
(либо из слоя классифицированных кварталов russia.city_quater_type, либо очищенный и причёсанный OpenStreetMap)';
comment on column russia.urban_diversity_landuse.geom is 'Геометрия';
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
alter table russia.urban_diversity_index add primary key(id);
create index on russia.urban_diversity_index using gist(geom);
create index on russia.urban_diversity_index(id_gis);
create index on russia.urban_diversity_index(residential_area_ha);
create index on russia.urban_diversity_index(commercial_area_ha);
create index on russia.urban_diversity_index(industrial_area_ha);
create index on russia.urban_diversity_index(public_facilities_area_ha);
create index on russia.urban_diversity_index(public_spaces_area_ha);
create index on russia.urban_diversity_index(total_area_used_ha);
create index on russia.urban_diversity_index(residential_share);
create index on russia.urban_diversity_index(commercial_share);
create index on russia.urban_diversity_index(industrial_share);
create index on russia.urban_diversity_index(public_facilities_share);
create index on russia.urban_diversity_index(public_spaces_share);
create index on russia.urban_diversity_index(urban_diversity_index)
;
/* Комментарии */
comment on table russia.urban_diversity_index is
'Индекс Сбалансированности характера землепользования. 
Разнообразие землепользования на км2 (жилье, сервисы, пром, общественные функции, обществ. пространства, исключая УДС).
Расчитывается с помощью Shannon-Wienner diversity index Land Use Mix; UN Habitat City Prosperity index
https://drive.google.com/file/d/13zrK5fvYYL6UWK5WAVKLc4XRJ6mAB9N8/view?usp=sharing';
comment on column russia.urban_diversity_index.id is 'Первичный ключ';
comment on column russia.urban_diversity_index.id_gis is 'id_gis города';
comment on column russia.urban_diversity_index.geom is 'Геометрия';
comment on column russia.urban_diversity_index.residential_area_ha is 'Суммарная площадь жилой зоны в границах ячейки, га';
comment on column russia.urban_diversity_index.commercial_area_ha is 'Суммарная площадь коммерческой зоны в границах ячейки, га';
comment on column russia.urban_diversity_index.industrial_area_ha is 'Суммарная площадь производственной зоны в границах ячейки, га';
comment on column russia.urban_diversity_index.public_facilities_area_ha is 'Суммарная площадь зоны общественных учреждений в границах ячейки, га';
comment on column russia.urban_diversity_index.public_spaces_area_ha is 'Суммарная площадь общедоступных пространств в границах ячейки, га';
comment on column russia.urban_diversity_index.total_area_ha is 'Площадь ячейки, га';
comment on column russia.urban_diversity_index.total_area_used_ha is 'Суммарная площадь используемых пространств в границах ячейки, га';
comment on column russia.urban_diversity_index.residential_share is 'Доля жилой зоны в площади ячейки';
comment on column russia.urban_diversity_index.commercial_share is 'Доля коммерческой зоны в площади ячейки';
comment on column russia.urban_diversity_index.industrial_share is 'Доля производственной зоны в площади ячейки';
comment on column russia.urban_diversity_index.public_facilities_share is 'Доля зоны общественных учреждений в площади ячейки';
comment on column russia.urban_diversity_index.public_spaces_share is 'Доля общедоступных пространств в площади ячейки';
comment on column russia.urban_diversity_index.urban_diversity_index is 'Итоговый индекс Сбалансированности характера землепользования'
;
select * from russia.urban_diversity_index

/* Статистика в Excel */
--select 
--	b.id_gis,
--	b.city "Город",
--	b.region_name "Субъект РФ",
--	round(avg(i.urban_diversity_index), 3) "Усреднённый индекс разнообразия"
--from russia.city b
--join russia.urban_diversity_index i using(id_gis)
--group by b.id_gis, b.city, b.region_name
