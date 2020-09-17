/* Гексагональная секта в границах городов */
/* Обрезаем предварительно сгенерированную сетку по границам */
create table index2019.data_hexgrid as 
select
	g.id,
	b.id_gis,
      round((
		case
			when st_within(g.geom, b.geom) then st_area(geom::geography, true) / 10000
			else st_area(st_intersection(b.geom, g.geom)::geography, true) / 10000
		end
	)::numeric, 2) area_ha
	st_multi(
		case
			when st_within(g.geom, b.geom) then g.geom
			else st_intersection(b.geom, g.geom)
		end
	)::geometry(multipolygon, 4326) geom
from tmp.hexgrid_1ha g
join index2019.data_boundary b on st_intersects(b.geom, g.geom);

/* PK, индексы и кластеризация */
alter table index2019.data_hexgrid drop column id;
alter table index2019.data_hexgrid add column id serial primary key;
create index on index2019.data_hexgrid (id_gis);
create index on index2019.data_hexgrid (area_ha);
create index on index2019.data_hexgrid using gist(geom);
cluster index2019.data_hexgrid using data_hexgrid_geom_idx;

/* Комментарии */
comment on table index2019.data_hexgrid is 
'Гексагональная сетка, обрезанная по границам городов';

