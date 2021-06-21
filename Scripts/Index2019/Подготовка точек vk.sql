/* Подготовка точек vk  (~ 40 мин. без кластеризации для 770 городов)*/
/* Создаём геометрию, присваиваем id_gis */
drop table if exists index2019.data_vk;
create table index2019.data_vk as 
select
	row_number() over() id,
	p.album_id,
	p.owner_id,
	p.text,
	p.date,
	p.lat,
	p.long,
	p.post_id,
	p.user_id,
	p.url,
	p.in_out,
	p.id_gis source_id_gis,
	b.id_gis,
	st_setsrid(st_makepoint(p.long, p.lat), 4326)::geometry(point, 4326) geom
from index2019.data_vk_raw p
left join index2019.data_boundary b
	on st_intersects(b.geom, st_setsrid(st_makepoint(p.long, p.lat), 4326));

/* PK, индексы и кластеризация */
alter table index2019.data_vk add primary key(id);
create index on index2019.data_vk using gist(geom);
create index on index2019.data_vk (id_gis);
create index on index2019.data_vk (in_out);
create index on index2019.data_vk (user_id);
cluster index2019.data_vk using data_vk_geom_idx;

/* Минимальная статистика по слою фото vk */
/* Время расчёта ~ 3 мин. */
drop materialized view if exists index2019.stat_vk cascade;
create materialized view index2019.stat_vk as
select 
	b.id_gis,
	b.city,
	b.region,
	coalesce(count(v.*), 0) total_photos,
	coalesce(count(v.*) filter (where in_out = 'out'), 0) out_photos,
	coalesce(count(v.*) filter (where in_out = 'in'), 0) in_photos,
	coalesce(count(v.*) filter (where in_out is null), 0) err_photos
from index2019.data_boundary b 
left join index2019.data_vk v using(id_gis)
group by b.id_gis, b.city, b.region;

comment on materialized view index2019.stat_vk is 'Минимальная статистика по слою фото vk';
comment on column index2019.stat_vk.id_gis is 'Уникальный идентификатор города';
comment on column index2019.stat_vk.city is 'Город';
comment on column index2019.stat_vk.region is 'Субъект РФ';
comment on column index2019.stat_vk.total_photos is 'Всего фото vk в городе';
comment on column index2019.stat_vk.out_photos is 'Всего фото vk на улице в городе';
comment on column index2019.stat_vk.in_photos is 'Всего фото vk в помещении в городе';
comment on column index2019.stat_vk.err_photos is 'Всего фото vk (локация не ясна - ошибка)';