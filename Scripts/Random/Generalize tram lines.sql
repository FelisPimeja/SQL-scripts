-- Генерализованные трамвайные линии, побитые на сегменты
-- Не доделано!!!

-- Вытаскиваем трамвайные линии
drop table if exists tram_lines;
create temp table tram_lines as
select
	(row_number() over())::int id,
	r.geom,
	b.id_gis
from russia.city_boundary b
join osm.railroads_ru r
  on st_intersects(r.geom, b.geom)
    and r.type = 'tram'
where b.city in (
--  'Волгоград',
--  'Нижний Новгород',
--  'Санкт-Петербург',
  'Самара'
);

create index on tram_lines(id_gis);
create index on tram_lines using gist(geom);
create index on tram_lines using gist((geom::geography));

-- Вытаскиваем остановки в радиусе 10м. от трамвайных линий (допущение, конечно, но небольшое)
drop table if exists tram_stops;
create temp table tram_stops as
select distinct on(p.id)
	p.id,
	p.id_gis,
	p.name,
	p.geom
from tram_lines t
join index2019.data_poi p
	on p.id_gis = t.id_gis
		and p.rubrics = 'Остановка общественного транспорта'
		and st_dwithin(p.geom::geography, t.geom::geography, 10);
	
create index on tram_stops(id_gis);
create index on tram_stops(name);
create index on tram_stops using gist(geom);
create index on tram_stops using gist((geom::geography));


-- Генерализуем трамвайные линии
-- 1. Проверка - надо ли генерализовать
drop table if exists tram_line_check;
create temp table tram_line_check as
select
	t1.*,
	case when t2.id is not null then true::bool else false::bool end flag
from tram_lines t1
left join tram_lines t2
	on t1.id_gis = t2.id_gis
		and t1.id <> t2.id
		and st_area(st_intersection(st_buffer(t1.geom::geography, 5, 'endcap=flat')::geometry, st_buffer(t2.geom::geography, 5, 'endcap=flat')::geometry)::geography) > 0.2 * st_area(st_buffer(t1.geom::geography, 5, 'endcap=flat'))
;

drop table if exists tmp.tram_stops;
create table tmp.tram_stops as
select * from tram_stops;


drop table if exists tmp.tram_line_check;
create table tmp.tram_line_check as
select * from tram_line_check;
