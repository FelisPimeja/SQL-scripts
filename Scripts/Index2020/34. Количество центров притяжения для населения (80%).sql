/* 34-й индикатор. Количество центров притяжения для населения */
/* Время расчёта ~ 5 ч. */
/* 34-й индикатор. Визуализация фото vk */
drop table if exists index2020.viz_i34_vk;
create table index2020.viz_i34_vk as 
select
	v.id,
	v.url,
	v.id_gis,
	s.id_street,
	s.name street_name,
	s.dist_m,
	v.geom
from index2020.data_vk v
join lateral (
	select
		s.id_street,
		s.name,
		st_distance(v.geom::geography, s.geom::geography, true) dist_m
	from index2020.data_street s
	where s.id_gis = v.id_gis
		and st_dwithin(v.geom::geography, s.geom::geography, 100)
	order by v.geom::geography <-> s.geom::geography
	limit 1
) s on true
--where v.id_gis <= 10 -- для дебага
order by id_gis;


/* Индексы */
alter table index2020.viz_i34_vk add primary key(id);
create index on index2020.viz_i34_vk (id_gis);
create index on index2020.viz_i34_vk (id_street);
create index on index2020.viz_i34_vk (street_name);
create index on index2020.viz_i34_vk (dist_m);
create index on index2020.viz_i34_vk using gist(geom);

/* Комментарии */
comment on table index2020.viz_i34_vk is '34-й индикатор. Количество центров притяжения для населения. Визуализация фото vk.';
comment on column index2020.viz_i34_vk.id is 'Уникальный идентификатор фото';
comment on column index2020.viz_i34_vk.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i34_vk.id_street is 'Уникальный идентификатор улицы';
comment on column index2020.viz_i34_vk.street_name is 'Название улицы';
comment on column index2020.viz_i34_vk.dist_m is 'Расстояние от точки до ближайшей улицы';
comment on column index2020.viz_i34_vk.geom is 'Точка фото vk';
	
	
/* Статистика по количесво фото vk сделанных на каждой именованной улице */
drop table if exists street_stat;
create temp table street_stat as
	select
		v.id_gis,
		v.id_street,
		count(v.id) street_photos,
		sum(count(v.id)) over (partition by id_gis order by count(v.id) desc, id_street) cumulative_sum_photos,
		sum(count(v.id)) over (partition by id_gis) as total_photos
	from index2020.viz_i34_vk v
--	where v.dist_m <= 100
	group by v.id_gis, v.id_street
;
create index on street_stat(id_gis);
create index on street_stat(id_street);
create index on street_stat(cumulative_sum_photos);
create index on street_stat(total_photos);


/* Визуализация статистики по количесво фото vk сделанных на каждой именованной улице */
drop table if exists index2020.stat_vk_street_60;
create table index2020.stat_vk_street_60 as
	select st.*, s.street_photos
	from index2020.data_street st
	join street_stat s 
		on s.id_street = st.id_street 
			and s.cumulative_sum_photos <= s.total_photos * 0.6
;

/* Индексы */
alter table index2020.stat_vk_street_60 add primary key(id_street);
create index on index2020.stat_vk_street_60(id_gis);
create index on index2020.stat_vk_street_60(id_street);
create index on index2020.stat_vk_street_60(name);
create index on index2020.stat_vk_street_60(street_photos);
create index on index2020.stat_vk_street_60 using gist(geom);

/* Комментарии */
comment on table index2020.stat_vk_street_60 is 'Статистика по количесво фото vk сделанных на каждой именованной улице';
comment on column index2020.stat_vk_street_60.id_gis is 'id_gis города';
comment on column index2020.stat_vk_street_60.id_street is 'Уникальный идентификатор улицы';
comment on column index2020.stat_vk_street_60.name is 'Название улицы';
comment on column index2020.stat_vk_street_60.street_photos is 'Всего фото сделано на этой улице (фото находящиеся в радиусе 100 м. от оси улицы, для которых эта ось ближайшая)';


/* 34-й индикатор. Расчёт самого индикатора */
drop table  if exists index2020.ind_i34_60;
create table index2020.ind_i34_60 as
	select
		b.id_gis::smallint,
		b.city,
		b.region,
		coalesce(ss.total_photos, 0)::int total_photos,
		coalesce(st.total_streets, 0)::smallint total_streets,
		coalesce(count(ss.id_street), 0)::smallint total_popular_streets,
		coalesce(round((count(ss.id_street) / nullif(st.total_streets, 0)::numeric), 4), 0) popular_streets_ratio
	from index2020.data_boundary b 
	left join index2020.stat_street st using(id_gis)
	left join street_stat ss
	on ss.id_gis = b.id_gis
		and (ss.cumulative_sum_photos <= ss.total_photos * 0.6
			or (ss.cumulative_sum_photos > ss.total_photos * 0.6
				and ss.cumulative_sum_photos - ss.street_photos < ss.total_photos * 0.6
			)
		)
	group by b.id_gis, b.city, b.region, st.total_streets, ss.total_photos
	order by b.id_gis
