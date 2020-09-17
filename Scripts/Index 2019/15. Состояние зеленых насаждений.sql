/* 15-й индикатор. Состояние зелёных насаждений */
/* Время расчёта ~ 15 сек. */
drop materialized view  if exists index2019.ind_i15;
create materialized view index2019.ind_i15 as 
/* Подсчёт суммарной площади зелёных насаждений для каждого города для разных срезов NDVI (0.5, 0.7, 0.75, 0.8) */
with
	n50 as (select id_gis, sum(area_ha) "sum" from index2019.data_ndvi where ndvi >= 50 group by id_gis),
	n70 as (select id_gis, sum(area_ha) "sum" from index2019.data_ndvi where ndvi >= 70 group by id_gis),
	n75 as (select id_gis, sum(area_ha) "sum" from index2019.data_ndvi where ndvi >= 75 group by id_gis),
	n80 as (select id_gis, sum(area_ha) "sum" from index2019.data_ndvi where ndvi >= 80 group by id_gis)

/* Сборка таблицы индекса */
select
	b.id_gis,
	b.city,
	b.region,
	round(n50.sum::numeric, 2) ndvi_50_ha,
	round((case
		when n80.sum > 0 then n80.sum
		when n80.sum = 0 and n75.sum > 0 then n75.sum
		else n70.sum
	end)::numeric, 2) ndvi_80_ha,
	round((case
		when n80.sum > 0 then n80.sum/n50.sum
		when n80.sum = 0 and n75.sum > 0 then n75.sum/n50.sum
		when n80.sum = 0 and n75.sum = 0 and n70.sum > 0 then n70.sum/n50.sum
	end)::numeric, 4) condition_ratio
from index2019.data_boundary as b
left join n50 using(id_gis)
left join n70 using(id_gis)
left join n75 using(id_gis)
left join n80 using(id_gis)
order by id_gis;

/* Индексы */
create unique index on index2019.ind_i15 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i15 is 'Состояние зелёных насаждений. 15-й индикатор.';
comment on column index2019.ind_i15.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i15.city is 'Город';
comment on column index2019.ind_i15.region is 'Субъект РФ';
comment on column index2019.ind_i15.ndvi_50_ha is 'Площадь озеленённой территории города(NDVI > 50), га';
comment on column index2019.ind_i15.ndvi_80_ha is 'Площадь озеленённой территории города(NDVI > 80 с оговорками), га';
comment on column index2019.ind_i15.condition_ratio is 'Отношение площади NDVI > 50 к NDVI > 80 %';

/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i15;
create view index2019.comp_i15 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round((i2.ndvi_50_ha)::numeric, 2), 0) ndvi_50_ha_2018,
	coalesce(i1.ndvi_50_ha, 0) ndvi_50_ha_2019,
	coalesce(round((i2.ndvi_80_ha)::numeric, 2), 0) ndvi_80_ha_2018,
	coalesce(i1.ndvi_80_ha, 0) ndvi_80_ha_2019,
	coalesce(round((i2.ratio)::numeric, 4), 0) condition_ratio_2018,
	coalesce(i1.condition_ratio, 0) condition_ratio_2019,
	(case 
		when i1.condition_ratio > round(i2.ratio::numeric, 4)
			then 2019
	 	when i1.condition_ratio = round(i2.ratio::numeric, 4)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i15 i1
left join index2018.i15_green_cond i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i15 is 'Сравнение с 2018 годом. 15-й индикатор. Состояние зелёных насаждений.';
comment on column index2019.comp_i15.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i15.city is 'Город';
comment on column index2019.comp_i15.region is 'Субъект РФ';
comment on column index2019.comp_i15.ndvi_50_ha_2018 is 'Площадь озеленения с качеством 50 <= NDVI < 80 на 2018 г.';
comment on column index2019.comp_i15.ndvi_50_ha_2019 is 'Площадь озеленения с качеством 50 <= NDVI < 80 на 2019 г.';
comment on column index2019.comp_i15.ndvi_80_ha_2018 is 'Площадь озеленения с качеством 80 <= NDVI на 2018 г.';
comment on column index2019.comp_i15.ndvi_80_ha_2019 is 'Площадь озеленения с качеством 80 <= NDVI на 2019 г.';
comment on column index2019.comp_i15.condition_ratio_2018 is 'Показатель состояния зелёных насаждений (отношение площадей) на 2018 г.';
comment on column index2019.comp_i15.condition_ratio_2019 is 'Показатель состояния зелёных насаждений (отношение площадей) на 2019 г.';
comment on column index2019.comp_i15.higher_value is 'В каком году показатель "Состояние зелёных насаждений" выше';