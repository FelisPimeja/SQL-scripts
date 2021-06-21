/* Подготовка точек vk */
/* ~ 1 ч. для 97 млн. записей на все города */

/* Создаём геометрию, присваиваем id_gis */
drop table if exists index2020.data_vk;
create table index2020.data_vk as 
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
from tmp.vk_photo_2020_raw
--limit 10000 --дебаг
;

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
comment on column index2020.data_vk.uuid is 'UUID от DC';
comment on column index2020.data_vk.id_gis is 'id_gis города';
comment on column index2020.data_vk.in_out is 'Локация фото (1 - на улице; 2 - в помещении)';
comment on column index2020.data_vk.category is 'Категория';
comment on column index2020.data_vk.category_p is 'Вес категории';
comment on column index2020.data_vk.attributes is 'Теги';
comment on column index2020.data_vk.owner_id is 'id пользователя vk (если 0, то фото загружено от группы)';
comment on column index2020.data_vk.url is 'url фото';
comment on column index2020.data_vk.date_time is 'Дата - время';
comment on column index2020.data_vk.geom is 'Локация';


/* Минимальная статистика по слою фото vk */
/* Время расчёта ~ 12 мин. на данных 2020 г. (97 млн. точек) */
drop table if exists index2020.stat_vk cascade;
create table index2020.stat_vk as
select 
	b.id_gis,
	b.city,
	b.region,
	coalesce(count(v.*), 0) total_photos,
	coalesce(count(v.*) filter (where in_out = 1), 0) out_photos,
	coalesce(count(v.*) filter (where in_out = 0), 0) in_photos,
	coalesce(count(v.*) filter (where in_out is null), 0) err_photos
from index2020.data_boundary b 
left join index2020.data_vk v using(id_gis)
group by b.id_gis, b.city, b.region;

/* Комментарии */
comment on table index2020.stat_vk is 'Минимальная статистика по слою фото vk';
comment on column index2020.stat_vk.id_gis is 'Уникальный идентификатор города';
comment on column index2020.stat_vk.city is 'Город';
comment on column index2020.stat_vk.region is 'Субъект РФ';
comment on column index2020.stat_vk.total_photos is 'Всего фото vk в городе';
comment on column index2020.stat_vk.out_photos is 'Всего фото vk на улице в городе';
comment on column index2020.stat_vk.in_photos is 'Всего фото vk в помещении в городе';
comment on column index2020.stat_vk.err_photos is 'Всего фото vk (локация не ясна - ошибка)';


/* Сравнение статистики по слою фото vk 2019 - 2020 гг. */
drop table if exists index2020.comp_stat_photo;
create table index2020.comp_stat_photo as
select 
	b.id_gis,
	b.city,
	b.region,
	s1.total_photos total_photos_2019,
	s2.total_photos total_photos_2020,
	s1.out_photos out_photos_2019,
	s2.out_photos out_photos_2020,
	s1.in_photos in_photos_2019,
	s2.in_photos in_photos_2020,
	s1.err_photos err_photos_2019,
	s2.err_photos err_photos_2020,
	case when s1.total_photos > s2.total_photos then 2019::smallint else 2020::smallint end more_photos,
	100 - round((s2.total_photos / s1.total_photos::numeric * 100)::numeric, 2) percent
from index2020.data_boundary b
left join index2019.stat_vk s1 using(id_gis)
left join index2020.stat_vk s2 using(id_gis);

alter table index2020.comp_stat_photo add primary key(id_gis);

/* Комментарии */
comment on table index2020.comp_stat_photo is 'Сравнение статистики по слою фото vk 2019 - 2020 гг.';
comment on column index2020.comp_stat_photo.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_stat_photo.city is 'Город';
comment on column index2020.comp_stat_photo.region is 'Субъект РФ';
comment on column index2020.comp_stat_photo.total_photos_2019 is 'Всего фото vk в городе за 2019 г.';
comment on column index2020.comp_stat_photo.total_photos_2020 is 'Всего фото vk в городе за 2020 г.';
comment on column index2020.comp_stat_photo.out_photos_2019 is 'Всего фото vk на улице в городе за 2019 г.';
comment on column index2020.comp_stat_photo.out_photos_2020 is 'Всего фото vk на улице в городе за 2020 г.';
comment on column index2020.comp_stat_photo.in_photos_2019 is 'Всего фото vk в помещении в городе за 2019 г.';
comment on column index2020.comp_stat_photo.in_photos_2020 is 'Всего фото vk в помещении в городе за 2020 г.';
comment on column index2020.comp_stat_photo.err_photos_2019 is 'Всего фото vk (локация не ясна - ошибка) за 2019 г.';
comment on column index2020.comp_stat_photo.err_photos_2020 is 'Всего фото vk (локация не ясна - ошибка) за 2020 г.';