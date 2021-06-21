/* 25-й индикатор. Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта */
/* Время расчёта с визуализацией ~ 30 мин. (а если считать правильно, то 10 мин...) */
/* Визуализация проверенных переходов */
drop table if exists index2020.viz_i25_crossing;
create table index2020.viz_i25_crossing as
	select (row_number() over())::int id, id_gis, geom
	from index2020.data_crossing
	where is_valid is true
--		and id_gis = 1122
;

/* Индексы */
alter table index2020.viz_i25_crossing add primary key(id);
create index on index2020.viz_i25_crossing(id_gis);
create index on index2020.viz_i25_crossing using gist(geom);
create index on index2020.viz_i25_crossing using gist((geom::geography));
--cluster index2020.viz_i25_crossing using viz_i25_crossing_geom_idx;

/* Комментарии */
comment on table index2020.viz_i25_crossing is '25-й индикатор. Визуализация проверенных переходов';
comment on column index2020.viz_i25_crossing.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i25_crossing.geom is 'Центроид пешеходного перехода';


/* Откладываем отдельные буфферы от объектов */
drop table if exists buffer;
create temp table buffer as
	select distinct on(geom)
		row_number() over() id,
		id_gis,
		st_buffer(geom::geography, 500)::geometry geom
	from index2020.data_poi
	where
		category = any('{Медицина и фармацевтика,Наука и образование,Спорт}') -- восклицательный знак тут лишний, но оставлен для сохранения преемственности...
			and rubrics != any('{Логопеды,Частная школа,Центр повышения квалификации,Спортплощадка,Фотошкола,Яхт-клуб,
							   Обучение мастеров для салонов красоты,Тренажерный зал,Тир,Пейнтбол,Лазертаг,Компьютерные курсы,
							   Судебно-медицинская экспертиза,Стрелковый клуб,Курсы иностранных языков,НИИ,Гольф-клуб,Дайвинг,
							   Массажный салон,Дополнительное образование,Аэроклуб,Курсы и мастер-классы,Коррекция зрения,
							   Клуб охотников и рыболовов,Магазин медицинских товаров,Магазин наглядных учебных пособий,Нетрадиционная медицина,
							   Салон оптики,Товары для инвалидов,Конный клуб,Центр йоги,Аптека,Магазин бильярда}')
--			and id_gis = 1122 -- для дебага
;

create index on buffer(id_gis);
create index on buffer using gist(geom);

/* Визуализация зоны поиска для 25-го индикатора - 500 м. в радиусе от объектов образования, здравоохранения и спорта */
drop table if exists index2020.viz_i25_poi_buffer;
create table index2020.viz_i25_poi_buffer as
/* Если сначала сделать объединение буферов, а потом пересечь его с границей, то на больших городах база съедает всю память и вешается!!! */
/* Поэтому, пересекаем по отдельности каждый буфер с границей города а потом объединяем полученный продукт на каждый город */
select		
	bo.id_gis,
	st_multi(st_union(
		case 
			when st_within(bu.geom, bo.geom)
				then bu.geom -- проверка на вложенность для экономии расчётов
			else st_intersection(bu.geom, bo.geom)
		end
		)
	)::geometry(multipolygon, 4326) geom
from buffer bu
join index2020.data_boundary bo using(id_gis)
group by bo.id_gis
order by bo.id_gis;

/* Индексы */
alter table index2020.viz_i25_poi_buffer add primary key (id_gis);
create index on index2020.viz_i25_poi_buffer using gist(geom);


/* Статистика по результатам фильтрации и проверки пешеходных переходов */
drop table if exists index2020.stat_crossing;
create table index2020.stat_crossing as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(count(c.*), 0) total_crossing,
	coalesce(count(c.*) filter(where c.is_valid is true), 0) total_valid_crossing
--	coalesce(count(c.*) filter(where c.manually_created is null), 0) total_ai_crossing_found,
--	coalesce(count(c.*) filter(where c.manually_created is not null), 0) total_manual_crossing,
--	coalesce(count(c.*) filter(where c.manually_created is null and c.is_valid is true), 0) total_ai_valid_crossing,
--	coalesce(count(c.*) filter(where c.manually_created is null and  c.is_valid is false), 0) total_ai_invalid_crossing,
--	coalesce((count(c.*) filter(where c.manually_created is null and c.is_valid is true)) * 100 / nullif((count(c.*) filter(where c.manually_created is null)), 0), 0) total_ai_valid_crossing_percent,
--	coalesce(100 - (count(c.*) filter(where c.manually_created is null and c.is_valid is true)) * 100 / nullif((count(c.*) filter(where c.manually_created is null)), 0), 0) total_ai_invalid_crossing_percent
from index2020.data_boundary b
left join index2020.viz_i25_poi_buffer bf using(id_gis)
left join index2020.data_crossing c using(id_gis)
group by b.id_gis, b.city, b.region
order by b.id_gis;

/* Индексы */
alter table index2020.stat_crossing add primary key(id_gis);

/* Комментарии */
comment on table index2020.stat_crossing is 'Статистика по результатам фильтрации и проверки пешеходных переходов';
comment on column index2020.stat_crossing.id_gis is 'Уникальный идентификатор города';
comment on column index2020.stat_crossing.city is 'Город';
comment on column index2020.stat_crossing.region is 'Субъект РФ';
comment on column index2020.stat_crossing.total_crossing is 'Общее число переходов в городе';
comment on column index2020.stat_crossing.total_valid_crossing is 'Общее число подтверждённых переходов';


