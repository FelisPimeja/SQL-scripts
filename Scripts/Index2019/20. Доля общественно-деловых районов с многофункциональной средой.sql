/* 20-й индикатор. Доля общественно-деловых районов с многофункциональной средой */
/* Время расчёта ~ 5 сек. */
drop materialized view if exists index2019.ind_i20 cascade; 
create materialized view index2019.ind_i20 as
select
	b.id_gis,
	b.city,
	b.region,
	round((st_area(b.geom::geography, true) / 10000)::numeric, 2) as city_area_ha,
	coalesce(sum(z.area_ha), 0) as multifunctional_odz_area,
	coalesce(round((sum(z.area_ha) * 100 / (st_area(b.geom::geography, true) / 10000))::numeric, 4), 0) multifunctional_odz_ratio
from index2019.data_boundary as b
left join index2019.stat_zoning as z
	on b.id_gis = z.id_gis
		and z.mu_odz > 0.2
		and z.z1_pop > 0
--where b.id_gis < 100 -- для дебага 
group by b.id_gis, b.city, b.region, b.geom;

/* Индексы */
create unique index on index2019.ind_i20 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i20 is '20-й индикатор. Доля общественно-деловых районов с многофункциональной средой';
comment on column index2019.ind_i20.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i20.city is 'Город';
comment on column index2019.ind_i20.region is 'Субъект РФ';
comment on column index2019.ind_i20.city_area_ha is 'Площадь города, га';
comment on column index2019.ind_i20.multifunctional_odz_area is 'Площадь общественно-деловых районов с многофункциональной средой (по гексагональной сетке)';
comment on column index2019.ind_i20.multifunctional_odz_ratio is 'Отношение площади общественно-деловых районов с многофункциональной средой к общей площади города';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i20;
create view index2019.comp_i20 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round(i2.city_area_ha::numeric, 2), 0) city_area_ha_2018,
	coalesce(i1.city_area_ha, 0) city_area_ha_2019,
	coalesce(round(i2.mu_odz_area_ha::numeric, 2), 0) multifunctional_odz_area_2018,
	coalesce(i1.multifunctional_odz_area, 0) multifunctional_odz_area_2019,
	coalesce(round((i2.mu_ratio)::numeric, 4), 0) multifunctional_odz_ratio_2018,
	coalesce(i1.multifunctional_odz_ratio, 0) multifunctional_odz_ratio_2019,
	(case 
		when coalesce(i1.multifunctional_odz_ratio, 0) > coalesce(round(i2.mu_ratio::numeric, 4), 0)
			then 2019
	 	when coalesce(i1.multifunctional_odz_ratio, 0) = coalesce(round(i2.mu_ratio::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i20 i1
left join index2018.i20_mixed_use_ratio i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i20 is 'Сравнение с 2018 годом. 20-й индикатор. Доля общественно-деловых районов с многофункциональной средой.';
comment on column index2019.comp_i20.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i20.city is 'Город';
comment on column index2019.comp_i20.region is 'Субъект РФ';
comment on column index2019.comp_i20.city_area_ha_2018 is 'Площадь города на 2018 г., га';
comment on column index2019.comp_i20.city_area_ha_2019 is 'Площадь города на 2019 г., га';
comment on column index2019.comp_i20.multifunctional_odz_area_2018 is 'Площадь общественно-деловых районов с многофункциональной средой на 2018 г., га';
comment on column index2019.comp_i20.multifunctional_odz_area_2019 is 'Площадь общественно-деловых районов с многофункциональной средой на 2019 г., га';
comment on column index2019.comp_i20.multifunctional_odz_ratio_2018 is 'Доля общественно-деловых районов с многофункциональной средой от общей площади города в 2018 г. %';
comment on column index2019.comp_i20.multifunctional_odz_ratio_2019 is 'Доля общественно-деловых районов с многофункциональной средой от общей площади города в 2019 г. %';
comment on column index2019.comp_i20.higher_value is 'В каком году показатель "Доля общественно-деловых районов с многофункциональной средой" выше';