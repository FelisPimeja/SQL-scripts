drop table if exists public.vk_photo_inout_3;
create table public.vk_photo_inout_3 as 
select * from public.vk_photo_inout
where id_gis in (
	541,
	117,
	105,
	162,
	624,
	571,
	696,
	517,
	722,
	874,
	687,
	759,
	824,
	112,
	628,
	75,
	20,
	1031,
	1027,
	511,
	429
);

drop table if exists public.vk_photo_inout_3_1;
create table public.vk_photo_inout_3_1 as 
select
	(row_number() over())::int id,
	id uuid,
	id_gis::smallint id_gis,
	in_out,
	category,
	category_p,
	attributes,
	owner_id,
	regexp_replace(url, '&c_uniq_tag.*$', '') url,
	to_timestamp(date) date_time,
	st_setsrid(st_makepoint(lng,lat), 4326)::geometry(point, 4326) geom
from public.vk_photo_inout_3
--limit 10000 --дебаг
;
create index on public.vk_photo_inout_3_1(url);

drop table if exists public.vk_photo_inout_3_2;
create table public.vk_photo_inout_3_2 as 
select distinct on(url) * from public.vk_photo_inout_3_1;


create table public.tile_crosswalk_raw as select * from public.tile_crosswalk

create table public.tile_crosswalk_ya_raw as select * from public.tile_crosswalk_ya

create table public.tile_crosswalk_gl_raw as select * from public.tile_crosswalk_gl


create table public.tile_crosswalk_2_raw as
select * from public.tile_crosswalk_gl
union
select * from public.tile_crosswalk_ya



create table public.vk_photo_inout_result_2 as 
select * from public.vk_photo_inout_result_fdw;

drop table if exists public.vk_photo_inout_result_2_1;
create table public.vk_photo_inout_result_2_1 as 
select
	(row_number() over())::int id,
	id uuid,
	id_gis::smallint id_gis,
	in_out,
	category,
	category_p,
	attributes,
	owner_id,
	regexp_replace(url, '&c_uniq_tag.*$', '') url,
	to_timestamp(date) date_time,
	st_setsrid(st_makepoint(lng,lat), 4326)::geometry(point, 4326) geom
from public.vk_photo_inout_result_2
--limit 10000 --дебаг
;
create index on public.vk_photo_inout_result_2_1(url);

drop table if exists public.vk_photo_inout_result_2_2;
create table public.vk_photo_inout_result_2_2 as 
select distinct on(url) * from public.vk_photo_inout_result_2_1;


select max(id) from public.vk_photo_inout_result_2_2;



select count(*) from public.vk_photo_inout_result_2_1; --88 716 609
select count(*) from public.vk_photo_inout_result_2_2; --69 885 497

create index on public.vk_photo_inout_result_2_2(id_gis);
select distinct id_gis from public.vk_photo_inout_result_2_2;

create table public.vk_stat as
select
	id_gis,
	coalesce(count(*), 0) total_photos,
	coalesce(count(*) filter (where in_out = 1), 0) out_photos,
	coalesce(count(*) filter (where in_out = 0), 0) in_photos
from public.vk_photo_inout_result_2_2 
group by id_gis




insert into public.vk_photo_inout_result_2_2 
select
	id + 88716608,
	uuid,
	id_gis,
	in_out,
	category,
	category_p,
	attributes,
	owner_id,
	url,
	date_time,
	geom
from public.vk_photo_inout_3_2;


create table public.vk_photo_inout_result_2_3 as 
select * from public.vk_photo_inout_result_2_2
where id_gis in (
	9,19,20,61,75,105,112,117,162,338,370,429,443,510,511,517,541,557,571,582,624,
	628,631,687,696,722,754,759,763,794,824,849,863,870,871,874,878,883,892,950,960,
	963,1027,1031
)