
/* 14-й индикатор. Уровень озеленения */
/* Время расчёта ~ 5 сек. */
drop table  if exists index2020.ind_i14;
create table index2020.ind_i14 as
with stat_ndvi as (
	select 
		id_gis,
		sum(ndvi_50_ha) ndvi_50_ha
	from index2020.stat_ndvi
	group by id_gis
)

select
	b.id_gis,
	b.city,
	b.region,
	round((st_area((b.geom)::geography, true) / 10000)::numeric, 2) as city_area_ha,
	case 
		when round(n.ndvi_50_ha::numeric, 2) > round((st_area((b.geom)::geography, true) / 10000)::numeric, 2)
			then round((st_area((b.geom)::geography, true) / 10000)::numeric, 2)
		else round(n.ndvi_50_ha::numeric, 2)
	end green_area_ha, -- площадь зелёных насаждений с проверкой превышения площади города
	case
		when coalesce(round((n.ndvi_50_ha * 100 / (st_area((b.geom)::geography, true) / 10000))::numeric, 4), 0) > 100
			then 100
		else coalesce(round((n.ndvi_50_ha * 100 / (st_area((b.geom)::geography, true) / 10000))::numeric, 4), 0)
	end green_percent -- процент зелёных насаждений с проверкой превышения 100
from index2020.data_boundary as b
left join stat_ndvi n using(id_gis)
order by id_gis;

/* Индексы */
alter table index2020.ind_i14 add primary key(id_gis);


/* Комментарии */
comment on table index2020.ind_i14 is 'Уровень озеленения. 14-й индикатор.';
comment on column index2020.ind_i14.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i14.city is 'Город';
comment on column index2020.ind_i14.region is 'Субъект РФ';
comment on column index2020.ind_i14.city_area_ha is 'Площадь города(расчитана по геометрии границы), га';
comment on column index2020.ind_i14.green_area_ha is 'Площадь озеленённой территории города, га';
comment on column index2020.ind_i14.green_percent is 'Процент озеленения %';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i14;
create table index2020.comp_i14 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	i2.city_area_ha city_area_ha_2019,
	i1.city_area_ha city_area_ha_2020,
	coalesce(i2.green_area_ha, 0) green_area_ha_2019,
	coalesce(i1.green_area_ha, 0) green_area_ha_2020,
	coalesce(i2.green_percent, 0) green_percent_2019,
	coalesce(i1.green_percent, 0) green_percent_2020,
	(case 
		when i1.green_percent > i2.green_percent
			then 2020
	 	when i1.green_percent < i2.green_percent
			then 2019
		else null
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i14 i1
left join index2019.ind_i14 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i14 is 'Сравнение с 2019 годом. 14-й индикатор. Уровень озеленения.';
comment on column index2020.comp_i14.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i14.city is 'Город';
comment on column index2020.comp_i14.region is 'Субъект РФ';
comment on column index2020.comp_i14.city_area_ha_2019 is 'Площадь города на 2019 г. (по геометрии границы)';
comment on column index2020.comp_i14.city_area_ha_2020 is 'Площадь города на 2020 г. (по геометрии границы)';
comment on column index2020.comp_i14.green_area_ha_2019 is 'Площадь озеленённой территории на 2019 г.';
comment on column index2020.comp_i14.green_area_ha_2020 is 'Площадь озеленённой территории на 2020 г.';
comment on column index2020.comp_i14.green_percent_2019 is 'Отношение площади озеленённой территории к общей площади города на 2019 г.';
comment on column index2020.comp_i14.green_percent_2020 is 'Отношение площади озеленённой территории к общей площади города на 2020 г.';
comment on column index2020.comp_i14.higher_value is 'В каком году показатель "Отношение площади озеленённой территории к общей площади города" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	city_area_ha_2019 "Площадь города, га(2019)",
	city_area_ha_2020 "Площадь города, га(2020)",
	green_area_ha_2019 "Площадь озел терр, га(2019)",
	green_area_ha_2020 "Площадь озел терр, га(2020)",
	green_percent_2019 "Процент озел терр, га(2019)",
	green_percent_2020 "Процент озел терр, га(2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i14;
*/
