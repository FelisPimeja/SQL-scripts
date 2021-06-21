/* 16-й индикатор. Привлекательность озелененных территорий (только по благоустроенному озеленению) */
/* Время расчёта ~ 6 час. */
drop materialized view if exists index2019.ind_i16 cascade;
create materialized view index2019.ind_i16 as 
with greenery_vk as (
	select
		v.id_gis,
		count(*) total_photos
	from index2019.data_vk v
	join index2019.data_greenery g
		on st_intersects(v.geom, g.geom)
			and v.id_gis = g.id_gis
			and g.id_gis is not null
--			and g.id_gis = 1 -- для дебага
	where v.in_out = 'out'
	group by v.id_gis
)

select
	b.id_gis,
	b.city,
	b.region,
	gs.green_area_km2,
	coalesce(s.total_photos, 0) vk_photos_all,
	coalesce(s.out_photos, 0) out_photos_all,
	coalesce(g.total_photos, 0) greenery_photos_all,
	coalesce(round(g.total_photos / gs.green_area_km2::numeric), 0) photos_to_km2
from index2019.data_boundary b
left join greenery_vk g using(id_gis)
left join index2019.stat_vk s using(id_gis)
left join (
	select id_gis, coalesce(round((sum(st_area(geom::geography, true)) / 1000000)::numeric, 4), 0) green_area_km2
	from index2019.data_greenery
	group by id_gis
) gs using(id_gis)
-- where b.id_gis = 1 -- для дебага
order by id_gis;

/* Индексы */
create unique index on index2019.ind_i16 (id_gis);


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i16;
create view index2019.comp_i16 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round((i2.green_area_km2)::numeric, 4), 0) green_area_km2_2018,
	coalesce(i1.green_area_km2, 0) green_area_km2_2019,
	coalesce(i2.outdoor_photos_all, 0) out_photos_all_2018,
	coalesce(i1.out_photos_all, 0) out_photos_all_2019,
	coalesce(i2.outdoor_photos_in_greenery, 0) greenery_photos_all_2018,
	coalesce(i1.greenery_photos_all, 0) greenery_photos_all_2019,
	coalesce(round((i2.photos_to_km2)::numeric, 4), 0) photos_to_km2_2018,
	coalesce(i1.photos_to_km2, 0) photos_to_km2_2019,
	(case 
		when i1.photos_to_km2 > round(i2.photos_to_km2::numeric, 4)
			then 2019
	 	when i1.photos_to_km2 = round(i2.photos_to_km2::numeric, 4)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i16 i1
left join index2018.i16_photos_in_greenery_ndvi i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i16 is 'Сравнение с 2018 годом. 16-й индикатор. Привлекательность озелененных территорий.';
comment on column index2019.comp_i16.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i16.city is 'Город';
comment on column index2019.comp_i16.region is 'Субъект РФ';
comment on column index2019.comp_i16.green_area_km2_2018 is 'Площадь озеленения с качеством 50 <= NDVI на 2018 г., км2';
comment on column index2019.comp_i16.green_area_km2_2019 is 'Площадь благоустроенного озеленения на 2019 г., км2';
comment on column index2019.comp_i16.out_photos_all_2018 is 'Общее количество фото сделанных на улице в 2018 г., ед';
comment on column index2019.comp_i16.out_photos_all_2019 is 'Общее количество фото сделанных на улице в 2019 г., ед';
comment on column index2019.comp_i16.greenery_photos_all_2018 is 'Общее количество фото сделанных на озеленённых территориях в 2018 г., ед';
comment on column index2019.comp_i16.greenery_photos_all_2019 is 'Общее количество фото сделанных на озеленённых территориях в 2019 г., ед';
comment on column index2019.comp_i16.photos_to_km2_2018 is 'Привлекательность озелененных территорий - "плотность" фото на озеленённых территориях в 2018 г., ед/км2';
comment on column index2019.comp_i16.photos_to_km2_2019 is 'Привлекательность озелененных территорий - "плотность" фото на озеленённых территориях в 2019 г., ед/км2';
comment on column index2019.comp_i16.higher_value is 'В каком году показатель "Привлекательность озелененных территорий" выше';