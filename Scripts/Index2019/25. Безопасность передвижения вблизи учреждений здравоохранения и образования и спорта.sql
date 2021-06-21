/* 25-й индикатор. Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта */
/* Время расчёта с визуализацией ~ 45 мин. (что странно - должно быть 10 мин...) */
/* Визуализация проверенных переходов */
drop materialized view if exists index2019.viz_i25_crossing cascade;
create materialized view index2019.viz_i25_crossing as
select id, id_gis, geom from index2019.data_crossing where is_valid is true or is_valid is null;
create unique index on index2019.viz_i25_crossing(id);
create index on index2019.viz_i25_crossing(id_gis);
create index on index2019.viz_i25_crossing using gist(geom);
cluster index2019.viz_i25_crossing using viz_i25_crossing_geom_idx;

/* Индексы */
create unique index on index2019.viz_i25_crossing (id_gis);

/* Комментарии */
comment on materialized view index2019.viz_i25_crossing is '25-й индикатор. Визуализация проверенных переходов';
comment on column index2019.viz_i25_crossing.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i25_crossing.geom is 'Центроид пешеходного перехода';


/* Визуализация зоны поиска для 25-го индикатора - 500 м. в радиусе от объектов образования, здравоохранения и спорта */
drop materialized view if exists index2019.viz_i25_poi_buffer cascade;
create materialized view index2019.viz_i25_poi_buffer as
/* Откладываем отдельные буфферы от объектов */
with buffer as (
select
	row_number() over() id,
	id_gis,
	st_buffer(geom::geography, 500)::geometry geom
from index2019.data_poi
where
	category != any('{Медицина и фармацевтика,Наука и образование,Спорт}') 
		and rubrics != any('{Логопеды,Частная школа,Центр повышения квалификации,Спортплощадка,Фотошкола,Яхт-клуб,
						   Обучение мастеров для салонов красоты,Тренажерный зал,Тир,Пейнтбол,Лазертаг,Компьютерные курсы,
						   Судебно-медицинская экспертиза,Стрелковый клуб,Курсы иностранных языков,НИИ,Гольф-клуб,Дайвинг,
						   Массажный салон,Дополнительное образование,Аэроклуб,Курсы и мастер-классы,Коррекция зрения,
						   Клуб охотников и рыболовов,Магазин медицинских товаров,Магазин наглядных учебных пособий,Нетрадиционная медицина,
						   Салон оптики,Товары для инвалидов,Конный клуб,Центр йоги,Аптека,Магазин бильярда}')
--		and id_gis = 778 -- для дебага
)
/* Если сначала сделать объединение буферов, а потом пересечь его с границей, то на больших городах база съедает всю память и вешается!!! */
/* Поэтому, пересекаем по отдельности каждый буфер с границей города а потом объединяем полученный продукт на каждый город */
select		
	bu.id_gis,
	st_multi(st_union(
		case 
			when st_within(bu.geom, bo.geom)
				then bu.geom -- проверка на вложенность для экономии расчётов
			else st_intersection(bu.geom, bo.geom)
		end
		)
	)::geometry(multipolygon, 4326) geom
from buffer bu
join index2019.data_boundary bo using(id_gis)
group by id_gis
order by id_gis;

/* Индексы */
create unique index on index2019.viz_i25_poi_buffer(id_gis);
create index on index2019.viz_i25_poi_buffer using gist(geom);


/* Статистика по результатам фильтрации и проверки пешеходных переходов */
drop materialized view if exists index2019.stat_crossing cascade;
create materialized view index2019.stat_crossing as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(count(c.*), 0) total_crossing,
	coalesce(count(c.*) filter(where c.manually_created is null and c.is_valid is true) + count(c.*) filter(where c.manually_created is not null), 0) total_valid_crossing,
	coalesce(count(c.*) filter(where c.manually_created is null), 0) total_ai_crossing_found,
	coalesce(count(c.*) filter(where c.manually_created is not null), 0) total_manual_crossing,
	coalesce(count(c.*) filter(where c.manually_created is null and c.is_valid is true), 0) total_ai_valid_crossing,
	coalesce(count(c.*) filter(where c.manually_created is null and  c.is_valid is false), 0) total_ai_invalid_crossing,
	coalesce((count(c.*) filter(where c.manually_created is null and c.is_valid is true)) * 100 / nullif((count(c.*) filter(where c.manually_created is null)), 0), 0) total_ai_valid_crossing_percent,
	coalesce(100 - (count(c.*) filter(where c.manually_created is null and c.is_valid is true)) * 100 / nullif((count(c.*) filter(where c.manually_created is null)), 0), 0) total_ai_invalid_crossing_percent
from index2019.data_boundary b
left join index2019.viz_i25_poi_buffer bf using(id_gis)
left join index2019.data_crossing c
	on st_intersects(bf.geom, c.geom)
group by b.id_gis
order by b.id_gis;

/* Индексы */
create unique index on index2019.stat_crossing (id_gis);

