/* 23-й индикатор. Уровень развития общественно-деловых районов города */
/* Время расчёта ~ 1 сек. */
drop materialized view if exists index2019.ind_i23 cascade; 
create materialized view index2019.ind_i23 as
select
	b.id_gis,
	b.city,
	b.region,
	m.multifunctional_odz_area,
	coalesce(z.total_odz, 0) total_odz,
	coalesce(z.odz_area_ratio, 0) odz_area_ratio
from index2019.data_boundary as b
left join index2019.ind_i20 m using(id_gis)
left join (
	select
		z.id_gis,
		sum(z.z3_odz) total_odz,
		round((sum(z.z3_odz) / sum(z.area_ha))::numeric, 4) odz_area_ratio
	from index2019.stat_zoning z
	where z.mu_odz > 0.2 and z.z1_pop > 0
--		and z.id_gis < 100 -- для дебага
	group by z.id_gis
) z using(id_gis);

/* Индексы */
create unique index on index2019.ind_i23 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i23 is '20-й индикатор. Уровень развития общественно-деловых районов города';
comment on column index2019.ind_i23.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i23.city is 'Город';
comment on column index2019.ind_i23.region is 'Субъект РФ';
comment on column index2019.ind_i23.multifunctional_odz_area is 'Площадь общественно-деловых районов с многофункциональной средой (по гексагональной сетке), га';
comment on column index2019.ind_i23.total_odz is 'Общее количество объектов общественно-делового назначения в районах с многофункциональной средой, ед.';
comment on column index2019.ind_i23.odz_area_ratio is 'Средняя плотность объектов общественно-делового назначения в районах с многофункциональной средой ед./га';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i23;
create view index2019.comp_i23 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round(i2.mu_odz_area_ha::numeric, 2), 0) multifunctional_odz_area_2018_ha,
	coalesce(i1.multifunctional_odz_area, 0) multifunctional_odz_area_2019_ha,
	coalesce(i2.odz_count, 0) total_odz_2018,
	coalesce(i1.total_odz, 0) total_odz_2019,
	coalesce(round((i2.ods_to_ha)::numeric, 4), 0) odz_area_ratio_2018,
	coalesce(i1.odz_area_ratio, 0) odz_area_ratio_2019,
	(case 
		when coalesce(i1.odz_area_ratio, 0) > coalesce(round((i2.ods_to_ha)::numeric, 4), 0)
			then 2019
	 	when coalesce(i1.odz_area_ratio, 0) = coalesce(round((i2.ods_to_ha)::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i23 i1
left join index2018.i23_odz_area i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i23 is 'Сравнение с 2018 годом. 23-й индикатор. Уровень развития общественно-деловых районов города.';
comment on column index2019.comp_i23.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i23.city is 'Город';
comment on column index2019.comp_i23.region is 'Субъект РФ';
comment on column index2019.comp_i23.multifunctional_odz_area_2018_ha is 'Площадь общественно-деловых районов с многофункциональной средой на 2018 г., га';
comment on column index2019.comp_i23.multifunctional_odz_area_2019_ha is 'Площадь общественно-деловых районов с многофункциональной средой на 2019 г., га';
comment on column index2019.comp_i23.total_odz_2018 is 'Количество объектов общественно-делового назначения в 2018 г., ед';
comment on column index2019.comp_i23.total_odz_2019 is 'Количество объектов общественно-делового назначения в 2019 г., ед';
comment on column index2019.comp_i23.odz_area_ratio_2018 is 'Уровень развития общественно-деловых районов города - отношение количества объектов к общественно-деловых районов с многофункциональной средой в 2018 г. ед/кв. км.';
comment on column index2019.comp_i23.odz_area_ratio_2019 is 'Уровень развития общественно-деловых районов города - отношение количества объектов к общественно-деловых районов с многофункциональной средой в 2019 г. ед/кв. км.';
comment on column index2019.comp_i23.higher_value is 'В каком году показатель "Уровень развития общественно-деловых районов города" выше';