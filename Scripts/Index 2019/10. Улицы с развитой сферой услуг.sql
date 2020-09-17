-- Первый вариант (логика расчёта отличается от финальной). НЕ ИСПОЛЬЗОВАТЬ!!!
-- Время расчёта ~ 6 часов 
drop materialized view if exists index2019.viz_i10;
create materialized view index2019.viz_i10 as
with
-- Проекция точек на линии улиц (с построением соединяющей линии, чтобы проще дебажить)
proj_points as (
	 select
		p.id poi_id,
		p.id_gis,
		s.id_street,
		st_transform(st_closestpoint(st_transform(s.geom, 3857),  st_transform(p.geom, 3857)), 4326) pnt_geom, -- отдельная колонка с спроецированными точками
		st_makeline(st_transform(st_closestpoint(st_transform(s.geom, 3857),  st_transform(p.geom, 3857)), 4326), p.geom) line_geom -- отдельная колонка с кратчайшей линией
	 from index2019.data_poi p
	 join index2019.data_street s
		on st_dwithin(s.geom::geography, p.geom::geography, 50, true) -- берём точки на расстоянии не более 50 м. от улицы
			and p.stretail is true
			and mall is false -- отбрасываем ритейл в торговых центрах
			and s.id_gis = p.id_gis
--			and p.id_gis =1062 -- только для дебага
),

-- Отсечение буфером участков с развитым стритритейлом р для каждой улицы
street_parts as (
	select 
		p.id_street,
		p.id_gis,
		st_collectionextract(st_intersection(st_buffer(st_collect(p.pnt_geom)::geography, 50)::geometry, s.geom), 2) stretail_geom,
		st_collect(p.line_geom) poi_lines_geom
	from proj_points p
	join index2019.data_street s using(id_street)
	group by p.id_street, p.id_gis, s.geom
),

-- Поиск самого протяжённого участка стритритейла для каждой улицы
street_parts_expl as (
	select
		id_street,
		max(len_m) max_len_m,
		max(geom) geom
	from (select id_street, st_length((st_dump(stretail_geom)).geom::geography, true) len_m, (st_dump(stretail_geom)).geom geom from street_parts) max
	group by id_street
)

-- Поиск улиц с развитым стритритейлом
select 
	s.id_street,
	s.id_gis,
	s.name,
	st_length(s.geom::geography, true) street_len_m,
	st_length(p.stretail_geom::geography, true) retail_len_m,
	max_p.max_len_m max_part_len_m,
	st_multi(p.stretail_geom)::geometry(multilinestring, 4326) retail_geom,
	st_multi(p.poi_lines_geom)::geometry(multilinestring, 4326) poi_lines_geom,
	max_p.geom::geometry(linestring, 4326) max_part_geom,
	case when st_length(p.stretail_geom::geography, true) >= st_length(s.geom::geography, true) * 0.75 then 1 end st_retail_075,
	case when max_p.max_len_m >= st_length(s.geom::geography, true) * 0.3 then 1 end max_part_03,
	case when (st_length(p.stretail_geom::geography, true) >= st_length(s.geom::geography, true) * 0.75 or max_p.max_len_m >= st_length(s.geom::geography, true) * 0.3) then 1 end st_retail_street
from index2019.data_street s
left join street_parts p using(id_street)
left join street_parts_expl max_p using(id_street)
where max_p.max_len_m is not null
	and  st_length(s.geom::geography, true) > 300; -- Условие на минимальную протяжённость улицы

	
-- Индексы
create unique index on index2019.viz_i10 (id_street); -- Первичный ключ
create index on index2019.viz_i10 (id_gis);
create index on index2019.viz_i10 (st_retail_075);
create index on index2019.viz_i10 (max_part_03);
create index on index2019.viz_i10 (st_retail_street);
create index on index2019.viz_i10 using gist(retail_geom);
create index on index2019.viz_i10 using gist(poi_lines_geom);
create index on index2019.viz_i10 using gist(max_part_geom);

