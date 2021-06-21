/* Время рассчёта 2.5 мин */
drop table if exists tmp.vk_stat;
create table tmp.vk_stat as 
with stat_2020 as (
select 
	id_gis,
	count(*) out_photos_2020
from index2020.data_vk
group by id_gis
)
select
	c.id_gis,
	c.city,
	c.region,
	c.out_photos_2019,
	s.out_photos_2020,
	case
		when s.out_photos_2020 > c.out_photos_2019 then 2020::text
		when c.out_photos_2019 > s.out_photos_2020 then 2019::text
		else 'Поровну'
	end more_photos,
	round(((s.out_photos_2020::numeric / c.out_photos_2019::numeric * 100) - 100)::numeric, 2)  dif_percent
from index2020.comp_stat_photo c
left join stat_2020 s using(id_gis);


drop index index2020.data_vk_date_time_idx;
drop index index2020.data_vk_geom_idx;
drop index index2020.data_vk_geom_idx1;
drop index index2020.data_vk_id_gis_orig_idx;
drop index index2020.data_vk_owner_id_idx;

delete from index2020.data_vk
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

drop table if exists tmp.vk_photo_inout_dovesok2_lite;
create table tmp.vk_photo_inout_dovesok2_lite as 
select 
	d.id,
	b.id_gis,
	d.id_gis id_gis_orig,
	d.owner_id,
	d.url,
	d.date_time,
	d.geom
from index2020.data_boundary b 
join tmp.vk_photo_inout_dovesok d 
	on st_intersects(b.geom, d.geom)
		and d.in_out = 1 
;

select max(id) from index2020.data_vk; -- 97661224

alter table index2020.data_vk drop constraint data_vk_pkey;
drop index index2020.data_vk_id_gis_idx;
drop index index2020.data_vk_pkey;
drop index index2020.data_vk_url_idx;

insert into index2020.data_vk
select 
	id + 97661224 id,
	id_gis,
	id_gis id_gis_orig,
	owner_id,
	url,
	date_time,
	geom
from tmp.vk_photo_inout_dovesok2_lite;

create index on index2020.data_vk(id_gis);

--explain
drop table if exists st_tmp;
create temp table st_tmp as
select 
	id_gis,
	count(*) out_photos_2020
from index2020.data_vk
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
)
group by id_gis
;


update tmp.vk_stat st
set out_photos_2020 = s.out_photos_2020
from st_tmp s
where st.id_gis = s.id_gis;

update tmp.vk_stat st
set more_photos = case
		when out_photos_2020 > out_photos_2019 then 2020::text
		when out_photos_2019 > out_photos_2020 then 2019::text
		else 'Поровну'
	end,
	dif_percent = round(((out_photos_2020::numeric / out_photos_2019::numeric * 100) - 100)::numeric, 2) 
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


select * from tmp.vk_stat
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

create table index2020.data_vk as 
select 
	row_number() over() id,
	id_gis,
	id_gis id_gis_orig,
	owner_id,
	url,
	date_time,
	geom
from index2020.data_vk_2;


/* PK, индексы */
alter table index2020.data_vk add primary key(id);
create index on index2020.data_vk(id_gis);
create index on index2020.data_vk(id_gis_orig);
create index on index2020.data_vk(owner_id);
create index on index2020.data_vk(url);
create index on index2020.data_vk(date_time);
create index on index2020.data_vk using gist(geom);
create index on index2020.data_vk using gist((geom::geography));

/* Комментарии */
comment on table index2020.data_vk is 'Исходные данные - фото vk';
comment on column index2020.data_vk.id is 'Первичный ключ';
comment on column index2020.data_vk.id_gis is 'id_gis города';
comment on column index2020.data_vk.id_gis_orig is 'id_gis города от DC';
comment on column index2020.data_vk.owner_id is 'id пользователя vk (если 0, то фото загружено от группы)';
comment on column index2020.data_vk.url is 'url фото';
comment on column index2020.data_vk.date_time is 'Дата - время';
comment on column index2020.data_vk.geom is 'Локация';
