/* 15-й индикатор. Состояние зелёных насаждений */
/* Предварительно рассчитан в Google Earth Engine. В базе только аггрегация. */
/* Время расчёта ~ 5 сек. */
drop table  if exists index2020.ind_i15;
create table index2020.ind_i15 as 
with stat_ndvi as (
	select 
		id_gis,
		sum(ndvi_50_ha) ndvi_50_ha,
		sum(ndvi_70_ha) ndvi_70_ha,
		sum(ndvi_75_ha) ndvi_75_ha,
		sum(ndvi_80_ha) ndvi_80_ha	
	from index2020.stat_ndvi
	group by id_gis
)
select
	b.id_gis,
	b.city,
	b.region,
	n.ndvi_50_ha,
	round((case
		when n.ndvi_80_ha > 0 then n.ndvi_80_ha
		when n.ndvi_80_ha = 0 and n.ndvi_75_ha > 0 then n.ndvi_75_ha
		else n.ndvi_70_ha
	end)::numeric, 2) ndvi_80_ha,
	round((case
		when n.ndvi_80_ha > 0 then n.ndvi_80_ha/n.ndvi_50_ha
		when n.ndvi_80_ha = 0 and n.ndvi_75_ha > 0 then n.ndvi_75_ha/n.ndvi_50_ha
		when n.ndvi_80_ha = 0 and n.ndvi_75_ha = 0 and n.ndvi_70_ha > 0 then n.ndvi_70_ha/n.ndvi_50_ha
	end)::numeric, 4) condition_ratio
from index2020.data_boundary as b
left join stat_ndvi n using(id_gis)
order by id_gis;

/* Индексы */
alter table index2020.ind_i15 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i15 is 'Состояние зелёных насаждений. 15-й индикатор.';
comment on column index2020.ind_i15.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i15.city is 'Город';
comment on column index2020.ind_i15.region is 'Субъект РФ';
comment on column index2020.ind_i15.ndvi_50_ha is 'Площадь озеленённой территории города(NDVI > 50), га';
comment on column index2020.ind_i15.ndvi_80_ha is 'Площадь озеленённой территории города(NDVI > 80 с оговорками), га';
comment on column index2020.ind_i15.condition_ratio is 'Отношение площади NDVI > 50 к NDVI > 80 %';

/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i15;
create table index2020.comp_i15 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.ndvi_50_ha, 0) ndvi_50_ha_2019,
	coalesce(i1.ndvi_50_ha, 0) ndvi_50_ha_2020,
	coalesce(i2.ndvi_80_ha, 0) ndvi_80_ha_2019,
	coalesce(i1.ndvi_80_ha, 0) ndvi_80_ha_2020,
	coalesce(i2.condition_ratio, 0) condition_ratio_2019,
	coalesce(i1.condition_ratio, 0) condition_ratio_2020,
	(case 
		when i1.condition_ratio > i2.condition_ratio
			then 2020
	 	when i1.condition_ratio < i2.condition_ratio
			then 2019
		else null
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i15 i1
left join index2019.ind_i15 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i15 is 'Сравнение с 2019 годом. 15-й индикатор. Состояние зелёных насаждений.';
comment on column index2020.comp_i15.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i15.city is 'Город';
comment on column index2020.comp_i15.region is 'Субъект РФ';
comment on column index2020.comp_i15.ndvi_50_ha_2019 is 'Площадь озеленения с качеством 50 <= NDVI < 80 на 2019 г.';
comment on column index2020.comp_i15.ndvi_50_ha_2020 is 'Площадь озеленения с качеством 50 <= NDVI < 80 на 2020 г.';
comment on column index2020.comp_i15.ndvi_80_ha_2019 is 'Площадь озеленения с качеством 80 <= NDVI на 2019 г.';
comment on column index2020.comp_i15.ndvi_80_ha_2020 is 'Площадь озеленения с качеством 80 <= NDVI на 2020 г.';
comment on column index2020.comp_i15.condition_ratio_2019 is 'Показатель состояния зелёных насаждений (отношение площадей) на 2019 г.';
comment on column index2020.comp_i15.condition_ratio_2020 is 'Показатель состояния зелёных насаждений (отношение площадей) на 2020 г.';
comment on column index2020.comp_i15.higher_value is 'В каком году показатель "Состояние зелёных насаждений" выше';


/* Вывод сравнительной таблицы в Excel */
--/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	ndvi_50_ha_2019 "Площадь ndvi < 80, га(2019)",
	ndvi_50_ha_2020 "Площадь ndvi < 80, га(2020)",
	ndvi_80_ha_2019 "Площадь ndvi >= 80, га(2019)",
	ndvi_80_ha_2020 "Площадь ndvi >= 80, га(2020)",
	condition_ratio_2019 "Состояние зел. насажд.(2019)",
	condition_ratio_2020 "Состояние зел. насажд.(2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i15;
--*/