-- Комментарии
comment on materialized view index2019.viz_i10 is 
'Улицы с развитым стритритейлом.
Визуализация 10-го индикатора.';
comment on column index2019.viz_i10.st_retail_075 is 'Да, если развитый ритейл на более 0.75 протяжённости улицы';
comment on column index2019.viz_i10.max_part_03 is 'Да, если развитый ритейл непрерывно на более 0.3 протяжённости улицы';
comment on column index2019.viz_i10.st_retail_street is 'Да, если улица попадает в категорию "с развитым ритейлом"';
comment on column index2019.viz_i10.retail_geom is 'Участки улиц с развитым ритейлом';
comment on column index2019.viz_i10.poi_lines_geom is 'Проекция точек POI на улицы';
comment on column index2019.viz_i10.id_street is 'Уникальный идентификатор улицы';
comment on column index2019.viz_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i10.name is 'Название улицы';
comment on column index2019.viz_i10.street_len_m is 'Протяжённость улицы в метрах';
comment on column index2019.viz_i10.retail_len_m is 'Суммарная протяжённость участков с ритейлом в метрах';
comment on column index2019.viz_i10.max_part_len_m is 'Протяжённость самого длинного участка с ритейлом в метрах';


/* 10-й индикатор. Количество улиц с развитой сферой услуг ~ 1 сек. */
drop materialized view if exists index2019.ind_i10;
create materialized view index2019.ind_i10 as
with
	street_total as (select id_gis, count(*) street_total from index2019.data_street group by id_gis), -- общее число улиц в каждом городе
	street_stat as (
		select
			id_gis,
			count(*) filter(where max_part_03 = 1) max_part_03_total,
			count(*) filter(where st_retail_075 = 1) retail_075_total,
			count(*) filter(where st_retail_street = 1) retail_street_total
		from index2019.viz_i10
		group by id_gis
	) -- статистика по улицам с ритейлом в каждом городе

select
	b.id_gis,
	b.city,
	b.region,
	coalesce(r.max_part_03_total, 0) max_part_03_total,
	coalesce(r.retail_075_total, 0) retail_075_total,
	coalesce(r.retail_street_total, 0) retail_street_total,
	coalesce(s.street_total, 0) street_total,
	coalesce(round(r.retail_street_total / nullif(s.street_total, 0)::numeric, 4), 0) i10 -- с проверкой деления на 0
from index2019.data_boundary b
left join street_stat r using(id_gis)
left join street_total s using(id_gis)
order by b.id_gis;

/* Комментарии */
comment on materialized view index2019.ind_i10 is 
'Улицы с развитым стритритейлом. 10-й индикатор.';
comment on column index2019.ind_i10.city is 'Город';
comment on column index2019.ind_i10.region is 'Субъект РФ';
comment on column index2019.ind_i10.max_part_03_total is 'Количество улиц у которых самый длинный непрерывный участок ритейла от 0.3 протяжённости улицы';
comment on column index2019.ind_i10.retail_075_total is 'Количество улиц у которых суммарная протяжённость участков ритейла от 0.75 протяжённости улицы';
comment on column index2019.ind_i10.retail_street_total is 'Количество улиц развитым ритейлом';
comment on column index2019.ind_i10.street_total is 'Общее количество улиц в городе';
comment on column index2019.ind_i10.i10 is '10-й индикатор';

-- Текущий вариант расчёта
/* 10-й индикатор. Улицы с развитой сферой услуг */
/* Время расчёта ~ 2.5 часов */

drop materialized view if exists index2019.viz_i10 cascade;
create materialized view index2019.viz_i10 as
with
/* разбираем улицы на singleparts для st_linelocatepoint и st_linelocatepoint */
streets_exploded as (
	select
		id_street,
		id_gis,
		name,
		st_length(geom::geography) str_len_m, -- длина всей улицы
		st_length((st_dump(geom)).geom::geography) str_part_len_m, -- протяжённость конкретного участка улицы
		(st_dump(geom)).geom geom
	from index2019.data_street
	where st_length(geom::geography) >= 300
	--	and id_gis < 700 -- дебаг
),

