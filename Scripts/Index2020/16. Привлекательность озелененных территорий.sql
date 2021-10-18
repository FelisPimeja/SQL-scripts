/* 16-й индикатор. Привлекательность озелененных территорий (только по благоустроенному озеленению) */
/* Время расчёта ~ 17 мин. для 18 млн. точек 2020 г. (и 35 мин для 27 млн. точек до зачистки от дублей)  */
/* Пересекаем фото и полигоны благоустроенного озеленения */
drop table if exists greenery_stat;
create temp table greenery_stat as
	select
		g.id_gis,
		count(v.*) total_photos
	from index2020.data_greenery g
	left join index2020.data_vk v
		on st_intersects(v.geom, g.geom)
			and v.id_gis = g.id_gis
	where g.id_gis is not null
--		and g.id_gis <= 100 -- для дебага
	group by g.id_gis
;

drop table if exists index2020.ind_i16;
create table index2020.ind_i16 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(gs.green_area_km2, 0) green_area_km2,
--	coalesce(s.total_photos, 0) vk_photos_all, -- при последнем рассчёте не хватало этих данных, поэтому я их исключил, но это не нормально (хотя и не смертельно)
	coalesce(s.out_photos_2020, 0) out_photos_all,
	coalesce(g.total_photos, 0) greenery_photos_all,
	coalesce(round(g.total_photos / gs.green_area_km2::numeric), 0) photos_to_km2
from index2020.data_boundary b
left join greenery_stat g using(id_gis)
--left join index2020.stat_vk s using(id_gis) -- это правильный указатель
left join tmp.vk_stat s using(id_gis) -- это временная таблица т.к. в последний момент всё пошло через жопу (
left join (
	select id_gis, coalesce(round((sum(st_area(geom::geography, true)) / 1000000)::numeric, 4), 0) green_area_km2
	from index2020.data_greenery
	group by id_gis
) gs using(id_gis)
-- where b.id_gis = 1 -- для дебага
order by id_gis;

/* Индексы */
alter table index2020.ind_i16 add primary key(id_gis);


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i16;
create table index2020.comp_i16 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.green_area_km2, 0) green_area_km2_2019,
	coalesce(i1.green_area_km2, 0) green_area_km2_2020,
	coalesce(i2.out_photos_all, 0) out_photos_all_2019,
	coalesce(i1.out_photos_all, 0) out_photos_all_2020,
	coalesce(i2.greenery_photos_all, 0) greenery_photos_all_2019,
	coalesce(i1.greenery_photos_all, 0) greenery_photos_all_2020,
	coalesce(i2.photos_to_km2, 0) photos_to_km2_2019,
	coalesce(i1.photos_to_km2, 0) photos_to_km2_2020,
	(case 
		when i1.photos_to_km2 > i2.photos_to_km2
			then 2020
	 	when i1.photos_to_km2 = i2.photos_to_km2
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i16 i1
left join index2019.ind_i16 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i16 is 'Сравнение с 2019 годом. 16-й индикатор. Привлекательность озелененных территорий.';
comment on column index2020.comp_i16.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i16.city is 'Город';
comment on column index2020.comp_i16.region is 'Субъект РФ';
comment on column index2020.comp_i16.green_area_km2_2019 is 'Площадь озеленения с качеством 50 <= NDVI на 2019 г., км2';
comment on column index2020.comp_i16.green_area_km2_2020 is 'Площадь благоустроенного озеленения на 2020 г., км2';
comment on column index2020.comp_i16.out_photos_all_2019 is 'Общее количество фото сделанных на улице в 2019 г., ед';
comment on column index2020.comp_i16.out_photos_all_2020 is 'Общее количество фото сделанных на улице в 2020 г., ед';
comment on column index2020.comp_i16.greenery_photos_all_2019 is 'Общее количество фото сделанных на озеленённых территориях в 2019 г., ед';
comment on column index2020.comp_i16.greenery_photos_all_2020 is 'Общее количество фото сделанных на озеленённых территориях в 2020 г., ед';
comment on column index2020.comp_i16.photos_to_km2_2019 is 'Привлекательность озелененных территорий - "плотность" фото на озеленённых территориях в 2019 г., ед/км2';
comment on column index2020.comp_i16.photos_to_km2_2020 is 'Привлекательность озелененных территорий - "плотность" фото на озеленённых территориях в 2020 г., ед/км2';
comment on column index2020.comp_i16.higher_value is 'В каком году показатель "Привлекательность озелененных территорий" выше';


/* Визуалка навскидку что-то типа: */
drop table if exists index2020.viz_i16;
create table index2020.viz_i16 as
	select v.*
	from index2020.data_greenery g
	left join index2020.data_vk v
		on st_intersects(v.geom, g.geom)
			and v.id_gis = g.id_gis
	where g.id_gis is not null
--		and g.id_gis <= 100 -- для дебага
;

/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	green_area_km2_2019 "Площадь благ. озел., км2 (2019)",
	green_area_km2_2020 "Площадь благ. озел., км2 (2020)",
	out_photos_all_2019 "Всего фото на улице, шт.(2019)",
	out_photos_all_2020 "Всего фото на улице, шт.(2020)",
	greenery_photos_all_2019 "Всего фото в гран благ озел, шт.(2019)",
	greenery_photos_all_2020 "Всего фото в гран благ озел, шт.(2020)",
	photos_to_km2_2019 "Плотн фото на озел терр, ед/км2(2019)",
	photos_to_km2_2020 "Плотн фото на озел терр, ед/км2(2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i16;
*/

