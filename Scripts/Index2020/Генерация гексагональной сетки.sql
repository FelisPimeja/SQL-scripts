/* Генерация гексагональной сетки на bbox городов + 5 км буфер (проще потом править сетку при изменении границ) */
/* Требуется PostGIS 3.1!!! */
/* Время рассчёта ~ 50 мин. */
/* Генерируем ббоксы границ городов */
drop table if exists bbox;
create temp table bbox as
	select st_envelope(st_buffer(geom::geography, 5000)::geometry)::geometry(polygon, 4326) geom -- bbox от 5 км. буфера границ городов
	from tmp.data_boundary
--	where id_gis <= 100 -- для дебага
;
create index on bbox using gist(geom)
;
/* Сливаем границы */
drop table if exists united;
create temp table united as
	select st_union(geom) geom from bbox
;
/* Разбираем границы обратно */
drop table if exists parted;
create temp table parted as
	select (st_dump(geom)).geom::geometry(polygon, 4326) geom from united;
create index on parted using gist(geom)
;
drop table if exists num_parted;
create temp table num_parted as
	select row_number() over() id, * from parted;
create index on num_parted(id)
create index on num_parted using gist(geom)
;
/* Пересекаем с utm зонами */
drop table if exists bound;
create temp table bound as
	select distinct on (p.id)
	p.id,
	('326' || u.utm_zone)::int crs ,
	p.geom
	from num_parted p
	left join tmp.utm_zones u
	on st_intersects(u.geom, p.geom);
create index on bound using gist(geom)
;
drop table if exists hex;
create temp table hex as
	select crs, id box_id, st_transform(st_setsrid((st_hexagongrid(62.04, st_transform(geom, crs))).geom, crs), 4326)::geometry(polygon, 4326) geom
	from bound;
create index on hex(box_id);
create index on hex using gist(geom)
;
/* Пересекаем гексагоны с границами bbox */
drop table if exists tmp.hexgrid_1ha;
create table tmp.hexgrid_1ha as
select (row_number() over())::int id, h.geom
from hex h
join num_parted p
	on p.id = h.box_id
		and st_intersects(p.geom, h.geom);
create index on tmp.hexgrid_1ha using gist(geom);

-- Если предыдущий шаг сделан на локальной базе, то копирование займёт около 30 мин.:
-- ogr2ogr -f PostgreSQL PG:"host=%PGHOST% port=%PGPORT% dbname=%PGDB% user=%PGUSER% password=%PGPASSWORD" -f "PostgreSQL" PG:"host=%PGHOST% port=%PGPORT% dbname=%PGDB% user=%PGUSER% password=%PGPASSWORD" tmp.hexgrid_1ha -lco GEOMETRY_NAME=geom -lco OVERWRITE=yes -lco SCHEMA=russia -lco FID=id -progress --config PG_USE_COPY YES

/* Обрезка гексагональной сектки по границам городов */
/* Время расчёта ~ 36 мин. */
drop table if exists index2020.data_hexgrid;
create table index2020.data_hexgrid as 
select
	(row_number() over())::int id,
	b.id_gis::smallint,
    round((
		case
			when st_within(g.geom, b.geom) then 1
			else st_area(st_intersection(b.geom, g.geom)::geography, true) / 10000
		end
	)::numeric, 2) area_ha,
	st_multi(
		case
			when st_within(g.geom, b.geom) then g.geom
			else st_intersection(b.geom, g.geom)
		end
	)::geometry(multipolygon, 4326) geom
from index2020.data_boundary b
left join russia.hexgrid_1ha g
	on st_intersects(b.geom, g.geom)
--where b.id_gis <= 10 -- дебаг
;
/* PK, индексы и кластеризация */
--alter table index2020.data_hexgrid drop column id;
alter table index2020.data_hexgrid add primary key(id);
create index on index2020.data_hexgrid (id_gis);
create index on index2020.data_hexgrid (area_ha);
create index on index2020.data_hexgrid using gist(geom);
--cluster index2020.data_hexgrid using data_hexgrid_geom_idx
;
/* Комментарии */
comment on table index2020.data_hexgrid is 
'Гексагональная сетка, обрезанная по границам городов';