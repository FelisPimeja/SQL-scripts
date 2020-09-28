/* Traffic data matching */
-- To do:
-- 1. Добавить потом комментарии к колонкам

alter table traffic.google_initial
	add column road_segment_id int;

alter table traffic.google_initial
	add column dist_to_road_m int;

create index on traffic.city_road_rebuild using gist((geom::geography));
create index on traffic.google_initial(cell_id);

/* Матчинг в новую таблицу потому что обновление traffic.google_initial проходит очень долго!!! */
-- Время выполнения ~ 1 час + полчаса на  индексы
drop table if exists traffic.google_matched;
create table traffic.google_matched as 
--explain
select
	i.id,
	i.geom,
	i.value,
	i.cell_id,
	r.id road_segment_id,
	st_distance(i.geom::geography, r.geom::geography)::int dist_to_road_m	
from traffic.google_initial i
left join lateral (
	select r.id, r.geom
	from traffic.city_road_rebuild r
	where st_dwithin(i.geom::geography, r.geom::geography, 15)
	order by i.geom::geography <-> r.geom::geography
	limit 1
) r on true
--where i.cell_id = 1
;

-- PK и индексы
alter table traffic.google_matched add primary key(id);
create index on traffic.google_matched using gist(geom);
create index on traffic.google_matched using gist((geom::geography));
create index on traffic.google_matched(cell_id);
create index on traffic.google_matched(value);
create index on traffic.google_matched(road_segment_id);
create index on traffic.google_matched(dist_to_road_m);


/* Перенос медианного значения на рёбра графа */
-- Время выполнения ~ 4 минут.
-- To do:
-- 1. Попробовать отсекать ложные срабатывания на примыкающих дорогах через расчёт плотности точек на км дороги

drop table if exists traffic.graph_matched1;
create table traffic.graph_matched1 as 
select
	r.*,
	percentile_disc(0.5) within group(order by g.value) median_value
from traffic.city_road_rebuild r
left join traffic.google_matched g
	on r.id = g.road_segment_id
group by r.id, r.id_gis, r.cell_id, r.geom;

alter table traffic.graph_matched1 add primary key(id);
create index on traffic.graph_matched1(median_value);
create index on traffic.graph_matched1(cell_id);
create index on traffic.graph_matched1(id_gis);
create index on traffic.graph_matched1 using gist(geom);
create index on traffic.graph_matched1 using gist(((st_lineinterpolatepoint(geom, (0.5)::double precision))::geography));

--select count(*) from traffic.graph_matched1 where median_value is not null


/* Поиск одной точки для каждого ребра графа, по которой можно собирать загруженность */
-- Время выполнения ~ 10 минут.
drop table if exists traffic.graph_match_points;
create table traffic.graph_match_points as 
select
	r.id road_segment_id,
	g.geom
from traffic.graph_matched1 r
join lateral (
	select g.road_segment_id, g.geom
	from traffic.google_matched g
	where r.id = g.road_segment_id
		and r.median_value = g.value 
	order by g.geom::geography <-> (st_lineinterpolatepoint(r.geom, (0.5)::double precision))::geography
	limit 1
) g on true 

alter table traffic.graph_match_points add primary key(road_segment_id);
create index on traffic.graph_match_points using gist(geom);