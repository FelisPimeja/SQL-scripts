/* 22-й индикатор. Концентрация объектов культурного наследия */
/* Время расчёта ~ 5 сек. */
drop materialized view  if exists index2019.ind_i22;
create materialized view index2019.ind_i22 as 
select
	b.id_gis,
	b.city,
	b.region,
	round((st_area((b.geom)::geography, true) / 1000000)::numeric, 2) as area_city_sqkm,
	coalesce(count(st_intersects(k.geom, b.geom)), 0) as okn_count,
	coalesce(round((count(st_intersects(k.geom, b.geom)) / (st_area((b.geom)::geography, true) / 1000000))::numeric, 4), 0) as ratio_okn_sqkm
from index2019.data_boundary as b
left join index2019.data_okn k using(id_gis)
group by b.id_gis, b.city, b.region
order by id_gis;

/* Индексы */
create unique index on index2019.ind_i22 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i22 is 'Состояние зелёных насаждений. 15-й индикатор.';
comment on column index2019.ind_i22.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i22.city is 'Город';
comment on column index2019.ind_i22.region is 'Субъект РФ';
comment on column index2019.ind_i22.area_city_sqkm is 'Площадь города(расчитана по геометрии границы), га';
comment on column index2019.ind_i22.okn_count is 'Общее число объектов культурного наследия в границах города';
comment on column index2019.ind_i22.ratio_okn_sqkm is 'Количество объектов культурного наследия на 1 кв. км. Города';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i22;
create view index2019.comp_i22 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round(i2.area_sqkm::numeric, 4), 0) area_city_sqkm_2018,
	coalesce(i1.area_city_sqkm, 0) area_city_sqkm_2019,
	coalesce(i2.okn_count, 0) okn_count_2018,
	coalesce(i1.okn_count, 0) okn_count_2019,
	coalesce(round((i2.okn_sqkm)::numeric, 4), 0) ratio_okn_sqkm_2018,
	coalesce(i1.ratio_okn_sqkm, 0) ratio_okn_sqkm_2019,
	(case 
		when coalesce(i1.ratio_okn_sqkm, 0) > coalesce(round(i2.okn_sqkm::numeric, 4), 0)
			then 2019
	 	when coalesce(i1.ratio_okn_sqkm, 0) = coalesce(round(i2.okn_sqkm::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i22 i1
left join index2018.i22_okn_sqkm i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i22 is 'Сравнение с 2018 годом. 22-й индикатор. Концентрация объектов культурного наследия.';
comment on column index2019.comp_i22.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i22.city is 'Город';
comment on column index2019.comp_i22.region is 'Субъект РФ';
comment on column index2019.comp_i22.area_city_sqkm_2018 is 'Площадь города на 2018 г., кв. км.';
comment on column index2019.comp_i22.area_city_sqkm_2019 is 'Площадь города на 2019 г., кв. км.';
comment on column index2019.comp_i22.okn_count_2018 is 'Количество объектов культурного наследия на 2018 г., га';
comment on column index2019.comp_i22.okn_count_2019 is 'Количество объектов культурного наследия на 2019 г., га';
comment on column index2019.comp_i22.ratio_okn_sqkm_2018 is 'Концентрация объектов культурного наследия - отношение количества объектов к площади города в 2018 г. ед/кв. км.';
comment on column index2019.comp_i22.ratio_okn_sqkm_2019 is 'Концентрация объектов культурного наследия - отношение количества объектов к площади города в 2019 г. ед/кв. км.';
comment on column index2019.comp_i22.higher_value is 'В каком году показатель "Концентрация объектов культурного наследия" выше';