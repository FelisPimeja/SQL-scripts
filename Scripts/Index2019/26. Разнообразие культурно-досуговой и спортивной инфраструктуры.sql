/* 26-й индикатор. Разнообразие культурно-досуговой и спортивной инфраструктуры */
/* Время расчёта ~ 15 сек. */
drop materialized view if exists index2019.ind_i26 cascade; 
create materialized view index2019.ind_i26 as
with subrubrics_count as (
	 select id_gis, subrubrics,	count(*) poi_count
	 from index2019.data_poi
	 where leisurez is true
--		and id_gis < 100 -- для дебага
	 group by id_gis, subrubrics
)

select
	b.id_gis,
	b.city,
	b.region,
	coalesce(round(((sum((a.poi_count - avr)^2) / count(a.subr_count))^0.5 / min(avr)::numeric), 4), 0.0000) sport_diversity
from index2019.data_boundary b
join (
	 select 
		 id_gis, 
		 poi_count,
		 sum(poi_count) over (partition by id_gis) subr_count,
		 count(subrubrics) over (partition by id_gis) total_poi,
		 sum(poi_count) over (partition by id_gis)/count(subrubrics) over (partition by id_gis) avr
	 from subrubrics_count) a using(id_gis)
group by b.id_gis, b.city, b.region
order by id_gis;

/* Индексы */
create unique index on index2019.ind_i26 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i26 is '26-й индикатор. Разнообразие культурно-досуговой и спортивной инфраструктуры';
comment on column index2019.ind_i26.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i26.city is 'Город';
comment on column index2019.ind_i26.region is 'Субъект РФ';
comment on column index2019.ind_i26.sport_divercity is 'Показатель разнообразия культурно-досуговой и спортивной инфраструктуры';


/* Сводная статистика по сабрубрикам */
drop materialized view if exists index2019.stat_subrubrics cascade; 
create materialized view index2019.stat_subrubrics as
select 
	b.id_gis,
	b.city,
	b.region,
	subrbr.count "всего сабрубрик в городе",
    coalesce(sub1.count, 0) "Азартные игры",
    coalesce(sub2.count, 0) "Архивы и библиотеки",
    coalesce(sub3.count, 0) "Бытовые услуги",
    coalesce(sub4.count, 0) "Водный спорт",
    coalesce(sub5.count, 0) "Водный транспорт",
    coalesce(sub6.count, 0) "Живопись и художественные изделия",
    coalesce(sub7.count, 0) "Кафе",
    coalesce(sub8.count, 0) "Кино и театр",
    coalesce(sub9.count, 0) "Конный спорт",
    coalesce(sub10.count, 0) "Культурные центры",
    coalesce(sub11.count, 0) "Музеи и выставки",
    coalesce(sub12.count, 0) "Музыка и хореография",
    coalesce(sub13.count, 0) "Общественное питание",
    coalesce(sub14.count, 0) "Организация праздников",
    coalesce(sub15.count, 0) "Парки и зоопарки",
    coalesce(sub16.count, 0) "Прочее",
    coalesce(sub17.count, 0) "Развлечения",
    coalesce(sub18.count, 0) "Санатории и дома отдыха",
    coalesce(sub19.count, 0) "Спортивные клубы и базы",
    coalesce(sub20.count, 0) "Спортивные организации",
    coalesce(sub21.count, 0) "Спортивные сооружения",
    coalesce(sub22.count, 0) "Туризм",
    coalesce(sub23.count, 0) "Уход за внешностью",
    coalesce(sub24.count, 0) "Фитнес и йога",
    coalesce(sub25.count, 0) "Экстремальный спорт"
