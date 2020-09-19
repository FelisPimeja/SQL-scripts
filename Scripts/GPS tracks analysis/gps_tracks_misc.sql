truncate table tmp.quazar_dataset 

select * from tmp.quazar_dataset

select * from tmp.quazar_clipped

create index on tmp.quazar_dataset using gist(wkb_geometry);
create index on tmp.quazar_dataset((speed::int));

drop table if exists tmp.quazar_clipped;
create table tmp.quazar_clipped as
select
	q.ogc_fid id,
	q.track_id::int,
	to_timestamp(q.timestamp::int) date_time,
	q.speed::smallint,
	q.bearing::smallint,
	q.veh_type::smallint,
	q.wkb_geometry::geometry(point, 4326) geom,
	b.id_gis
from russia.city_boundary b
join tmp.quazar_dataset q
	on st_intersects(q.wkb_geometry, b.geom)
		and q.speed::int between 0 and 155
;


-- Фикс для кривых данных со стороны Квазара:
drop table if exists tmp.quazar_clipped;
create table tmp.quazar_clipped as
select q.ogc_fid id,
	q.track_id::int,
	to_timestamp(q.timestamp::int) date_time,
	substring(z, 3, length(z))::int speed,
	q.speed::int bearing,
	q.bearing::smallint veh_type,
	q.wkb_geometry::geometry(point, 4326) geom,
	b.id_gis
from russia.city_boundary b
join tmp.quazar_dataset q
	on st_intersects(q.wkb_geometry, b.geom)
		and substring(z, 3, length(z))::int between 10 and 155
--where b.id_gis = 1051
;



-- Проверка фильтра для qgis (т.к. он не умеет в специфические для pg касты и функции)
select *, cast(substr(cast(cast("date_time" as time) as varchar), 1, 2) as int) time_ from tmp.quazar_clipped limit 100

select count(q.*) from veb_rf.city c join tmp.quazar_clipped q using(id_gis)

analyze verbose tmp.quazar_clipped

create index on tmp.quazar_clipped(id_gis);


-- Вырезаем города ВЭБа в отдельную таблицу
drop table if exists tmp.quazar_veb;
create table tmp.quazar_veb as
select q.*
from veb_rf.city c
join tmp.quazar_clipped q using(id_gis);
create index on tmp.quazar_veb(id_gis);
create index on tmp.quazar_veb(track_id);
create index on tmp.quazar_veb(date_time);
create index on tmp.quazar_veb(speed);
create index on tmp.quazar_veb(bearing);
create index on tmp.quazar_veb(veh_type);
create index on tmp.quazar_veb using gist(geom);
create index on tmp.quazar_veb using gist((geom::geography)); -- время выполнения ~ 1 часа!!!


-- Строим треки для городов ВЭБа
drop table if exists tmp.quazar_veb_track;
create table tmp.quazar_veb_track as
select
	track_id,
	min(date_time),
	avg(speed),
	max(veh_type),
	st_multi(st_makeline(geom order by date_time) filter(where datedif_min::int <= 5))::geometry(multilinestring, 4326) geom
from (
	select
		*,
--		date_time,
--		lead(date_time) over(partition by track_id order by date_time) lead_,
		extract(hour from ((lead(date_time) over(partition by track_id order by date_time))) - date_time)::int * 60
			+ extract(minute from ((lead(date_time) over(partition by track_id order by date_time))) - date_time)::int datedif_min
	from tmp.quazar_veb
	where id_gis = 1051
) a
group by track_id;


-- Сажаем треки на граф (присваиваем id ближайшей дороги)
drop table if exists tmp.quazar_on_track;
create table tmp.quazar_on_track as
select
	q.*,
	r.street_id
from tmp.quazar_clipped q
left join lateral (
	select street_id, geom
	from index2019.data_road r
	where st_dwithin(q.geom::geography, r.geom::geography, 10)
		and r.type not in ('service', 'footway', 'steps', 'track', 'cycleway', 'bridleway')
	order by q.geom::geography <-> r.geom::geography
	limit 1
) r on true
--where q.id_gis = 1051 -- дебаг
;
create index on tmp.quazar_on_track(street_id);
create index on tmp.quazar_on_track(id_gis);


