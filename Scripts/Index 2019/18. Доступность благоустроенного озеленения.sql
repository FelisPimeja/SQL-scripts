/* 18-й индикатор. Доступность благоустроенного озеленения */
/* Время расчёта ~ 6 часов */
/* Визуализация зданий по отношению к благоустроенному озеленению */
drop materialized view if exists index2019.viz_i18_population cascade; 
create materialized view index2019.viz_i18_population as 
select distinct on (p.id)
	p.id,
	p.id_gis,
	p.population,
	case 
		when g.id is not null
			then true::bool
		else false::bool
	end	near_greenery,
	p.geom
from index2019.data_pop_altermag p
left join index2019.data_greenery g
	on st_dwithin(g.geom::geography, p.geom::geography, 800, true)
		and g.id_gis = p.id_gis
--where p.id_gis < 100 -- для дебага
;

/* Индексы */
create unique index on index2019.viz_i18_population (id);
create index on index2019.viz_i18_population (id_gis);
create index on index2019.viz_i18_population (population);
create index on index2019.viz_i18_population (near_greenery);
create index on index2019.viz_i18_population using gist(geom);

/* Комментарии */
comment on materialized view index2019.viz_i18_population is '18-й индикатор. Визуализация жилых домов по отношению к благоустроенному озеленению';
comment on column index2019.viz_i18_population.id is 'Уникальный идентификатор жилого дома';
comment on column index2019.viz_i18_population.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i18_population.population is 'количество проживающих в доме';
comment on column index2019.viz_i18_population.near_greenery is 'Да, если расположен не далее 800 м. от ближайшего парка';
comment on column index2019.viz_i18_population.geom is 'Геометрия';



/* Расчёт индикатора */
drop materialized view if exists index2019.ind_i18 cascade; 
create materialized view index2019.ind_i18 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(r.pop2019, 0) city_population_rosstat,
	coalesce(case
		when p.near_greenery_population > r.pop2019
			then r.pop2019
		else p.near_greenery_population
	end, 0)::int near_greenery_population,
	coalesce(case
		when p.near_greenery_population > r.pop2019
			then 100.00::numeric
		else round((p.near_greenery_population * 100 / nullif(r.pop2019::numeric, 0)::numeric), 2)
	end, 0.00) as near_greenery_ratio
from index2019.data_boundary b
left join index2019.data_pop_rosstat r using(id_gis)
left join (
	select id_gis, sum(population) filter(where near_greenery is true) near_greenery_population
	from index2019.viz_i18_population
	group by id_gis
) p using(id_gis)
order by b.id_gis;

/* Индексы */
create unique index on index2019.ind_i18 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i18 is '18-й индикатор. Доступность благоустроенного озеленения';
comment on column index2019.ind_i18.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i18.city is 'Город';
comment on column index2019.ind_i18.region is 'Субъект РФ';
comment on column index2019.ind_i18.city_population_rosstat is 'Население города (по данным Росстата 2019)';
comment on column index2019.ind_i18.near_greenery_population is 'Число жителей, проживающих не далее 800 м. от ближайшего парка';
comment on column index2019.ind_i18.near_greenery_ratio is 'Отношение числа жителей, проживающих не далее 800 м. от ближайшего парка ко всему населению города';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i18;
create view index2019.comp_i18 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.city_population, 0) city_population_rosstat_2018,
	coalesce(i1.city_population_rosstat, 0) city_population_rosstat_2019,
	coalesce(i2.near_greenery_population, 0) near_greenery_population_2018,
	coalesce(i1.near_greenery_population, 0) near_greenery_population_2019,
	coalesce(round((i2.pop_ratio)::numeric, 4), 0) near_greenery_ratio_2018,
	coalesce(round((i1.near_greenery_ratio / 100)::numeric, 4), 0) near_greenery_ratio_2019,
	(case 
		when coalesce(round((i1.near_greenery_ratio / 100)::numeric, 4), 0) > coalesce(round(i2.pop_ratio::numeric, 4), 0)
			then 2019
	 	when coalesce(round((i1.near_greenery_ratio / 100)::numeric, 4), 0) = coalesce(round(i2.pop_ratio::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i18 i1
left join index2018.i18_greenery_access i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i18 is 'Сравнение с 2018 годом. 18-й индикатор. Доступность благоустроенного озеленения.';
comment on column index2019.comp_i18.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i18.city is 'Город';
comment on column index2019.comp_i18.region is 'Субъект РФ';
comment on column index2019.comp_i18.city_population_rosstat_2018 is 'Численность населения города в 2018 г., чел. (по данным Росстата), чел.';
comment on column index2019.comp_i18.city_population_rosstat_2019 is 'Численность населения города в 2019 г., чел. (по данным Росстата), чел.';
comment on column index2019.comp_i18.near_greenery_population_2018 is 'Численность населения проживающего в радиусе 800 м. от парка в 2018 г., чел.';
comment on column index2019.comp_i18.near_greenery_population_2019 is 'Численность населения проживающего в радиусе 800 м. от парка в 2019 г., чел.';
comment on column index2019.comp_i18.near_greenery_ratio_2018 is 'Доступность благоустроенного озеленения - отношение численности населения проживающего в радиусе 800 м. от парка ко всему населению города в 2018 г.';
comment on column index2019.comp_i18.near_greenery_ratio_2019 is 'Доступность благоустроенного озеленения - отношение численности населения проживающего в радиусе 800 м. от парка ко всему населению города в 2019 г.';
comment on column index2019.comp_i18.higher_value is 'В каком году показатель "Доступность благоустроенного озеленения" выше';