/* Комментарии */
comment on materialized view index2019.stat_crossing is 'Статистика по результатам фильтрации и проверки пешеходных переходов';
comment on column index2019.stat_crossing.id_gis is 'Уникальный идентификатор города';
comment on column index2019.stat_crossing.city is 'Город';
comment on column index2019.stat_crossing.region is 'Субъект РФ';
comment on column index2019.stat_crossing.total_crossing is 'Общее число переходов в городе (автоматически найденные и добавленные в ручную)';
comment on column index2019.stat_crossing.total_ai_crossing_found is 'Общее число переходов автоматически найденных в городе';
comment on column index2019.stat_crossing.total_ai_valid_crossing is 'Общее число подтверждённых переходов автоматически найденных в городе';
comment on column index2019.stat_crossing.total_ai_invalid_crossing is 'Общее число забракованных переходов автоматически найденных в городе';
comment on column index2019.stat_crossing.total_manual_crossing is 'Общее число переходов добавленных вручную в городе';
comment on column index2019.stat_crossing.total_ai_valid_crossing_percent is 'Процент подтверждённых переходов от общего числа автоматически найденных в городе';
comment on column index2019.stat_crossing.total_ai_invalid_crossing_percent is 'Процент забракованных переходов от общего числа автоматически найденных в городе';


/* Считаем индикатор */
drop materialized view if exists index2019.ind_i25;
create materialized view index2019.ind_i25 as 
/* Считаем перекрёстки в радиусе 500 м. от объектов */
with crossing_count as (
	select
		c.id_gis,
		count(*) as count
	from index2019.viz_i25_crossing c
	join index2019.viz_i25_poi_buffer b on st_intersects(c.geom, b.geom)
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
		from index2019.data_road r
		join index2019.viz_i25_poi_buffer b using(id_gis)
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
from index2019.data_boundary b
left join crossing_count c using(id_gis)
left join road_length r using(id_gis)
order by b.id_gis;

/* Комментарии */
comment on materialized view index2019.ind_i25 is
'Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта. 25-й индикатор.';
comment on column index2019.ind_i25.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i25.city is 'Город';
comment on column index2019.ind_i25.region is 'Субъект РФ';
comment on column index2019.ind_i25.total_crossing is 'Всего переклёстков в радиусе 500 м. от объектов';
comment on column index2019.ind_i25.sum_road_length_km is 'Суммарная протяжённость дорог в радиусе 500 м. от объектов';
comment on column index2019.ind_i25.crossings_to_km is 'Количество перекрёстков на 1 км.';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i25;
create view index2019.comp_i25 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.crossings_count, 0) total_crossing_2018,
	coalesce(i1.total_crossing, 0) total_crossing_201,
	coalesce(round(i2.filtered_road_length_km::numeric, 2), 0) sum_road_length_km_2018,
	coalesce(i1.sum_road_length_km, 0) sum_road_length_km_2019,
	coalesce(round((i2.crossings_to_km2_filtered)::numeric, 4), 0) crossings_to_km_2018,
	coalesce(i1.crossings_to_km, 0) crossings_to_km_2019,
	(case 
		when coalesce(i1.crossings_to_km, 0) > coalesce(round((i2.crossings_to_km2_filtered)::numeric, 4), 0)
			then 2019
	 	when coalesce(i1.crossings_to_km, 0) = coalesce(round((i2.crossings_to_km2_filtered)::numeric, 4), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i25 i1
left join index2018.i25_road_safety i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i25 is 'Сравнение с 2018 годом. 25-й индикатор. Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта.';
comment on column index2019.comp_i25.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i25.city is 'Город';
comment on column index2019.comp_i25.region is 'Субъект РФ';
comment on column index2019.comp_i25.total_crossing_2018 is 'Общее количество размеченных пешеходных переходов вблизи социальных и спортивных объектов в 2018 г., ед.';
comment on column index2019.comp_i25.total_crossing_2019 is 'Общее количество размеченных пешеходных переходов вблизи социальных и спортивных объектов в 2019 г., ед.';
comment on column index2019.comp_i25.sum_road_length_km_2018 is 'Общая протяжённость улично-дорожной сети вблизи социальных и спортивных объектов в 2018 г., км.';
comment on column index2019.comp_i25.sum_road_length_km_2019 is 'Общая протяжённость улично-дорожной сети вблизи социальных и спортивных объектов в 2019 г., км.';
comment on column index2019.comp_i25.crossings_to_km_2018 is 'Отношение количества размеченных пешеходных переходов к общей протяжённости улично-дорожной сети вблизи социальных и спортивных объектов в 2018 г. ед/км.';
comment on column index2019.comp_i25.crossings_to_km_2019 is 'Отношение количества размеченных пешеходных переходов к общей протяжённости улично-дорожной сети вблизи социальных и спортивных объектов в 2018 г. ед/км.';
comment on column index2019.comp_i25.higher_value is 'В каком году показатель "Безопасность передвижения вблизи учреждений здравоохранения и образования и спорта" выше';