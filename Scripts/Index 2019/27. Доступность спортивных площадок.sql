/* 27-й индикатор. Доступность спортивных площадок */
/* В несколько городов были добавлены точки ручками. Следить за ними в будущем: 772	Ясный, 371 Лихославль, 231 Игарка, 483 Озерск !!!  */
/* Время расчёта ~ 10 мин. */
/* Визуализация зданий по отношению к спортивных площадок */
drop materialized view if exists index2019.viz_i27_population cascade; 
create materialized view index2019.viz_i27_population as 
select distinct on (p.id)
	p.id,
	p.id_gis,
	p.population,
	case 
		when g.id is not null
			then true::bool
		else false::bool
	end	near_sport,
	p.geom
from index2019.data_pop_altermag p
left join index2019.data_poi g
	on st_dwithin(g.geom::geography, p.geom::geography, 800, true)
		and g.rubrics = any('{Каток,Спортивное поле,Спортплощадка}')
		and g.id_gis = p.id_gis
--where p.id_gis < 100 -- для дебага
;

/* Индексы */
create unique index on index2019.viz_i27_population (id);
create index on index2019.viz_i27_population (id_gis);
create index on index2019.viz_i27_population (population);
create index on index2019.viz_i27_population (near_sport);
create index on index2019.viz_i27_population using gist(geom);

/* Комментарии */
comment on materialized view index2019.viz_i27_population is '27-й индикатор. Визуализация жилых домов по отношению к спортивным площадокам';
comment on column index2019.viz_i27_population.id is 'Уникальный идентификатор жилого дома';
comment on column index2019.viz_i27_population.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i27_population.population is 'Количество проживающих в доме';
comment on column index2019.viz_i27_population.near_sport is 'Да, если расположен не далее 800 м. от ближайшей спорт площадки';
comment on column index2019.viz_i27_population.geom is 'Геометрия';



/* Расчёт индикатора */
drop materialized view if exists index2019.ind_i27 cascade; 
create materialized view index2019.ind_i27 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(r.pop2019, 0) city_population_rosstat,
	coalesce(case
		when p.near_sport_population > r.pop2019
			then r.pop2019
		else p.near_sport_population
	end, 0)::int near_sport_population,
	coalesce(case
		when p.near_sport_population > r.pop2019
			then 100.00::numeric
		else round((p.near_sport_population * 100 / nullif(r.pop2019::numeric, 0)::numeric), 2)
	end, 0.00) as near_sport_ratio
from index2019.data_boundary b
left join index2019.data_pop_rosstat r using(id_gis)
left join (
	select id_gis, sum(population) filter(where near_sport is true) near_sport_population
	from index2019.viz_i27_population
	group by id_gis
) p using(id_gis)
order by b.id_gis;

/* Индексы */
create unique index on index2019.ind_i27 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i27 is '27-й индикатор. Доступность спортивных площадок';
comment on column index2019.ind_i27.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i27.city is 'Город';
comment on column index2019.ind_i27.region is 'Субъект РФ';
comment on column index2019.ind_i27.city_population_rosstat is 'Население города (по данным Росстата 2019)';
comment on column index2019.ind_i27.near_sport_population is 'Число жителей, проживающих не далее 800 м. от ближайшей спорт площадки';
comment on column index2019.ind_i27.near_sport_ratio is 'Отношение числа жителей, проживающих не далее 800 м. от ближайшей спорт площадки ко всему населению города';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i27;
create view index2019.comp_i27 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.city_population, 0) city_population_rosstat_2018,
	coalesce(i1.city_population_rosstat, 0) city_population_rosstat_2019,
	coalesce(i2.near_sport_population, 0) near_sport_population_2018,
	coalesce(i1.near_sport_population, 0) near_sport_population_2019,
	coalesce(round((i2.pop_ratio)::numeric, 4), 0) near_sport_ratio_2018,
	coalesce(i1.near_sport_ratio, 0) near_sport_ratio_2019,
	(case 
		when coalesce(i1.near_sport_ratio, 0) > coalesce(round((i2.pop_ratio)::numeric, 4), 0)
			then 2019
	 	when coalesce(i1.near_sport_ratio, 0) = coalesce(round((i2.pop_ratio)::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i27 i1
left join index2018.i27_sport_access i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i27 is 'Сравнение с 2018 годом. 27-й индикатор. Доступность спортивных площадок.';
comment on column index2019.comp_i27.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i27.city is 'Город';
comment on column index2019.comp_i27.region is 'Субъект РФ';
comment on column index2019.comp_i27.city_population_rosstat_2018 is 'Численность населения города в 2018 г., чел. (по данным Росстата), чел.';
comment on column index2019.comp_i27.city_population_rosstat_2019 is 'Численность населения города в 2019 г., чел. (по данным Росстата), чел.';
comment on column index2019.comp_i27.near_sport_population_2018 is 'Численность населения проживающего в радиусе 800 м. от спортплощадки в 2018 г., чел.';
comment on column index2019.comp_i27.near_sport_population_2019 is 'Численность населения проживающего в радиусе 800 м. от спортплощадки в 2019 г., чел.';
comment on column index2019.comp_i27.near_sport_ratio_2018 is 'Доступность спортивных площадок - отношение численности населения проживающего в радиусе 800 м. от спортплощадки ко всему населению города в 2018 г.';
comment on column index2019.comp_i27.near_sport_ratio_2019 is 'Доступность спортивных площадок - отношение численности населения проживающего в радиусе 800 м. от спортплощадки ко всему населению города в 2018 г.';
comment on column index2019.comp_i27.higher_value is 'В каком году показатель "Доступность спортивных площадок" выше';