from index2019.data_boundary b 
left join (select id_gis, count(distinct subrubrics) count from index2019.data_poi where subrubrics = any('{Азартные игры,Архивы и библиотеки,Бытовые услуги,Водный спорт,Водный транспорт,Живопись и художественные изделия,Кафе,Кино и театр,Конный спорт,Культурные центры,Музеи и выставки,Музыка и хореография,Общественное питание,Организация праздников,Парки и зоопарки,Прочее,Развлечения,Санатории и дома отдыха,Спортивные клубы и базы,Спортивные организации,Спортивные сооружения,Туризм,Уход за внешностью,Фитнес и йога,Экстремальный спорт}')  group by id_gis) subrbr using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Азартные игры' group by id_gis) sub1 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Архивы и библиотеки' group by id_gis) sub2 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Бытовые услуги' group by id_gis) sub3 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Водный спорт' group by id_gis) sub4 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Водный транспорт' group by id_gis) sub5 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Живопись и художественные изделия' group by id_gis) sub6 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Кафе' group by id_gis) sub7 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Кино и театр' group by id_gis) sub8 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Конный спорт' group by id_gis) sub9 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Культурные центры' group by id_gis) sub10 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Музеи и выставки' group by id_gis) sub11 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Музыка и хореография' group by id_gis) sub12 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Общественное питание' group by id_gis) sub13 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Организация праздников' group by id_gis) sub14 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Парки и зоопарки' group by id_gis) sub15 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Прочее' group by id_gis) sub16 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Развлечения' group by id_gis) sub17 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Санатории и дома отдыха' group by id_gis) sub18 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Спортивные клубы и базы' group by id_gis) sub19 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Спортивные организации' group by id_gis) sub20 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Спортивные сооружения' group by id_gis) sub21 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Туризм' group by id_gis) sub22 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Уход за внешностью' group by id_gis) sub23 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Фитнес и йога' group by id_gis) sub24 using(id_gis)
left join (select id_gis, count(*) count from index2019.data_poi where subrubrics = 'Экстремальный спорт' group by id_gis) sub25 using(id_gis)
order by id_gis;

/* Индексы */
create unique index on index2019.stat_subrubrics (id_gis);