streets as (select row_number() over() id_str_part, * from streets_exploded), -- новая номерация улиц

/* подчищаем пачки POI в одних координатах */
poi as (
	select distinct on (st_x(geom), st_y(geom)) id, id_gis, geom
	from index2019.data_poi
	where stretail is true
		and mall is false -- отбрасываем торговые центры
--		and id_gis < 700 -- дебаг
--		and id_gis in (select id_gis from streets group by id_gis) -- ленивый дебаг + время
	order by st_x(geom), st_y(geom)
),

/* проекция точек на улицы */
poi_proj as (
	select distinct on (s.id_str_part, st_linelocatepoint(st_transform(s.geom, 3857), st_transform(p.geom, 3857))) -- подчищаем точки проецирующиеся в одно место
		s.id_str_part,
		s.id_street,
		s.id_gis,
		s.name,
		s.str_len_m,
		s.str_part_len_m,
		st_linelocatepoint(st_transform(s.geom, 3857), st_transform(p.geom, 3857)) pnt_loc, -- положение точки на линии
		st_transform(st_makeline(st_transform(p.geom, 3857), st_lineinterpolatepoint(st_transform(s.geom, 3857), st_linelocatepoint(st_transform(s.geom, 3857), st_transform(p.geom, 3857)))), 4326) poi_line_geom,
		s.geom street_geom
	from poi p
	join streets s
		on st_dwithin(s.geom::geography, p.geom::geography, 50, true) -- берём точки на расстоянии не более 50 м. от улицы
			and s.id_gis = p.id_gis
	order by id_str_part, st_linelocatepoint(st_transform(s.geom, 3857), st_transform(p.geom, 3857))
),

/* расчёт отрезков между спроецированными точками */
street_parts as (
	select
		row_number() over(partition by id_str_part) pnt_id, -- нумерация спроецированных точек
		count(*) over(partition by id_str_part) pnt_count, -- подсчёт количества отрезков для каждой части улицы
		id_str_part,
		id_street,
		id_gis,
		name,
		str_len_m,
		str_part_len_m,
		pnt_loc,
		lag(pnt_loc) over(partition by id_str_part order by pnt_loc) prev_pnt_loc,  -- положение предыдущей точки на линии
		str_part_len_m * (pnt_loc - coalesce(lag(pnt_loc) over(partition by id_str_part order by pnt_loc), 0)) prev_dist_m, -- длина отрезка слева от точки
		poi_line_geom,
		(case
			when lag(pnt_loc) over(partition by id_str_part order by pnt_loc) is null
		 		or (str_part_len_m * (pnt_loc - coalesce(lag(pnt_loc) over(partition by id_str_part order by pnt_loc), 0))) > 100
				then null
			else st_transform(st_linesubstring(st_transform(street_geom, 3857), lag(pnt_loc) over(partition by id_str_part order by pnt_loc), pnt_loc), 4326) -- 4326 -> 3857 -> 4326 -> чтобы правильно отложить точки и восстановить по ним геометрию
		end)::geometry(linestring, 4326) retail_geom -- участок улицы с ритейлом (сразу отсекаем длиннее 100м)
	from poi_proj
),

/* кластеризация и поиск самого протяжённого участка ритейла для каждой улицы */
retail_max_part as (
	select distinct on (id_street)
		id_street,
		sum(case when prev_pnt_loc is null or prev_dist_m > 100 then 0 else prev_dist_m end) max_part_len_m, -- длина участка 
		st_multi(st_union(retail_geom))::geometry(multilinestring, 4326) max_part_geom -- сборка самого длинного участка улицы с ритейлом
	from (
		select *, count(new_cluster) over(order by id_part, id_str_part, id_street rows unbounded preceding) cluster_id
		from (
			select
				row_number() over() id_part,
				id_str_part,
				id_street,
				prev_dist_m,
				prev_pnt_loc,
				case
					when prev_dist_m > 100
						or prev_pnt_loc is null
						then true
				end new_cluster,
				retail_geom
			from street_parts
		) clustering -- отмечаем границы кластеров
	) assigned_clusters -- нумеруем кластеры
	group by id_street, cluster_id
	order by id_street, max_part_len_m desc
),

