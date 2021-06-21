
/* 14-й индикатор. Уровень озеленения */
/* Время расчёта ~ 15 сек. */
drop materialized view  if exists index2019.ind_i14;
create materialized view index2019.ind_i14 as
/* Подсчёт суммарной площади зелёных насаждений для каждого города */
with sum_area_ndvi as(
	select
		id_gis,
		sum(area_ha) area_ha
	from index2019.data_ndvi
	where ndvi >= 50
--		and id_gis < 500 -- для дебага
	group by id_gis
)

/* Сборка таблицы индекса */
select
	b.id_gis,
	b.city,
	b.region,
	round((st_area((b.geom)::geography, true) / 10000)::numeric, 2) as city_area_ha,
	case 
		when round(n.area_ha::numeric, 2) > round((st_area((b.geom)::geography, true) / 10000)::numeric, 2)
			then round((st_area((b.geom)::geography, true) / 10000)::numeric, 2)
		else round(n.area_ha::numeric, 2)
	end green_area_ha, -- площадь зелёных насаждений с проверкой превышения площади города
	case
		when coalesce(round((n.area_ha * 100 / (st_area((b.geom)::geography, true) / 10000))::numeric, 4), 0) > 100
			then 100
		else coalesce(round((n.area_ha * 100 / (st_area((b.geom)::geography, true) / 10000))::numeric, 4), 0)
	end green_percent -- процент зелёных насаждений с проверкой превышения 100
from index2019.data_boundary as b
left join sum_area_ndvi n using(id_gis)
order by id_gis;

/* Индексы */
create unique index on index2019.ind_i14 (id_gis);


/* Комментарии */
comment on materialized view index2019.ind_i14 is 'Уровень озеленения. 14-й индикатор.';
comment on column index2019.ind_i14.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i14.city is 'Город';
comment on column index2019.ind_i14.region is 'Субъект РФ';
comment on column index2019.ind_i14.city_area_ha is 'Площадь города(расчитана по геометрии границы), га';
comment on column index2019.ind_i14.green_area_ha is 'Площадь озеленённой территории города, га';
comment on column index2019.ind_i14.green_percent is 'Процент озеленения %';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i14;
create view index2019.comp_i14 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	round(i2.area_ha::numeric, 2) city_area_ha_2018,
	i1.city_area_ha city_area_ha_2019,
	coalesce(round((i2.area_green_ha)::numeric, 2), 0) green_area_ha_2018,
	coalesce(i1.green_area_ha, 0) green_area_ha_2019,
	coalesce(round(i2.green_percent::numeric, 4), 0) green_percent_2018,
	coalesce(i1.green_percent, 0) green_percent_2019,
	(case 
		when i1.green_percent > round(i2.green_percent::numeric, 4)
			then 2019
	 	when i1.green_percent = round(i2.green_percent::numeric, 4)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i14 i1
left join index2018.i14_green_level i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i14 is 'Сравнение с 2018 годом. 14-й индикатор. Уровень озеленения.';
comment on column index2019.comp_i14.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i14.city is 'Город';
comment on column index2019.comp_i14.region is 'Субъект РФ';
comment on column index2019.comp_i14.city_area_ha_2019 is 'Площадь города на 2018 г. (по геометрии границы)';
comment on column index2019.comp_i14.city_area_ha_2018 is 'Площадь города на 2019 г. (по геометрии границы)';
comment on column index2019.comp_i14.green_area_ha_2018 is 'Площадь озеленённой территории на 2018 г.';
comment on column index2019.comp_i14.green_area_ha_2019 is 'Площадь озеленённой территории на 2019 г.';
comment on column index2019.comp_i14.green_percent_2018 is 'Отношение площади озеленённой территории к общей площади города на 2018 г.';
comment on column index2019.comp_i14.green_percent_2019 is 'Отношение площади озеленённой территории к общей площади города на 2019 г.';
comment on column index2019.comp_i14.higher_value is 'В каком году показатель "Отношение площади озеленённой территории к общей площади города" выше';