/* Комментарии */
comment on materialized view index2019.stat_subrubrics is '26-й индикатор. Сводная статистика по сабрубрикам';
comment on column index2019.stat_subrubrics.id_gis is 'Уникальный идентификатор города';
comment on column index2019.stat_subrubrics.city is 'Город';
comment on column index2019.stat_subrubrics.region is 'Субъект РФ';
comment on column index2019.stat_subrubrics."Азартные игры" is 'Азартные игры';
comment on column index2019.stat_subrubrics."Архивы и библиотеки" is 'Архивы и библиотеки';
comment on column index2019.stat_subrubrics."Бытовые услуги" is 'Бытовые услуги';
comment on column index2019.stat_subrubrics."Водный спорт" is 'Водный спорт';
comment on column index2019.stat_subrubrics."Водный транспорт" is 'Водный транспорт';
comment on column index2019.stat_subrubrics."Живопись и художественные изделия" is 'Живопись и художественные изделия';
comment on column index2019.stat_subrubrics."Кафе" is 'Кафе';
comment on column index2019.stat_subrubrics."Кино и театр" is 'Кино и театр';
comment on column index2019.stat_subrubrics."Конный спорт" is 'Конный спорт';
comment on column index2019.stat_subrubrics."Культурные центры" is 'Культурные центры';
comment on column index2019.stat_subrubrics."Музеи и выставки" is 'Музеи и выставки';
comment on column index2019.stat_subrubrics."Музыка и хореография" is 'Музыка и хореография';
comment on column index2019.stat_subrubrics."Общественное питание" is 'Общественное питание';
comment on column index2019.stat_subrubrics."Организация праздников" is 'Организация праздников';
comment on column index2019.stat_subrubrics."Парки и зоопарки" is 'Парки и зоопарки';
comment on column index2019.stat_subrubrics."Прочее" is 'Прочее';
comment on column index2019.stat_subrubrics."Развлечения" is 'Развлечения';
comment on column index2019.stat_subrubrics."Санатории и дома отдыха" is 'Санатории и дома отдыха';
comment on column index2019.stat_subrubrics."Спортивные клубы и базы" is 'Спортивные клубы и базы';
comment on column index2019.stat_subrubrics."Спортивные организации" is 'Спортивные организации';
comment on column index2019.stat_subrubrics."Спортивные сооружения" is 'Спортивные сооружения';
comment on column index2019.stat_subrubrics."Туризм" is 'Туризм';
comment on column index2019.stat_subrubrics."Уход за внешностью" is 'Уход за внешностью';
comment on column index2019.stat_subrubrics."Фитнес и йога" is 'Фитнес и йога';
comment on column index2019.stat_subrubrics."Экстремальный спорт" is 'Экстремальный спорт';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i26;
create view index2019.comp_i26 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round(i2.i26::numeric, 4), 0) sport_divercity_2018,
	coalesce(i1.sport_divercity, 0) sport_divercity_2019,
	(case 
		when coalesce(i1.sport_divercity, 0) > coalesce(round(i2.i26::numeric, 4), 0)
			then 2019
	 	when coalesce(i1.sport_divercity, 0) = coalesce(round(i2.i26::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value, -- в каком году показатель выше
	coalesce(i3."Всего сабрубрик в городе", 0)::smallint "Всего сабрубрик в городе_2018",
	coalesce(i4."всего сабрубрик в городе", 0)::smallint "Всего сабрубрик в городе_2019",
	coalesce(i3."Азартные игры", 0)::smallint "Азартные игры_2018",
	coalesce(i4."Азартные игры", 0)::smallint "Азартные игры_2019",
	coalesce(i3."Архивы и библиотеки", 0)::smallint "Архивы и библиотеки_2018",
	coalesce(i4."Архивы и библиотеки", 0)::smallint "Архивы и библиотеки_2019",
	coalesce(i3."Бытовые услуги", 0)::smallint "Бытовые услуги_2018",
	coalesce(i4."Бытовые услуги", 0)::smallint "Бытовые услуги_2019",
	coalesce(i3."Водный спорт", 0)::smallint "Водный спорт_2018",
	coalesce(i4."Водный спорт", 0)::smallint "Водный спорт_2019",
	coalesce(i3."Водный транспорт", 0)::smallint "Водный транспорт_2018",
	coalesce(i4."Водный транспорт", 0)::smallint "Водный транспорт_2019",
	coalesce(i3."Живопись и художественные изделия", 0)::smallint "Живопись и худож. изделия_2018",
	coalesce(i4."Живопись и художественные изделия", 0)::smallint "Живопись и худож. изделия_2019",
	coalesce(i3."Кафе", 0)::smallint "Кафе_2018",
	coalesce(i4."Кафе", 0)::smallint "Кафе_2019",
	coalesce(i3."Кино и театр", 0)::smallint "Кино и театр_2018",
	coalesce(i4."Кино и театр", 0)::smallint "Кино и театр_2019",
	coalesce(i3."Конный спорт", 0)::smallint "Конный спорт_2018",
	coalesce(i4."Конный спорт", 0)::smallint "Конный спорт_2019",
	coalesce(i3."Культурные центры", 0)::smallint "Культурные центры_2018",
	coalesce(i4."Культурные центры", 0)::smallint "Культурные центры_2019",
	coalesce(i3."Музеи и выставки", 0)::smallint "Музеи и выставки_2018",
	coalesce(i4."Музеи и выставки", 0)::smallint "Музеи и выставки_2019",
	coalesce(i3."Музыка и хореография", 0)::smallint "Музыка и хореография_2018",
	coalesce(i4."Музыка и хореография", 0)::smallint "Музыка и хореография_2019",
	coalesce(i3."Общественное питание", 0)::smallint "Общественное питание_2018",
	coalesce(i4."Общественное питание", 0)::smallint "Общественное питание_2019",
	coalesce(i3."Организация праздников", 0)::smallint "Организация праздников_2018",
	coalesce(i4."Организация праздников", 0)::smallint "Организация праздников_2019",
	coalesce(i3."Парки и зоопарки", 0)::smallint "Парки и зоопарки_2018",
	coalesce(i4."Парки и зоопарки", 0)::smallint "Парки и зоопарки_2019",
	coalesce(i3."Прочее", 0)::smallint "Прочее_2018",
	coalesce(i4."Прочее", 0)::smallint "Прочее_2019",
	coalesce(i3."Развлечения", 0)::smallint "Развлечения_2018",
	coalesce(i4."Развлечения", 0)::smallint "Развлечения_2019",
	coalesce(i3."Санатории и дома отдыха", 0)::smallint "Санатории и дома отдыха_2018",
	coalesce(i4."Санатории и дома отдыха", 0)::smallint "Санатории и дома отдыха_2019",
	coalesce(i3."Спортивные клубы и базы", 0)::smallint "Спортивные клубы и базы_2018",
	coalesce(i4."Спортивные клубы и базы", 0)::smallint "Спортивные клубы и базы_2019",
	coalesce(i3."Спортивные организации", 0)::smallint "Спортивные организации_2018",
	coalesce(i4."Спортивные организации", 0)::smallint "Спортивные организации_2019",
	coalesce(i3."Спортивные сооружения", 0)::smallint "Спортивные сооружения_2018",
	coalesce(i4."Спортивные сооружения", 0)::smallint "Спортивные сооружения_2019",
	coalesce(i3."Туризм", 0)::smallint "Туризм_2018",
	coalesce(i4."Туризм", 0)::smallint "Туризм_2019",
	coalesce(i3."Уход за внешностью", 0)::int "Уход за внешностью_2018",
	coalesce(i4."Уход за внешностью", 0)::int "Уход за внешностью_2019",
	coalesce(i3."Фитнес и йога", 0)::smallint "Фитнес и йога_2018",
	coalesce(i4."Фитнес и йога", 0)::smallint "Фитнес и йога_2019",
	coalesce(i3."Экстремальный спорт", 0)::smallint "Экстремальный спорт_2018",
	coalesce(i4."Экстремальный спорт", 0)::smallint "Экстремальный спорт_2019"
from index2019.ind_i26 i1
left join index2018.i26_leisure_diversity_old i2 using(id_gis)
left join index2018.i26_subrubrics i3 using(id_gis)
left join index2019.stat_subrubrics i4 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i26 is 'Сравнение с 2018 годом. 26-й индикатор. Разнообразие культурно-досуговой и спортивной инфраструктуры.';
comment on column index2019.comp_i26.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i26.city is 'Город';
comment on column index2019.comp_i26.region is 'Субъект РФ';
comment on column index2019.comp_i26.sport_divercity_2018 is 'Разнообразие спортивной инфраструктуры на 2018 год';
comment on column index2019.comp_i26.sport_divercity_2019 is 'Разнообразие спортивной инфраструктуры на 2019 год';
comment on column index2019.comp_i26.higher_value is 'В каком году показатель "Разнообразие спортивной инфраструктуры" выше';
comment on column index2019.comp_i26."Всего сабрубрик в городе_2018" is 'Вего сабрубрик в городе на 2018 год';
comment on column index2019.comp_i26."Всего сабрубрик в городе_2019" is 'Всего сабрубрик в городе на 2019 год';
comment on column index2019.comp_i26."Азартные игры_2018" is 'Азартные игры на 2018 год';
comment on column index2019.comp_i26."Азартные игры_2019" is 'Азартные игры на 2019 год';
comment on column index2019.comp_i26."Архивы и библиотеки_2018" is 'Архивы и библиотеки на 2018 год';
comment on column index2019.comp_i26."Архивы и библиотеки_2019" is 'Архивы и библиотеки на 2019 год';
comment on column index2019.comp_i26."Бытовые услуги_2018" is 'Бытовые услуги на 2018 год';
comment on column index2019.comp_i26."Бытовые услуги_2019" is 'Бытовые услуги на 2019 год';
comment on column index2019.comp_i26."Водный спорт_2018" is 'Водный спорт на 2018 год';
comment on column index2019.comp_i26."Водный спорт_2019" is 'Водный спорт на 2019 год';
comment on column index2019.comp_i26."Водный транспорт_2018" is 'Водный транспорт на 2018 год';
comment on column index2019.comp_i26."Водный транспорт_2019" is 'Водный транспорт на 2019 год';
comment on column index2019.comp_i26."Живопись и худож. изделия_2018" is 'Живопись и художественные изделия на 2018 год';
comment on column index2019.comp_i26."Живопись и худож. изделия_2019" is 'Живопись и художественные изделия на 2019 год';
comment on column index2019.comp_i26."Кафе_2018" is 'Кафе на 2018 год';
comment on column index2019.comp_i26."Кафе_2019" is 'Кафе на 2019 год';
comment on column index2019.comp_i26."Кино и театр_2018" is 'Кино и театр на 2018 год';
comment on column index2019.comp_i26."Кино и театр_2019" is 'Кино и театр на 2019 год';
comment on column index2019.comp_i26."Конный спорт_2018" is 'Конный спорт на 2018 год';
comment on column index2019.comp_i26."Конный спорт_2019" is 'Конный спорт на 2019 год';
comment on column index2019.comp_i26."Культурные центры_2018" is 'Культурные центры на 2018 год';
comment on column index2019.comp_i26."Культурные центры_2019" is 'Культурные центры на 2019 год';
comment on column index2019.comp_i26."Музеи и выставки_2018" is 'Музеи и выставки на 2018 год';
comment on column index2019.comp_i26."Музеи и выставки_2019" is 'Музеи и выставки на 2019 год';
comment on column index2019.comp_i26."Музыка и хореография_2018" is 'Музыка и хореография на 2018 год';
comment on column index2019.comp_i26."Музыка и хореография_2019" is 'Музыка и хореография на 2019 год';
comment on column index2019.comp_i26."Общественное питание_2018" is 'Общественное питание на 2018 год';
comment on column index2019.comp_i26."Общественное питание_2019" is 'Общественное питание на 2019 год';
comment on column index2019.comp_i26."Организация праздников_2018" is 'Организация праздников на 2018 год';
comment on column index2019.comp_i26."Организация праздников_2019" is 'Организация праздников на 2019 год';
comment on column index2019.comp_i26."Парки и зоопарки_2018" is 'Парки и зоопарки на 2018 год';
comment on column index2019.comp_i26."Парки и зоопарки_2019" is 'Парки и зоопарки на 2019 год';
comment on column index2019.comp_i26."Прочее_2018" is 'Прочее на 2018 год';
comment on column index2019.comp_i26."Прочее_2019" is 'Прочее на 2019 год';
comment on column index2019.comp_i26."Развлечения_2018" is 'Развлечения на 2018 год';
comment on column index2019.comp_i26."Развлечения_2019" is 'Развлечения на 2019 год';
comment on column index2019.comp_i26."Санатории и дома отдыха_2018" is 'Санатории и дома отдыха на 2018 год';
comment on column index2019.comp_i26."Санатории и дома отдыха_2019" is 'Санатории и дома отдыха на 2019 год';
comment on column index2019.comp_i26."Спортивные клубы и базы_2018" is 'Спортивные клубы и базы на 2018 год';
comment on column index2019.comp_i26."Спортивные клубы и базы_2019" is 'Спортивные клубы и базы на 2019 год';
comment on column index2019.comp_i26."Спортивные организации_2018" is 'Спортивные организации на 2018 год';
comment on column index2019.comp_i26."Спортивные организации_2019" is 'Спортивные организации на 2019 год';
comment on column index2019.comp_i26."Спортивные сооружения_2018" is 'Спортивные сооружения на 2018 год';
comment on column index2019.comp_i26."Спортивные сооружения_2019" is 'Спортивные сооружения на 2019 год';
comment on column index2019.comp_i26."Туризм_2018" is 'Туризм на 2018 год';
comment on column index2019.comp_i26."Туризм_2019" is 'Туризм на 2019 год';
comment on column index2019.comp_i26."Уход за внешностью_2018" is 'Уход за внешностью на 2018 год';
comment on column index2019.comp_i26."Уход за внешностью_2019" is 'Уход за внешностью на 2019 год';
comment on column index2019.comp_i26."Фитнес и йога_2018" is 'Фитнес и йога на 2018 год';
comment on column index2019.comp_i26."Фитнес и йога_2019" is 'Фитнес и йога на 2019 год';
comment on column index2019.comp_i26."Экстремальный спорт_2018" is 'Экстремальный спорт на 2018 год';
comment on column index2019.comp_i26."Экстремальный спорт_2019" is 'Экстремальный спорт на 2019 год';