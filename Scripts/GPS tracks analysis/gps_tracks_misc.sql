truncate table tmp.quazar_dataset 

select * from tmp.quazar_dataset

select * from tmp.quazar_clipped

create index on tmp.quazar_dataset using gist(wkb_geometry);
create index on tmp.quazar_dataset((speed::int))

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
		and q.speed::int between 0 and 140
;

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
drop table if exists tmp.quazar_veb_on_track;
create table tmp.quazar_veb_on_track as
select
	q.*,
	r.street_id
from tmp.quazar_veb q
left join lateral (
	select street_id, geom
	from index2019.data_road r
	where st_dwithin(q.geom::geography, r.geom::geography, 10)
	order by q.geom::geography <-> r.geom::geography
	limit 1
) r on true
where q.id_gis = 1051 -- дебаг
;

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
left join tmp.quazar_veb_on_track q using(street_id)
where r.id_gis = 1051 -- дебаг
group by r.street_id, r.id_gis,	r.name,	r.type, r.geom
;

select date_time, extract(hour from date_time) hour_ from tmp.quazar_veb_on_track
	
	
	
