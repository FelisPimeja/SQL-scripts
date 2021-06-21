/* 5-й индикатор. Разнообразие услуг в жилой зоне */
/* Время расчёта ~ 1 сек. */
drop materialized view if exists index2019.ind_i05 cascade; 
create materialized view index2019.ind_i05 as
with diversity as (
	select
		id_gis,
		sum(area_ha) residential_area_ha,
		coalesce(sum(area_ha) filter (where sbrbr_count > 7), 0.00) diverse_area_ha -- отсечка в 7 субрубрик подобрана руками при первом расчёте индекса
	from index2019.stat_zoning
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
from index2019.data_boundary b
left join diversity s using(id_gis)
order by b.id_gis;

/* Индексы */
create unique index on index2019.ind_i18 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i05 is '5-й индикатор. Разнообразие услуг в жилой зоне';
comment on column index2019.ind_i05.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i05.city is 'Город';
comment on column index2019.ind_i05.region is 'Субъект РФ';
comment on column index2019.ind_i05.residential_area_ha is 'Площадь жилой зоны (по гексагональной сетке)';
comment on column index2019.ind_i05.diverse_area_ha is 'Площадь функционально разнообразной жилой зоны (по гексагональной сетке)';
comment on column index2019.ind_i05.diverse_area_ratio is 'Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i05;
create view index2019.comp_i05 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	round(to_number(i2.resident_area_ha, '99999D99')::numeric, 2) residential_area_ha_2018,
	i1.residential_area_ha residential_area_ha_2019,
	round(to_number(i2.subr7_diverse_area_ha, '99999D99')::numeric, 2) diverse_area_ha_2018,
	i1.diverse_area_ha diverse_area_ha_2019,
	round(to_number(i2.area_ratio7,  '0D99999')::numeric, 4) diverse_area_ratio_2018,
	i1.diverse_area_ratio diverse_area_ratio_2019,
	(case 
		when i1.diverse_area_ratio > round(to_number(i2.area_ratio7, '0D99999')::numeric, 4)
			then 2019
	 	when i1.diverse_area_ratio = round(to_number(i2.area_ratio7, '0D99999')::numeric, 4)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i05 i1
left join index2018.i05_subrubrics_diversity i2 on i1.id_gis = to_number(i2.id_gis, '9999')
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i05 is 'Сравнение с 2018 годом. 5-й индикатор. Разнообразие услуг в жилой зоне.';
comment on column index2019.comp_i05.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i05.city is 'Город';
comment on column index2019.comp_i05.region is 'Субъект РФ';
comment on column index2019.comp_i05.residential_area_ha_2018 is 'Площадь жилой зоны  2018 г.(по гексагональной сетке)';
comment on column index2019.comp_i05.residential_area_ha_2019 is 'Площадь жилой зоны  2019 г.(по гексагональной сетке)';
comment on column index2019.comp_i05.diverse_area_ha_2018 is 'Площадь функционально разнообразной жилой зоны 2018 г.(по гексагональной сетке)';
comment on column index2019.comp_i05.diverse_area_ha_2019 is 'Площадь функционально разнообразной жилой зоны 2019 г.(по гексагональной сетке)';
comment on column index2019.comp_i05.diverse_area_ratio_2018 is 'Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны 2018 г.';
comment on column index2019.comp_i05.diverse_area_ratio_2019 is 'Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны 2019 г.';
comment on column index2019.comp_i05.higher_value is ' В каком году показатель "Отношение площади функционально разнообразной жилой зоны к общей площади жилой зоны" выше';