/* подсчёт суммарной протяжённости участков ритейла */
sum_street_parts as(
	select
		id_street,
		id_gis,
		name,
		str_len_m,
		sum(case when prev_pnt_loc is null or prev_dist_m > 100 then 0 else prev_dist_m end) sum_retail_len_m, -- сумма отрезков с проверкой на первую точку и максимальную длину
		st_multi(st_union(poi_line_geom))::geometry(multilinestring, 4326) poi_lines_geom,
		st_multi(st_union(retail_geom))::geometry(multilinestring, 4326) retail_geom,
		st_multi(st_union(poi_line_geom))::geometry(multilinestring, 4326) plines_geom
	from street_parts 
	group by id_street, id_gis, str_len_m, name
	order by sum(prev_dist_m) / str_len_m desc
)

/* сборка всех показателей для улицы */
select
	sp.id_gis,
	sp.id_street,
	sp.name,
	sp.str_len_m, -- протяжённость улицы
	sp.sum_retail_len_m, -- протяжённость участков ритейла
	mp.max_part_len_m, -- протяжённость самого длинного участка ритейла
	sp.sum_retail_len_m / sp.str_len_m  as ret_proportion,
	case when mp.max_part_len_m / sp.str_len_m >= 0.3 then true else null end max_part_03,
	case when sp.sum_retail_len_m / sp.str_len_m >= 0.75 then true else null end sum_retail_len_075,
	case when mp.max_part_len_m / sp.str_len_m >= 0.3 or sp.sum_retail_len_m / sp.str_len_m >= 0.75 then true else null end retail_street,
	sp.poi_lines_geom, -- точки POI, спроецированные на улицу
	sp.retail_geom, -- участки ритейла
	mp.max_part_geom -- самые длинные участки ритейла
from sum_street_parts sp
join retail_max_part mp using(id_street)
order by sp.id_gis, sum_retail_len_075, retail_street;

/* Индексы */
create unique index on index2019.viz_i10 (id_street); -- Первичный ключ
create index on index2019.viz_i10 (id_gis);
create index on index2019.viz_i10 (sum_retail_len_075);
create index on index2019.viz_i10 (max_part_03);
create index on index2019.viz_i10 (retail_street);
create index on index2019.viz_i10 using gist(retail_geom);
create index on index2019.viz_i10 using gist(poi_lines_geom);
create index on index2019.viz_i10 using gist(max_part_geom);

/* Комментарии */
comment on materialized view index2019.viz_i10 is 
'Улицы с развитым стритритейлом.
Визуализация 10-го индикатора.';
comment on column index2019.viz_i10.sum_retail_len_075 is 'Да, если ритейл на более 0.75 протяжённости улицы';
comment on column index2019.viz_i10.max_part_03 is 'Да, если ритейл непрерывно на более 0.3 протяжённости улицы';
comment on column index2019.viz_i10.retail_street is 'Да, если улица попадает в категорию "с развитым ритейлом"';
comment on column index2019.viz_i10.ret_proportion is 'Соотношение суммарной длины участков ритейла к длине улицы';
comment on column index2019.viz_i10.retail_geom is 'Участки улиц с ритейлом';
comment on column index2019.viz_i10.poi_lines_geom is 'Проекция точек POI на улицы';
comment on column index2019.viz_i10.max_part_geom is 'Самые длинные участки улиц с ритейлом';
comment on column index2019.viz_i10.id_street is 'Уникальный идентификатор улицы';
comment on column index2019.viz_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i10.name is 'Название улицы';
comment on column index2019.viz_i10.str_len_m is 'Протяжённость улицы в метрах';
comment on column index2019.viz_i10.sum_retail_len_m is 'Суммарная протяжённость участков с ритейлом в метрах';
comment on column index2019.viz_i10.max_part_len_m is 'Протяжённость самого длинного участка с ритейлом в метрах';


