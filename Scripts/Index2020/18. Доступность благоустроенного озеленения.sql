/* 18-й индикатор. Доступность благоустроенного озеленения */
/* Время расчёта ~ 5 мин. */
/* Визуализация зданий по отношению к благоустроенному озеленению */

--create index on index2020.data_greenery (id_gis);
--create index on index2020.data_greenery using gist((geom::geography));

/* Проставляем id_gis для зелени если были правки */
update index2020.data_greenery g
	set id_gis = b.id_gis
	from index2020.data_boundary b
	where g.id_gis is null
		and st_intersects(g.geom, b.geom)

drop table if exists index2020.viz_i18_population cascade; 
create table index2020.viz_i18_population as 
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
from index2020.data_pop_altermag p
left join index2020.data_greenery g
	on st_dwithin(g.geom::geography, p.geom::geography, 800, true)
		and g.id_gis = p.id_gis
--where p.id_gis < 100 -- для дебага
;
/* Индексы */
alter table index2020.viz_i18_population add primary key(id);
create index on index2020.viz_i18_population (id_gis);
create index on index2020.viz_i18_population (population);
create index on index2020.viz_i18_population (near_greenery);
create index on index2020.viz_i18_population using gist(geom);

/* Комментарии */
comment on table index2020.viz_i18_population is '18-й индикатор. Визуализация жилых домов по отношению к благоустроенному озеленению';
comment on column index2020.viz_i18_population.id is 'Уникальный идентификатор жилого дома';
comment on column index2020.viz_i18_population.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i18_population.population is 'количество проживающих в доме';
comment on column index2020.viz_i18_population.near_greenery is 'Да, если расположен не далее 800 м. от ближайшего парка';
comment on column index2020.viz_i18_population.geom is 'Геометрия';


/* Расчёт индикатора */
drop table if exists index2020.ind_i18; 
create table index2020.ind_i18 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(r.pop2020, 0) city_population_rosstat,
	coalesce(case
		when p.near_greenery_population > r.pop2020
			then r.pop2020
		else p.near_greenery_population
	end, 0)::int near_greenery_population,
	coalesce(case
		when p.near_greenery_population > r.pop2020
			then 100.00::numeric
		else round((p.near_greenery_population * 100 / nullif(r.pop2020::numeric, 0)::numeric), 2)
	end, 0.00) as near_greenery_ratio
from index2020.data_boundary b
left join index2020.data_pop_rosstat r using(id_gis)
left join (
	select id_gis, sum(population) filter(where near_greenery is true) near_greenery_population
	from index2020.viz_i18_population
	group by id_gis
) p using(id_gis)
order by b.id_gis;

/* Индексы */
alter table index2020.ind_i18 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i18 is '18-й индикатор. Доступность благоустроенного озеленения';
comment on column index2020.ind_i18.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i18.city is 'Город';
comment on column index2020.ind_i18.region is 'Субъект РФ';
comment on column index2020.ind_i18.city_population_rosstat is 'Население города (по данным Росстата 2020)';
comment on column index2020.ind_i18.near_greenery_population is 'Число жителей, проживающих не далее 800 м. от ближайшего парка';
comment on column index2020.ind_i18.near_greenery_ratio is 'Отношение числа жителей, проживающих не далее 800 м. от ближайшего парка ко всему населению города';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i18;
create table index2020.comp_i18 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.city_population_rosstat, 0) city_population_rosstat_2019,
	coalesce(i1.city_population_rosstat, 0) city_population_rosstat_2020,
	coalesce(i2.near_greenery_population, 0) near_greenery_population_2019,
	coalesce(i1.near_greenery_population, 0) near_greenery_population_2020,
	coalesce(round((i2.near_greenery_ratio / 100)::numeric, 4), 0) near_greenery_ratio_2019,
	coalesce(round((i1.near_greenery_ratio / 100)::numeric, 4), 0) near_greenery_ratio_2020,
	(case 
		when coalesce(round((i1.near_greenery_ratio / 100)::numeric, 4), 0) > coalesce(round((i2.near_greenery_ratio / 100)::numeric, 4), 0)
			then 2020
	 	when coalesce(round((i1.near_greenery_ratio / 100)::numeric, 4), 0) = coalesce(round((i2.near_greenery_ratio / 100)::numeric, 4), 0)
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i18 i1
left join index2019.ind_i18 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i18 is 'Сравнение с 2019 годом. 18-й индикатор. Доступность благоустроенного озеленения.';
comment on column index2020.comp_i18.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i18.city is 'Город';
comment on column index2020.comp_i18.region is 'Субъект РФ';
comment on column index2020.comp_i18.city_population_rosstat_2019 is 'Численность населения города в 2019 г., чел. (по данным Росстата), чел.';
comment on column index2020.comp_i18.city_population_rosstat_2020 is 'Численность населения города в 2020 г., чел. (по данным Росстата), чел.';
comment on column index2020.comp_i18.near_greenery_population_2019 is 'Численность населения проживающего в радиусе 800 м. от парка в 2019 г., чел.';
comment on column index2020.comp_i18.near_greenery_population_2020 is 'Численность населения проживающего в радиусе 800 м. от парка в 2020 г., чел.';
comment on column index2020.comp_i18.near_greenery_ratio_2019 is 'Доступность благоустроенного озеленения - отношение численности населения проживающего в радиусе 800 м. от парка ко всему населению города в 2019 г.';
comment on column index2020.comp_i18.near_greenery_ratio_2020 is 'Доступность благоустроенного озеленения - отношение численности населения проживающего в радиусе 800 м. от парка ко всему населению города в 2020 г.';
comment on column index2020.comp_i18.higher_value is 'В каком году показатель "Доступность благоустроенного озеленения" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",	
	city_population_rosstat_2019 "Числ. насел.(Росстат), чел (2019)",
	city_population_rosstat_2020 "Числ. насел.(Росстат), чел (2020)",
	near_greenery_population_2019 "Числ. насел. в радиусе зел., чел (2019)",
	near_greenery_population_2020 "Числ. насел. в радиусе зел., чел (2020)",
	near_greenery_ratio_2019 "Доступн. благ. озелен. (2019)",
	near_greenery_ratio_2020 "Доступн. благ. озелен. (2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i18;
*/