;

/* Индексы */
alter table index2020.ind_i34_60 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i34_60 is '34-й индикатор. Количество центров притяжения для населения.';
comment on column index2020.ind_i34_60.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i34_60.city is 'Город';
comment on column index2020.ind_i34_60.region is 'Субъект РФ';
comment on column index2020.ind_i34_60.total_photos is 'Всего фото в городе (вне помещения на расстоянии не далее 100 м. от ближайшей улицы)';
comment on column index2020.ind_i34_60.total_streets is 'Всего улиц в городе (именованных по OpenStreetMap)';
comment on column index2020.ind_i34_60.total_popular_streets is 'Всего популярных улиц (на которых суммарно сделано ~ 60% фото от общего числа)';
comment on column index2020.ind_i34_60.popular_streets_ratio is 'Отношение числа популярных улиц к общему числу улиц в городе (именованных по OpenStreetMap)';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i34_60;
create table index2020.comp_i34_60 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.total_photos, 0) total_photos_2019,
	coalesce(i1.total_photos, 0) total_photos_2020,
	coalesce(i2.total_streets, 0) total_streets_2019,
	coalesce(i1.total_streets, 0) total_streets_2020,
	coalesce(i2.total_popular_streets, 0) total_popular_streets_2019,
	coalesce(i1.total_popular_streets, 0) total_popular_streets_2020,
	coalesce(i2.popular_streets_ratio, 0) popular_streets_ratio_2019,
	coalesce(i1.popular_streets_ratio, 0) popular_streets_ratio_2020,
	(case 
		when coalesce(i1.popular_streets_ratio, 0) > coalesce(i2.popular_streets_ratio, 0)
			then 2020
	 	when coalesce(i1.popular_streets_ratio, 0) = coalesce(i2.popular_streets_ratio, 0)
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i34_60 i1
left join index2019.ind_i34 i2 using(id_gis)
order by id_gis;
--alter table index2019.ind_i34 rename column streets_sum_60_perc_photos to total_popular_streets;
/* Комментарии */
comment on table index2020.comp_i34_60 is 'Сравнение с 2019 годом. 34-й индикатор. Количество центров притяжения для населения.';
comment on column index2020.comp_i34_60.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i34_60.city is 'Город';
comment on column index2020.comp_i34_60.region is 'Субъект РФ';
comment on column index2020.comp_i34_60.total_photos_2019 is 'Общее количество фото, сделанных снаружи не далее 100 м от оси улицы в 2019 г., ед.';
comment on column index2020.comp_i34_60.total_photos_2020 is 'Общее количество фото, сделанных снаружи не далее 100 м от оси улицы в 2020 г., ед.';
comment on column index2020.comp_i34_60.total_streets_2019 is 'Число улиц в городе на 2019 г., ед.';
comment on column index2020.comp_i34_60.total_streets_2020 is 'Число улиц в городе на 2019 г., ед.';
comment on column index2020.comp_i34_60.total_popular_streets_2019 is 'Число улиц на которых сделано ~ 60% всех фото в городе на 2019 г., ед.';
comment on column index2020.comp_i34_60.total_popular_streets_2020 is 'Число улиц на которых сделано ~ 60% всех фото в городе на 2020 г., ед.';
comment on column index2020.comp_i34_60.popular_streets_ratio_2019 is 'Количество центров притяжения для населения - отношение улиц на которых сделано ~ 60% всех фото к общему числу фото, сделанных в городе в 2019 г.';
comment on column index2020.comp_i34_60.popular_streets_ratio_2020 is 'Количество центров притяжения для населения - отношение улиц на которых сделано ~ 60% всех фото к общему числу фото, сделанных в городе в 2020 г.';
comment on column index2020.comp_i34_60.higher_value is 'В каком году показатель "Количество центров притяжения для населения" выше';



/* Вывод сравнительной таблицы в Excel */
/*
select 
	i.id_gis "id_gis города",
	i.city "Город",
	i.region "Субъект РФ",
	i.total_photos_2019 "Всего фото на улице(2019)",
	i.total_photos_2020 "Всего фото на улице(2020)",
	i.total_streets_2019 "Всего улиц в городе(2019)",
	i.total_streets_2020  "Всего улиц в городе(2020)",
	i.total_popular_streets_2019 "Всего центров притяж.(2019)",
	i.total_popular_streets_2020 "Всего центров притяж.(2020)",
	i.popular_streets_ratio_2019 "Доля центров притяж.(2019)",
	i.popular_streets_ratio_2020 "Доля центров притяж.(2020)",
	case when i.higher_value is null then 'поровну' else i.higher_value::text end "В каком году показатель выше",
	s.area_dif_perc "% разницы в площад гор 2019-2020гг"
from index2020.comp_i34_60 i
left join index2020.stat_boundary s using(id_gis)
;
*/