-- Сборка статистики на графе
drop table if exists tmp.quazar_graph;
create table tmp.quazar_graph as
select
	r.street_id,
	r.id_gis,
	r.name,
	r.type,
	r.geom,
	avg(q.speed) filter(where extract(hour from q.date_time) not in (7,8,9,10,18,19,20)) speed_normal,
	avg(q.speed) filter(where extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_rush_hour,
	avg(q.speed) filter(where extract(hour from q.date_time) not in (7,8,9,10,18,19,20)) - avg(q.speed) filter(where extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_dif
from index2019.data_road r
left join tmp.quazar_on_track q using(street_id)
--where r.id_gis = 1051 -- дебаг
where r.id_gis in (select id_gis from veb_rf.city)
group by r.street_id, r.id_gis,	r.name,	r.type, r.geom
;

select date_time, extract(hour from date_time) hour_ from tmp.quazar_on_track;
	
create index on osm.extent using gist(geom);


-- Простая статистика на разнице медианных скоростей в час пик и обычное время (для всех дорог в пределах города)
drop table if exists tmp.quazar_stat1;
create table tmp.quazar_stat1 as
select
	b.id_gis,
	b.city,
	b.region_name,
	percentile_disc(0.5) within group(order by q.speed) filter(where extract(hour from q.date_time) not in (7,8,9,10,18,19,20)) speed_normal,
	percentile_disc(0.5) within group(order by q.speed) filter(where extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_rush_hour,
	percentile_disc(0.5) within group(order by q.speed) filter(where extract(hour from q.date_time) not in (7,8,9,10,18,19,20)) - percentile_disc(0.5) within group(order by q.speed) filter(where extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_dif
from russia.city_boundary b
join tmp.quazar_on_track q using(id_gis)
group by b.id_gis, b.city, b.region_name
order by speed_dif desc;


-- Более продвинутая статистика на разнице медианных скоростей в час пик и обычное время (для всех дорог в пределах города) с введением весов от важности дорог
drop table if exists quazar_on_track;
create temp table quazar_on_track as
--explain
select g.*, r.type, extract(hour from g.date_time)::smallint "hour"
from tmp.quazar_on_track g
join index2019.data_road r
	on g.street_id = r.street_id
		and g.id_gis = r.id_gis
		and r."type" in ('trunk','trunk_link','primary','primary_link','secondary','secondary_link','tertiary','tertiary_link','unclassified','road','residential')
 where g.id_gis in (select id_gis from veb_rf.city limit 100) --дебаг
;
		
create index on quazar_on_track(track_id);
create index on quazar_on_track(id_gis);
create index on quazar_on_track(speed);
create index on quazar_on_track(type);
create index on quazar_on_track(hour);


drop table if exists tmp.quazar_stat2;
create table tmp.quazar_stat2 as
select
	b.id_gis,
	b.city,
	b.region_name,
	
	count(distinct q.track_id) total_tracks, -- сколько треков пришлось на город за 4 дня
	
	/* Медианная скорость в обычное время для дорог трёх разных категорий  */
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('trunk','trunk_link','primary','primary_link') and q.hour not in (7,8,9,10,18,19,20)) speed_normal_1,
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('secondary','secondary_link','tertiary','tertiary_link') and q.hour not in (7,8,9,10,18,19,20)) speed_normal_2,
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('unclassified','road','residential') and q.hour not in (7,8,9,10,18,19,20)) speed_normal_3,
	
	/* Медианная скорость в "час пик" для дорог трёх разных категорий  */
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('trunk','trunk_link','primary','primary_link') and q.hour in (7,8,9,10,18,19,20)) speed_rush_hour_1,
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('secondary','secondary_link','tertiary','tertiary_link') and q.hour in (7,8,9,10,18,19,20)) speed_rush_hour_2,
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('unclassified','road','residential') and q.hour in (7,8,9,10,18,19,20)) speed_rush_hour_3,
	
	/* Разница с скорости в "час пик" и обычное время для дорог трёх разных категорий  */
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('trunk','trunk_link','primary','primary_link') and q.hour not in (7,8,9,10,18,19,20)) - percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('trunk','trunk_link','primary','primary_link') and extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_dif_1,
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('secondary','secondary_link','tertiary','tertiary_link') and q.hour not in (7,8,9,10,18,19,20)) - percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('secondary','secondary_link','tertiary','tertiary_link') and extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_dif_2,
	percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('unclassified','road','residential') and q.hour not in (7,8,9,10,18,19,20)) - percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('unclassified','road','residential') and extract(hour from q.date_time) in (7,8,9,10,18,19,20)) speed_dif_3,
	
	/* Разница в скорости с условно "максимально разрешённой" */
	80 - percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('trunk','trunk_link','primary','primary_link') and q.hour not in (7,8,9,10,18,19,20)) speed_limit_dif_1,
	80 - percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('secondary','secondary_link','tertiary','tertiary_link') and q.hour not in (7,8,9,10,18,19,20)) speed_limit_dif_2,
	60 - percentile_disc(0.5) within group(order by q.speed) filter(where q.type in ('unclassified','road','residential') and q.hour not in (7,8,9,10,18,19,20)) speed_limit_dif_3

	from russia.city_boundary b
join quazar_on_track q using(id_gis)
group by b.id_gis, b.city, b.region_name
order by speed_dif_1 desc;

select distinct r.type from tmp.quazar_on_track q join index2019.data_road r using(street_id)
