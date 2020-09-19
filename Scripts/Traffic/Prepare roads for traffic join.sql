/* Подготовка графа основных улиц и дорог для скрапинга загруженности дорог */
-- To do:
-- 1. Какие-то небольшие проблемы на стадии импорта дорог из ОСМ. Вернуться туда и разобраться
-- 2. "Хвостики" на стыках квадратов сетки.
-- 3. Добавить потом комментарии к таблицам и колонкам.

/* Время выполнения ~ 20 мин. */

/* обрезка дорог по границам городов */
drop table if exists traffic.city_road;
create table traffic.city_road as
select distinct on(h.id)
	h.id,
	h.id_gis,
	h.type,
	h.name,
	h.geom
from osm_test.highway h
where
	type in ('primary','primary_link','residential','road','secondary','secondary_link','tertiary','trunk','trunk_link','unclassified')
--		and id_gis = 1082  -- для дебага
;
alter table traffic.city_road add primary key(id);
create index on traffic.city_road using gist(geom);


/* два следующих подзапроса пересобирают граф с разбивкой на перекрёстках */
/* разбивка графа на сегменты */
drop table if exists segments;
create temp table segments as
select
	id_gis,
	st_makeline(lag((pt).geom, 1, null) over (partition by id order by id, (pt).path), (pt).geom)::geometry(linestring, 4326) geom
from (select id, id_gis, st_dumppoints(geom) as pt from traffic.city_road) as dumps
;

-- select * from segments;

drop table if exists segments2;
create temp table segments2 as
select --distinct on(s.geom)
	s.id_gis,
	g.id cell_id,
	s.geom
from segments s
join traffic.grid_russia_city g
	on st_intersects(s.geom, st_transform(g.geom, 4326));

-- select * from segments2;

/* обратная сборка из сегментов */
drop table if exists roads_rebuilt;
create temp table roads_rebuilt as
select
	id_gis,
	cell_id,
	st_simplify((st_dump(st_linemerge(st_collect(geom)))).geom, 0.00003)::geometry(linestring, 4326) geom
from segments2
where geom is not null
group by id_gis, cell_id;

drop table if exists traffic.city_road_rebuild;
create table traffic.city_road_rebuild as
select
	(row_number() over())::int id,
	id_gis,
	cell_id,
	st_linesubstring(geom, 100.00*n/length,
	  case
		when 100.00*(n+1) < length then 100.00*(n+1)/length
		else 1
	  end)::geometry(linestring, 4326) geom
from
  (select
  	id_gis,
  	cell_id,
  	st_linemerge(geom) geom,
  	st_length(geom::geography, true) length
  from roads_rebuilt
  ) t
cross join generate_series(0,100) n
where n*100.00/length < 1
;

alter table traffic.city_road_rebuild add primary key(id);
create index on traffic.city_road_rebuild(id_gis);
create index on traffic.city_road_rebuild(cell_id);
create index on traffic.city_road_rebuild using gist(geom);
create index on traffic.city_road_rebuild using gist(((st_lineinterpolatepoint(geom, 0.5))::geography)); -- Индекс по точке - середине линии (для последующего поиска ближайшей на растре)



