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

