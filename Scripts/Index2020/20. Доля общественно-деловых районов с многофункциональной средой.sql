/* 20-й индикатор. Доля общественно-деловых районов с многофункциональной средой */
/* Время расчёта ~ 20 сек. */
drop table if exists index2020.ind_i20; 
create table index2020.ind_i20 as
select
	b.id_gis,
	b.city,
	b.region,
	round((st_area(b.geom::geography, true) / 10000)::numeric, 2) as city_area_ha,
	coalesce(sum(z.area_ha), 0) as multifunctional_odz_area,
	coalesce(round((sum(z.area_ha) * 100 / (st_area(b.geom::geography, true) / 10000))::numeric, 4), 0) multifunctional_odz_ratio
from index2020.data_boundary as b
left join index2020.stat_zoning as z
	on b.id_gis = z.id_gis
		and z.mu_odz > 0.2
		and z.z1_pop > 0
--where b.id_gis < 100 -- для дебага 
group by b.id_gis, b.city, b.region, b.geom;

/* Индексы */
alter table index2020.ind_i20 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i20 is '20-й индикатор. Доля общественно-деловых районов с многофункциональной средой';
comment on column index2020.ind_i20.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i20.city is 'Город';
comment on column index2020.ind_i20.region is 'Субъект РФ';
comment on column index2020.ind_i20.city_area_ha is 'Площадь города, га';
comment on column index2020.ind_i20.multifunctional_odz_area is 'Площадь общественно-деловых районов с многофункциональной средой (по гексагональной сетке)';
comment on column index2020.ind_i20.multifunctional_odz_ratio is 'Отношение площади общественно-деловых районов с многофункциональной средой к общей площади города';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i20;
create table index2020.comp_i20 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.city_area_ha, 0) city_area_ha_2019,
	coalesce(i1.city_area_ha, 0) city_area_ha_2020,
	coalesce(i2.multifunctional_odz_area, 0) multifunctional_odz_area_2019,
	coalesce(i1.multifunctional_odz_area, 0) multifunctional_odz_area_2020,
	coalesce(i2.multifunctional_odz_ratio, 0) multifunctional_odz_ratio_2019,
	coalesce(i1.multifunctional_odz_ratio, 0) multifunctional_odz_ratio_2020,
	(case 
		when coalesce(i1.multifunctional_odz_ratio, 0) > coalesce(i2.multifunctional_odz_ratio, 0)
			then 2020
	 	when coalesce(i1.multifunctional_odz_ratio, 0) = coalesce(i2.multifunctional_odz_ratio, 0)
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i20 i1
left join index2019.ind_i20 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i20 is 'Сравнение с 2019 годом. 20-й индикатор. Доля общественно-деловых районов с многофункциональной средой.';
comment on column index2020.comp_i20.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i20.city is 'Город';
comment on column index2020.comp_i20.region is 'Субъект РФ';
comment on column index2020.comp_i20.city_area_ha_2019 is 'Площадь города на 2019 г., га';
comment on column index2020.comp_i20.city_area_ha_2020 is 'Площадь города на 2020 г., га';
comment on column index2020.comp_i20.multifunctional_odz_area_2019 is 'Площадь общественно-деловых районов с многофункциональной средой на 2019 г., га';
comment on column index2020.comp_i20.multifunctional_odz_area_2020 is 'Площадь общественно-деловых районов с многофункциональной средой на 2020 г., га';
comment on column index2020.comp_i20.multifunctional_odz_ratio_2019 is 'Доля общественно-деловых районов с многофункциональной средой от общей площади города в 2019 г. %';
comment on column index2020.comp_i20.multifunctional_odz_ratio_2020 is 'Доля общественно-деловых районов с многофункциональной средой от общей площади города в 2020 г. %';
comment on column index2020.comp_i20.higher_value is 'В каком году показатель "Доля общественно-деловых районов с многофункциональной средой" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	city_area_ha_2019 "Площадь города, га (2019)",
	city_area_ha_2020 "Площадь города, га (2020)",
	multifunctional_odz_area_2019 "S общ.-дел. районов с МФУ средой, га (2019)",
	multifunctional_odz_area_2020 "S общ.-дел. районов с МФУ средой, га (2020)",
	multifunctional_odz_ratio_2019 "Доля общ.-дел. районов с МФУ средой (2019)",
	multifunctional_odz_ratio_2020 "Доля общ.-дел. районов с МФУ средой (2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i20;
*/
