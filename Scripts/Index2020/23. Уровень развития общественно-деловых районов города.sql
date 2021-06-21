/* 23-й индикатор. Уровень развития общественно-деловых районов города */
/* Время расчёта ~ 1 сек. */
drop table if exists index2020.ind_i23; 
create table index2020.ind_i23 as
select
	b.id_gis,
	b.city,
	b.region,
	m.multifunctional_odz_area,
	coalesce(z.total_odz, 0) total_odz,
	coalesce(z.odz_area_ratio, 0) odz_area_ratio
from index2020.data_boundary as b
left join index2020.ind_i20 m using(id_gis)
left join (
	select
		z.id_gis,
		sum(z.z3_odz) total_odz,
		round((sum(z.z3_odz) / sum(z.area_ha))::numeric, 4) odz_area_ratio
	from index2020.stat_zoning z
	where z.mu_odz > 0.2 and z.z1_pop > 0
--		and z.id_gis < 100 -- для дебага
	group by z.id_gis
) z using(id_gis);

/* Индексы */
alter table index2020.ind_i23 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i23 is '20-й индикатор. Уровень развития общественно-деловых районов города';
comment on column index2020.ind_i23.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i23.city is 'Город';
comment on column index2020.ind_i23.region is 'Субъект РФ';
comment on column index2020.ind_i23.multifunctional_odz_area is 'Площадь общественно-деловых районов с многофункциональной средой (по гексагональной сетке), га';
comment on column index2020.ind_i23.total_odz is 'Общее количество объектов общественно-делового назначения в районах с многофункциональной средой, ед.';
comment on column index2020.ind_i23.odz_area_ratio is 'Средняя плотность объектов общественно-делового назначения в районах с многофункциональной средой ед./га';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i23;
create table index2020.comp_i23 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.multifunctional_odz_area, 0) multifunctional_odz_area_2019_ha,
	coalesce(i1.multifunctional_odz_area, 0) multifunctional_odz_area_2020_ha,
	coalesce(i2.total_odz, 0) total_odz_2019,
	coalesce(i1.total_odz, 0) total_odz_2020,
	coalesce(i2.odz_area_ratio, 0) odz_area_ratio_2019,
	coalesce(i1.odz_area_ratio, 0) odz_area_ratio_2020,
	(case 
		when coalesce(i1.odz_area_ratio, 0) > coalesce(i2.odz_area_ratio, 0)
			then 2020
	 	when coalesce(i1.odz_area_ratio, 0) = coalesce(i2.odz_area_ratio, 0)
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i23 i1
left join index2019.ind_i23 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i23 is 'Сравнение с 2019 годом. 23-й индикатор. Уровень развития общественно-деловых районов города.';
comment on column index2020.comp_i23.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i23.city is 'Город';
comment on column index2020.comp_i23.region is 'Субъект РФ';
comment on column index2020.comp_i23.multifunctional_odz_area_2019_ha is 'Площадь общественно-деловых районов с многофункциональной средой на 2019 г., га';
comment on column index2020.comp_i23.multifunctional_odz_area_2020_ha is 'Площадь общественно-деловых районов с многофункциональной средой на 2020 г., га';
comment on column index2020.comp_i23.total_odz_2019 is 'Количество объектов общественно-делового назначения в 2019 г., ед';
comment on column index2020.comp_i23.total_odz_2020 is 'Количество объектов общественно-делового назначения в 2020 г., ед';
comment on column index2020.comp_i23.odz_area_ratio_2019 is 'Уровень развития общественно-деловых районов города - отношение количества объектов к общественно-деловых районов с многофункциональной средой в 2019 г. ед/кв. км.';
comment on column index2020.comp_i23.odz_area_ratio_2020 is 'Уровень развития общественно-деловых районов города - отношение количества объектов к общественно-деловых районов с многофункциональной средой в 2020 г. ед/кв. км.';
comment on column index2020.comp_i23.higher_value is 'В каком году показатель "Уровень развития общественно-деловых районов города" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	multifunctional_odz_area_2019_ha "S общ-дел район с МФУ сред, га (2019)",
	multifunctional_odz_area_2020_ha "S общ-дел район с МФУ сред, га (2020)",
	total_odz_2019 "Кол-во объект общ-дел назнач, ед(2019)",
	total_odz_2020 "Кол-во объект общ-дел назнач, ед(2020)",
	odz_area_ratio_2019 "Ур разв общ-дел районов, ед/км2 (2019)",
	odz_area_ratio_2020 "Ур разв общ-дел районов, ед/км2 (2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i23;
*/
