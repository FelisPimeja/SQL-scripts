/* 5-й индикатор. Разнообразие услуг в жилой зоне */
/* Время расчёта ~ 1 сек. */
drop table if exists index2020.ind_i05 cascade; 
create table index2020.ind_i05 as
with diversity as (
	select
		id_gis,
		sum(area_ha) residential_area_ha,
		coalesce(sum(area_ha) filter (where sbrbr_count > 7), 0.00) diverse_area_ha -- отсечка в 7 субрубрик подобрана руками при первом расчёте индекса
	from index2020.stat_zoning
	where z1_pop > 0
--		and id_gis < 10 -- для дебага
	group by id_gis
)
select
	b.id_gis,
	b.city,
	b.region,
	s.residential_area_ha,
	s.diverse_area_ha,
	coalesce(round((s.diverse_area_ha / s.residential_area_ha), 4), 0) as diverse_area_ratio
from index2020.data_boundary b
left join diversity s using(id_gis)
order by b.id_gis;

/* Индексы */
alter table index2020.ind_i05 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i05 is '5-й индикатор. Разнообразие услуг в жилой зоне';
comment on column index2020.ind_i05.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i05.city is 'Город';
comment on column index2020.ind_i05.region is 'Субъект РФ';
comment on column index2020.ind_i05.residential_area_ha is 'Площадь жилой зоны (по гексагональной сетке)';
comment on column index2020.ind_i05.diverse_area_ha is 'Площадь функционально разнообразной жилой зоны (по гексагональной сетке)';
comment on column index2020.ind_i05.diverse_area_ratio is 'Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны';

/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i05;
create table index2020.comp_i05 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	i2.residential_area_ha residential_area_ha_2019,
	i1.residential_area_ha residential_area_ha_2020,
	i2.diverse_area_ha diverse_area_ha_2019,
	i1.diverse_area_ha diverse_area_ha_2020,
	i2.diverse_area_ratio diverse_area_ratio_2019,
	i1.diverse_area_ratio diverse_area_ratio_2020,
	(case 
		when i1.diverse_area_ratio > i2.diverse_area_ratio
			then 2020
	 	when i1.diverse_area_ratio = i2.diverse_area_ratio
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i05 i1
left join index2019.ind_i05 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i05 is 'Сравнение с 2019 годом. 5-й индикатор. Разнообразие услуг в жилой зоне.';
comment on column index2020.comp_i05.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i05.city is 'Город';
comment on column index2020.comp_i05.region is 'Субъект РФ';
comment on column index2020.comp_i05.residential_area_ha_2019 is 'Площадь жилой зоны  2019 г.(по гексагональной сетке)';
comment on column index2020.comp_i05.residential_area_ha_2020 is 'Площадь жилой зоны  2020 г.(по гексагональной сетке)';
comment on column index2020.comp_i05.diverse_area_ha_2019 is 'Площадь функционально разнообразной жилой зоны 2019 г.(по гексагональной сетке)';
comment on column index2020.comp_i05.diverse_area_ha_2020 is 'Площадь функционально разнообразной жилой зоны 2020 г.(по гексагональной сетке)';
comment on column index2020.comp_i05.diverse_area_ratio_2019 is 'Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны 2019 г.';
comment on column index2020.comp_i05.diverse_area_ratio_2020 is 'Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны 2020 г.';
comment on column index2020.comp_i05.higher_value is ' В каком году показатель "Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	residential_area_ha_2019 "Площадь жилой зоны, га (2019)",
	residential_area_ha_2020 "Площадь жилой зоны, га (2020)",
	diverse_area_ha_2019 "Площ. функц. разнообр. зоны, га (2019)",
	diverse_area_ha_2020 "Площ. функц. разнообр. зоны, га (2020)",
	diverse_area_ratio_2019 "Отношение площадей (2019)",
	diverse_area_ratio_2020 "Отношение площадей (2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i05;
*/
