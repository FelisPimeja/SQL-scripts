/* 34-й индикатор. Количество центров притяжения для населения */
/* Время расчёта ~ 24 часа!!! */
/* 34-й индикатор. Визуализация фото vk */
drop materialized view if exists index2019.viz_i34_vk cascade;
create materialized view index2019.viz_i34_vk as 
select
	v.id,
	v.url,
	v.id_gis,
	s.id_street,
	s.name street_name,
	s.dist_m,
	v.geom
from index2019.data_vk v
join lateral (
	select s.id_street, s.name, st_distance(v.geom::geography, s.geom::geography, true) dist_m
	from index2019.data_street s
	where s.id_gis = v.id_gis
	order by v.geom::geography <-> s.geom::geography
	limit 1
) s on true
where v.in_out = 'out'
--	and v.id_gis < 10 -- для дебага
order by id_gis;

/* Индексы */
create unique index on index2019.viz_i34_vk (id);
create index on index2019.viz_i34_vk (id_gis);
create index on index2019.viz_i34_vk (id_street);
create index on index2019.viz_i34_vk (street_name);
create index on index2019.viz_i34_vk (dist_m);
create index on index2019.viz_i34_vk using gist(geom);

/* Комментарии */
comment on materialized view index2019.viz_i34_vk is '34-й индикатор. Количество центров притяжения для населения. Визуализация фото vk.';
comment on column index2019.viz_i34_vk.id is 'Уникальный идентификатор фото';
comment on column index2019.viz_i34_vk.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i34_vk.id_street is 'Уникальный идентификатор улицы';
comment on column index2019.viz_i34_vk.street_name is 'Название улицы';
comment on column index2019.viz_i34_vk.dist_m is 'Расстояние от точки до ближайшей улицы';
comment on column index2019.viz_i34_vk.geom is 'Точка фото vk';



/* 34-й индикатор. Расчёт самого индикатора */
drop materialized view  if exists index2019.ind_i34;
create materialized view index2019.ind_i34 as
with street_stat as (
	select
		v.id_gis,
		v.id_street,
		count(v.id) street_photos,
		sum(count(v.id)) over (partition by id_gis order by count(v.id) desc, id_street) cumulative_sum_photos,
		sum(count(v.id)) over (partition by id_gis) as total_photos
	from index2019.viz_i34_vk v
	where v.dist_m <= 100
	group by v.id_gis, v.id_street
)

select
	b.id_gis::smallint,
	b.city,
	b.region,
	coalesce(ss.total_photos, 0)::int total_photos,
	coalesce(st.total_streets, 0)::smallint total_streets,
	coalesce(count(ss.id_street), 0)::smallint total_popular_streets,
	coalesce(round((count(ss.id_street) / nullif(st.total_streets, 0)::numeric), 4), 0) popular_streets_ratio
from index2019.data_boundary b 
left join index2019.stat_street st using(id_gis)
left join street_stat ss
on ss.id_gis = b.id_gis
	and (ss.cumulative_sum_photos <= ss.total_photos * 0.75
		or (ss.cumulative_sum_photos > ss.total_photos * 0.75
			and ss.cumulative_sum_photos - ss.street_photos < ss.total_photos * 0.75
		)
	)
group by b.id_gis, b.city, b.region, st.total_streets, ss.total_photos
order by b.id_gis;

/* Индексы */
create unique index on index2019.ind_i34 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i34 is '34-й индикатор. Количество центров притяжения для населения.';
comment on column index2019.ind_i34.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i34.city is 'Город';
comment on column index2019.ind_i34.region is 'Субъект РФ';
comment on column index2019.ind_i34.total_photos is 'Всего фото в городе (вне помещения на расстоянии не далее 100 м. от ближайшей улицы)';
comment on column index2019.ind_i34.total_streets is 'Всего улиц в городе (именованных по OpenStreetMap)';
comment on column index2019.ind_i34.total_popular_streets is 'Всего популярных улиц (на которых суммарно сделано ~ 75% фото от общего числа)';
comment on column index2019.ind_i34.popular_streets_ratio is 'Отношение числа популярных улиц к общему числу улиц в городе (именованных по OpenStreetMap)';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i34;
create view index2019.comp_i34 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.photos_all, 0) total_photos_2018,
	coalesce(i1.total_photos, 0) total_photos_2019,
	coalesce(i2.streets_all, 0) total_streets_2018,
	coalesce(i1.total_streets, 0) total_streets_2019,
	coalesce(i2.streets_sum_75_perc_photos, 0) streets_sum_75_perc_photos_2018,
	coalesce(i1.total_popular_streets, 0) streets_sum_75_perc_photos_2019,
	coalesce(round((i2.place_ratio)::numeric, 2), 0) popular_streets_ratio_2018,
	coalesce(i1.popular_streets_ratio, 0) popular_streets_ratio_2019,
	(case 
		when coalesce(i1.popular_streets_ratio, 0) > coalesce(round((i2.place_ratio)::numeric, 2), 0)
			then 2019
	 	when coalesce(i1.popular_streets_ratio, 0) = coalesce(round((i2.place_ratio)::numeric, 2), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i34 i1
left join index2018.i34_streets_by_photo i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i34 is 'Сравнение с 2018 годом. 34-й индикатор. Количество центров притяжения для населения.';
comment on column index2019.comp_i34.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i34.city is 'Город';
comment on column index2019.comp_i34.region is 'Субъект РФ';
comment on column index2019.comp_i34.total_photos_2018 is 'Общее количество фото, сделанных снаружи не далее 100 м от оси улицы в 2018 г., ед.';
comment on column index2019.comp_i34.total_photos_2019 is 'Общее количество фото, сделанных снаружи не далее 100 м от оси улицы в 2019 г., ед.';
comment on column index2019.comp_i34.total_streets_2018 is 'Число улиц в городе на 2018 г., ед.';
comment on column index2019.comp_i34.total_streets_2019 is 'Число улиц в городе на 2018 г., ед.';
comment on column index2019.comp_i34.streets_sum_75_perc_photos_2018 is 'Число улиц на которых сделано ~ 75% всех фото в городе на 2018 г., ед.';
comment on column index2019.comp_i34.streets_sum_75_perc_photos_2019 is 'Число улиц на которых сделано ~ 75% всех фото в городе на 2019 г., ед.';
comment on column index2019.comp_i34.popular_streets_ratio_2018 is 'Количество центров притяжения для населения - отношение улиц на которых сделано ~ 75% всех фото к общему числу фото, сделанных в городе в 2018 г.';
comment on column index2019.comp_i34.popular_streets_ratio_2019 is 'Количество центров притяжения для населения - отношение улиц на которых сделано ~ 75% всех фото к общему числу фото, сделанных в городе в 2019 г.';
comment on column index2019.comp_i34.higher_value is 'В каком году показатель "Количество центров притяжения для населения" выше';





/* Визуалка - наиболее популярные улицы */   -- Вкорячить потом нормально!!!
/*create table tmp.tmp_viz_i34_st as 
with stat as (
	select
		v.id_gis,
		v.id_street,
		count(v.id) street_photos,
		sum(count(v.id)) over (partition by id_gis order by count(v.id) desc, id_street) cumulative_sum_photos,
		sum(count(v.id)) over (partition by id_gis) as total_photos
	from tmp.tmp_viz_i34_vk v
	--where v.dist_m <= 100
	group by v.id_gis, v.id_street
)
select st.*, s.street_photos
from index2019.data_street st
join stat s 
	on s.id_street = st.id_street 
		and s.cumulative_sum_photos <= s.total_photos * 0.75;

create index on tmp.tmp_viz_i34_st using gist(geom);*/