/* 10-й индикатор. Количество улиц с развитой сферой услуг ~ 1 сек. */
drop materialized view if exists index2019.ind_i10;
create materialized view index2019.ind_i10 as
with
	street_total as (select id_gis, count(*) street_total from index2019.data_street group by id_gis), -- общее число улиц в каждом городе
	street_stat as (
		select
			id_gis,
			count(*) filter(where max_part_03 is true) max_part_03_total,
			count(*) filter(where sum_retail_len_075 is true) retail_075_total,
			count(*) filter(where retail_street is true) retail_street_total
		from index2019.viz_i10
		group by id_gis
	) -- статистика по улицам с ритейлом в каждом городе

select
	b.id_gis,
	b.city,
	b.region,
	coalesce(r.max_part_03_total, 0) max_part_03_total,
	coalesce(r.retail_075_total, 0) retail_075_total,
	coalesce(r.retail_street_total, 0) retail_street_total,
	coalesce(s.street_total, 0) street_total,
	coalesce(round(r.retail_street_total / nullif(s.street_total, 0)::numeric, 4), 0) i10 -- с проверкой деления на 0
from index2019.data_boundary b
left join street_stat r using(id_gis)
left join street_total s using(id_gis)
order by b.id_gis;

/* Индексы */
create unique index on index2019.ind_i10 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i10 is 
'Улицы с развитым стритритейлом. 10-й индикатор.';
comment on column index2019.ind_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i10.city is 'Город';
comment on column index2019.ind_i10.region is 'Субъект РФ';
comment on column index2019.ind_i10.max_part_03_total is 'Количество улиц у которых самый длинный непрерывный участок ритейла от 0.3 протяжённости улицы';
comment on column index2019.ind_i10.retail_075_total is 'Количество улиц у которых суммарная протяжённость участков ритейла от 0.75 протяжённости улицы';
comment on column index2019.ind_i10.retail_street_total is 'Количество улиц развитым ритейлом';
comment on column index2019.ind_i10.street_total is 'Общее количество улиц в городе';
comment on column index2019.ind_i10.i10 is '10-й индикатор';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i10;
create view index2019.comp_i10 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(to_number(i2.total_stre, '99999D99'), 0) street_total_2018,
	coalesce(i1.street_total, 0) street_total_2019,
	coalesce(to_number(i2.retail_str, '99999D99'), 0) retail_street_total_2018,
	coalesce(i1.retail_street_total, 0) retail_street_total_2019,
	round(to_number(i2.i10,  '0D99999')::numeric, 4) i10_2018,
	i1.i10 i10_2019,
	(case 
		when i1.i10 > round(to_number(i2.i10, '0D99999')::numeric, 4)
			then 2019
	 	when i1.i10 = round(to_number(i2.i10, '0D99999')::numeric, 4)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i10 i1
left join index2018.i10_street_retail i2 on i1.id_gis = to_number(i2.id_gis, '9999')
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i10 is 'Сравнение с 2018 годом. 10-й индикатор. Улицы с развитым стритритейлом.';
comment on column index2019.comp_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i10.city is 'Город';
comment on column index2019.comp_i10.region is 'Субъект РФ';
comment on column index2019.comp_i10.street_total_2018 is 'Число улиц в городе на 2018 г.';
comment on column index2019.comp_i10.street_total_2018 is 'Число улиц в городе на 2019 г.';
comment on column index2019.comp_i10.retail_street_total_2018 is 'Число улиц с развитым стрит ритейлом в городе на 2018 г.';
comment on column index2019.comp_i10.retail_street_total_2018 is 'Число улиц с развитым стрит ритейлом в городе на 2019 г.';
comment on column index2019.comp_i10.i10_2018 is 'Отношение числа улиц с развитым стрит ритейлом к ощему числу улиц в городе на 2018 г.';
comment on column index2019.comp_i10.i10_2018 is 'Отношение числа улиц с развитым стрит ритейлом к ощему числу улиц в городе на 2019 г.';
comment on column index2019.comp_i10.higher_value is 'В каком году показатель "Отношение числа улиц с развитым стрит ритейлом к ощему числу улиц в городе" выше';