/* Статистика по результатам фильтрации и проверки пешеходных переходов */
drop table if exists index2020.comp_stat_crossing;
create table index2020.comp_stat_crossing as 
select
	s1.id_gis,
	s1.city,
	s1.region,
	s2.total_crossing total_crossing_2019,
	s1.total_crossing total_crossing_2020,
	s2.total_valid_crossing total_valid_crossing_2019,
	s1.total_valid_crossing total_valid_crossing_2020
from index2020.stat_crossing s1
left join index2019.stat_crossing s2 using(id_gis);


/* Считаем индикатор */
drop table if exists index2020.ind_i25;
create table index2020.ind_i25 as 
/* Считаем перекрёстки в радиусе 500 м. от объектов */
with crossing_count as (
	select
		c.id_gis,
		count(*) as count
	from index2020.viz_i25_poi_buffer b
	join index2020.viz_i25_crossing c
		on st_intersects(c.geom, b.geom)
			and b.id_gis = c.id_gis
	group by c.id_gis
),
/* Считаем протяжённость улично-дорожной сети в радиусе 500 м. от объектов */
road_length as (
	select
		id_gis,
		sum(st_length((geom)::geography, true)) / 1000 as sum_road_length_km
	from (
		select
			id_gis,
			st_multi(case 
				when st_within(r.geom, b.geom)
					then r.geom -- проверка на вложенность для экономии расчётов
				else st_collectionextract(st_intersection(r.geom, b.geom), 2)
			end)::geometry(multilinestring, 4326) geom
		from index2020.data_road r
		join index2020.viz_i25_poi_buffer b using(id_gis)
		/* отфильтровываем дороги которые не должны попасть в подсчёт суммарной протяжённости */
		where r.type != any ('{steps,groyne,cycleway,pedestrian,track,motorway_link,preserved,motorway,service,path}')
--			and b.id_gis < 100 -- для дебага
	) r
	group by id_gis
)
/* Сводим статистику */
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(c.count, 0) as total_crossing,
	round(r.sum_road_length_km::numeric, 2) sum_road_length_km,
	coalesce(round((c.count / r.sum_road_length_km)::numeric, 4), 0) as crossings_to_km
from index2020.data_boundary b
left join crossing_count c using(id_gis)
left join road_length r using(id_gis)
order by b.id_gis;

/* Комментарии */
comment on table index2020.ind_i25 is
'Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта. 25-й индикатор.';
comment on column index2020.ind_i25.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i25.city is 'Город';
comment on column index2020.ind_i25.region is 'Субъект РФ';
comment on column index2020.ind_i25.total_crossing is 'Всего переклёстков в радиусе 500 м. от объектов';
comment on column index2020.ind_i25.sum_road_length_km is 'Суммарная протяжённость дорог в радиусе 500 м. от объектов';
comment on column index2020.ind_i25.crossings_to_km is 'Количество перекрёстков на 1 км.';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i25;
create table index2020.comp_i25 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.total_crossing, 0) total_crossing_2019,
	coalesce(i1.total_crossing, 0) total_crossing_2020,
	coalesce(i2.sum_road_length_km, 0) sum_road_length_km_2019,
	coalesce(i1.sum_road_length_km, 0) sum_road_length_km_2020,
	coalesce(i2.crossings_to_km, 0) crossings_to_km_2019,
	coalesce(i1.crossings_to_km, 0) crossings_to_km_2020,
	(case 
		when coalesce(i1.crossings_to_km, 0) > coalesce(i2.crossings_to_km, 0)
			then 2020
	 	when coalesce(i1.crossings_to_km, 0) = coalesce(i2.crossings_to_km, 0)
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i25 i1
left join index2019.ind_i25 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i25 is 'Сравнение с 2019 годом. 25-й индикатор. Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта.';
comment on column index2020.comp_i25.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i25.city is 'Город';
comment on column index2020.comp_i25.region is 'Субъект РФ';
comment on column index2020.comp_i25.total_crossing_2019 is 'Общее количество размеченных пешеходных переходов вблизи социальных и спортивных объектов в 2019 г., ед.';
comment on column index2020.comp_i25.total_crossing_2020 is 'Общее количество размеченных пешеходных переходов вблизи социальных и спортивных объектов в 2020 г., ед.';
comment on column index2020.comp_i25.sum_road_length_km_2019 is 'Общая протяжённость улично-дорожной сети вблизи социальных и спортивных объектов в 2019 г., км.';
comment on column index2020.comp_i25.sum_road_length_km_2020 is 'Общая протяжённость улично-дорожной сети вблизи социальных и спортивных объектов в 2020 г., км.';
comment on column index2020.comp_i25.crossings_to_km_2019 is 'Отношение количества размеченных пешеходных переходов к общей протяжённости улично-дорожной сети вблизи социальных и спортивных объектов в 2019 г. ед/км.';
comment on column index2020.comp_i25.crossings_to_km_2020 is 'Отношение количества размеченных пешеходных переходов к общей протяжённости улично-дорожной сети вблизи социальных и спортивных объектов в 2019 г. ед/км.';
comment on column index2020.comp_i25.higher_value is 'В каком году показатель "Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	total_crossing_2019 "Всего перех вблизи соц, шт(2019)",
	total_crossing_2020 "Всего перех вблизи соц, шт(2020)",
	sum_road_length_km_2019 "Протяж улиц вблизи соц, км(2019)",
	sum_road_length_km_2020 "Протяж улиц вблизи соц, км(2020)",
	crossings_to_km_2019 "Пеш пер на 1км улиц(2019)",
	crossings_to_km_2020 "Пеш пер на 1км улиц(2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i25;
*/
