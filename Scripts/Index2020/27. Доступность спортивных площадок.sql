/* 27-й индикатор. Доступность спортивных площадок */
/* В несколько городов были добавлены точки ручками. Следить за ними в будущем: 772	Ясный, 371 Лихославль, 231 Игарка, 483 Озерск !!!  */
/* Время расчёта ~ 1 мин. */

/* Выборка спортплощадок в отдельную таблицу для оптимизации последующего запроса */
drop table if exists sport;
create temp table sport as 
select * from index2020.data_poi
where rubrics = any('{Каток,Спортивное поле,Спортплощадка}');
create index on sport(id_gis);
create index on sport using gist((geom::geography));

/* Визуализация зданий по отношению к спортивных площадок */
drop table if exists index2020.viz_i27_population; 
create table index2020.viz_i27_population as 
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
from index2020.data_pop_altermag p
left join sport g
	on st_dwithin(g.geom::geography, p.geom::geography, 800, true)
		and g.id_gis = p.id_gis
--where p.id_gis < 100 -- для дебага
;

/* Индексы */
alter table index2020.viz_i27_population add primary key(id);
create index on index2020.viz_i27_population (id_gis);
create index on index2020.viz_i27_population (population);
create index on index2020.viz_i27_population (near_sport);
create index on index2020.viz_i27_population using gist(geom);

/* Комментарии */
comment on table index2020.viz_i27_population is '27-й индикатор. Визуализация жилых домов по отношению к спортивным площадокам';
comment on column index2020.viz_i27_population.id is 'Уникальный идентификатор жилого дома';
comment on column index2020.viz_i27_population.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i27_population.population is 'Количество проживающих в доме';
comment on column index2020.viz_i27_population.near_sport is 'Да, если расположен не далее 800 м. от ближайшей спорт площадки';
comment on column index2020.viz_i27_population.geom is 'Геометрия';



/* Расчёт индикатора */
drop table if exists index2020.ind_i27; 
create table index2020.ind_i27 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(r.pop2020, 0) city_population_rosstat,
	coalesce(case
		when p.near_sport_population > r.pop2020
			then r.pop2020
		else p.near_sport_population
	end, 0)::int near_sport_population,
	coalesce(case
		when p.near_sport_population > r.pop2020
			then 100.00::numeric
		else round((p.near_sport_population * 100 / nullif(r.pop2020::numeric, 0)::numeric), 2)
	end, 0.00) as near_sport_ratio
from index2020.data_boundary b
left join index2020.data_pop_rosstat r using(id_gis)
left join (
	select id_gis, sum(population) filter(where near_sport is true) near_sport_population
	from index2020.viz_i27_population
	group by id_gis
) p using(id_gis)
order by b.id_gis;

/* Индексы */
alter table index2020.ind_i27 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i27 is '27-й индикатор. Доступность спортивных площадок';
comment on column index2020.ind_i27.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i27.city is 'Город';
comment on column index2020.ind_i27.region is 'Субъект РФ';
comment on column index2020.ind_i27.city_population_rosstat is 'Население города (по данным Росстата 2020)';
comment on column index2020.ind_i27.near_sport_population is 'Число жителей, проживающих не далее 800 м. от ближайшей спорт площадки';
comment on column index2020.ind_i27.near_sport_ratio is 'Отношение числа жителей, проживающих не далее 800 м. от ближайшей спорт площадки ко всему населению города';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i27;
create table index2020.comp_i27 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.city_population_rosstat, 0) city_population_rosstat_2019,
	coalesce(i1.city_population_rosstat, 0) city_population_rosstat_2020,
	coalesce(i2.near_sport_population, 0) near_sport_population_2019,
	coalesce(i1.near_sport_population, 0) near_sport_population_2020,
	coalesce(i2.near_sport_ratio, 0) near_sport_ratio_2019,
	coalesce(i1.near_sport_ratio, 0) near_sport_ratio_2020,
	(case 
		when i1.near_sport_ratio > i2.near_sport_ratio
			then 2020
	 	when i1.near_sport_ratio < i2.near_sport_ratio
			then 2019
		else null
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i27 i1
left join index2019.ind_i27 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i27 is 'Сравнение с 2019 годом. 27-й индикатор. Доступность спортивных площадок.';
comment on column index2020.comp_i27.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i27.city is 'Город';
comment on column index2020.comp_i27.region is 'Субъект РФ';
comment on column index2020.comp_i27.city_population_rosstat_2019 is 'Численность населения города в 2019 г., чел. (по данным Росстата), чел.';
comment on column index2020.comp_i27.city_population_rosstat_2020 is 'Численность населения города в 2020 г., чел. (по данным Росстата), чел.';
comment on column index2020.comp_i27.near_sport_population_2019 is 'Численность населения проживающего в радиусе 800 м. от спортплощадки в 2019 г., чел.';
comment on column index2020.comp_i27.near_sport_population_2020 is 'Численность населения проживающего в радиусе 800 м. от спортплощадки в 2020 г., чел.';
comment on column index2020.comp_i27.near_sport_ratio_2019 is 'Доступность спортивных площадок - отношение численности населения проживающего в радиусе 800 м. от спортплощадки ко всему населению города в 2019 г.';
comment on column index2020.comp_i27.near_sport_ratio_2020 is 'Доступность спортивных площадок - отношение численности населения проживающего в радиусе 800 м. от спортплощадки ко всему населению города в 2019 г.';
comment on column index2020.comp_i27.higher_value is 'В каком году показатель "Доступность спортивных площадок" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	city_population_rosstat_2019 "Числ. насел.(Росстат), чел (2019)",
	city_population_rosstat_2020 "Числ. насел.(Росстат), чел (2020)",
	near_sport_population_2019 "Числ. насел. в радиусе спорт пл., чел (2019)",
	near_sport_population_2020 "Числ. насел. в радиусе спорт пл., чел (2020)",
	near_sport_ratio_2019 "Доступн. спорт площадок (2019)",
	near_sport_ratio_2020 "Доступн. спорт площадок (2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i27;
*/
