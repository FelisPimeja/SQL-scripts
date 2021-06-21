/* 10-й индикатор. Улицы с развитой сферой услуг */
/* Время расчёта ~ 8 мин. */

/* разбираем улицы на singleparts для st_linelocatepoint и st_linelocatepoint */
create index on index2020.data_street((st_length(geom::geography)));
drop table if exists streets_exploded;
create temp table streets_exploded as
select
		id_street,
		id_gis,
		name,
		st_length(geom::geography) str_len_m, -- длина всей улицы
		st_length((st_dump(geom)).geom::geography) str_part_len_m, -- протяжённость конкретного участка улицы
		(st_dump(geom)).geom geom
	from index2020.data_street
	where st_length(geom::geography) >= 300
--		and id_gis <= 10 -- дебаг
;

drop table if exists streets;
create temp table streets as
select row_number() over() id_str_part, * from streets_exploded; -- новая номерация улиц
create index on streets(id_gis);
create index on streets using gist(st_transform(geom, 3857));
create index on streets using gist((geom::geography));

/* подчищаем пачки POI в одних координатах */
drop table if exists poi;
create temp table poi as
select distinct on (st_x(geom), st_y(geom)) id, id_gis, geom
	from index2020.data_poi
	where stretail is true
		and mall is false -- отбрасываем торговые центры
--		and id_gis < 700 -- дебаг
--		and id_gis in (select id_gis from streets group by id_gis) -- ленивый дебаг + время
	order by st_x(geom), st_y(geom);
create index on poi(id_gis);
create index on poi using gist(st_transform(geom, 3857));
create index on poi using gist((geom::geography));

/* проекция точек на улицы */
drop table if exists poi_proj;
create temp table poi_proj as
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
	from streets s
	join poi p
		on st_dwithin(s.geom::geography, p.geom::geography, 50, true) -- берём точки на расстоянии не более 50 м. от улицы
			and s.id_gis = p.id_gis
	order by id_str_part, st_linelocatepoint(st_transform(s.geom, 3857), st_transform(p.geom, 3857));
create index on poi_proj(id_str_part);
create index on poi_proj using gist(st_transform(street_geom, 3857));

/* расчёт отрезков между спроецированными точками */
drop table if exists street_parts;
create temp table street_parts as
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
	from poi_proj;
create index on street_parts(prev_dist_m);
create index on street_parts(prev_pnt_loc);
create index on street_parts(id_gis, id_street, str_len_m);

/* кластеризация и поиск самого протяжённого участка ритейла для каждой улицы */
drop table if exists assigned_clusters;
create temp table assigned_clusters as
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
		) clustering; -- отмечаем границы кластеров
create index on assigned_clusters(prev_pnt_loc);
create index on assigned_clusters(prev_dist_m);

drop table if exists retail_max_part;
create temp table retail_max_part as
	select distinct on (id_street)
		id_street,
		sum(case when prev_pnt_loc is null or prev_dist_m > 100 then 0 else prev_dist_m end) max_part_len_m, -- длина участка 
		st_multi(st_union(retail_geom))::geometry(multilinestring, 4326) max_part_geom -- сборка самого длинного участка улицы с ритейлом
	from assigned_clusters -- нумеруем кластеры
	group by id_street, cluster_id
	order by id_street, max_part_len_m desc;
create index on assigned_clusters(id_street);
create index on assigned_clusters(prev_dist_m);

	
/* подсчёт суммарной протяжённости участков ритейла */
drop table if exists sum_street_parts;
create temp table sum_street_parts as 
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
	order by sum(prev_dist_m) / str_len_m desc;
create index on sum_street_parts(id_street);

/* сборка всех показателей для улицы */
drop table if exists index2020.viz_i10;
create table index2020.viz_i10 as
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
alter table index2020.viz_i10 add primary key(id_street); -- Первичный ключ
create index on index2020.viz_i10 (id_gis);
create index on index2020.viz_i10 (sum_retail_len_075);
create index on index2020.viz_i10 (max_part_03);
create index on index2020.viz_i10 (retail_street);
create index on index2020.viz_i10 using gist(retail_geom);
create index on index2020.viz_i10 using gist(poi_lines_geom);
create index on index2020.viz_i10 using gist(max_part_geom);

/* Комментарии */
comment on table index2020.viz_i10 is 
'Улицы с развитым стритритейлом.
Визуализация 10-го индикатора.';
comment on column index2020.viz_i10.sum_retail_len_075 is 'Да, если ритейл на более 0.75 протяжённости улицы';
comment on column index2020.viz_i10.max_part_03 is 'Да, если ритейл непрерывно на более 0.3 протяжённости улицы';
comment on column index2020.viz_i10.retail_street is 'Да, если улица попадает в категорию "с развитым ритейлом"';
comment on column index2020.viz_i10.ret_proportion is 'Соотношение суммарной длины участков ритейла к длине улицы';
comment on column index2020.viz_i10.retail_geom is 'Участки улиц с ритейлом';
comment on column index2020.viz_i10.poi_lines_geom is 'Проекция точек POI на улицы';
comment on column index2020.viz_i10.max_part_geom is 'Самые длинные участки улиц с ритейлом';
comment on column index2020.viz_i10.id_street is 'Уникальный идентификатор улицы';
comment on column index2020.viz_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i10.name is 'Название улицы';
comment on column index2020.viz_i10.str_len_m is 'Протяжённость улицы в метрах';
comment on column index2020.viz_i10.sum_retail_len_m is 'Суммарная протяжённость участков с ритейлом в метрах';
comment on column index2020.viz_i10.max_part_len_m is 'Протяжённость самого длинного участка с ритейлом в метрах';


/* 10-й индикатор. Количество улиц с развитой сферой услуг ~ 1 сек. */
drop table if exists index2020.ind_i10;
create table index2020.ind_i10 as
with
	street_total as (select id_gis, count(*) street_total from index2020.data_street group by id_gis), -- общее число улиц в каждом городе
	street_stat as (
		select
			id_gis,
			count(*) filter(where max_part_03 is true) max_part_03_total,
			count(*) filter(where sum_retail_len_075 is true) retail_075_total,
			count(*) filter(where retail_street is true) retail_street_total
		from index2020.viz_i10
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
from index2020.data_boundary b
left join street_stat r using(id_gis)
left join street_total s using(id_gis)
order by b.id_gis;

/* Индексы */
alter table index2020.ind_i10 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i10 is 
'Улицы с развитым стритритейлом. 10-й индикатор.';
comment on column index2020.ind_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i10.city is 'Город';
comment on column index2020.ind_i10.region is 'Субъект РФ';
comment on column index2020.ind_i10.max_part_03_total is 'Количество улиц у которых самый длинный непрерывный участок ритейла от 0.3 протяжённости улицы';
comment on column index2020.ind_i10.retail_075_total is 'Количество улиц у которых суммарная протяжённость участков ритейла от 0.75 протяжённости улицы';
comment on column index2020.ind_i10.retail_street_total is 'Количество улиц развитым ритейлом';
comment on column index2020.ind_i10.street_total is 'Общее количество улиц в городе';
comment on column index2020.ind_i10.i10 is '10-й индикатор';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i10;
create table index2020.comp_i10 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.street_total, 0) street_total_2019,
	coalesce(i1.street_total, 0) street_total_2020,
	coalesce(i2.retail_street_total, 0) retail_street_total_2019,
	coalesce(i1.retail_street_total, 0) retail_street_total_2020,
	i2.i10 i10_2019,
	i1.i10 i10_2020,
	(case 
		when i1.i10 > i2.i10 then 2020
	 	when i1.i10 = i2.i10 then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i10 i1
left join index2019.ind_i10 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i10 is 'Сравнение с 2019 годом. 10-й индикатор. Улицы с развитым стритритейлом.';
comment on column index2020.comp_i10.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i10.city is 'Город';
comment on column index2020.comp_i10.region is 'Субъект РФ';
comment on column index2020.comp_i10.street_total_2019 is 'Число улиц в городе на 2019 г.';
comment on column index2020.comp_i10.street_total_2019 is 'Число улиц в городе на 2020 г.';
comment on column index2020.comp_i10.retail_street_total_2019 is 'Число улиц с развитым стрит ритейлом в городе на 2019 г.';
comment on column index2020.comp_i10.retail_street_total_2019 is 'Число улиц с развитым стрит ритейлом в городе на 2020 г.';
comment on column index2020.comp_i10.i10_2019 is 'Отношение числа улиц с развитым стрит ритейлом к ощему числу улиц в городе на 2019 г.';
comment on column index2020.comp_i10.i10_2019 is 'Отношение числа улиц с развитым стрит ритейлом к ощему числу улиц в городе на 2020 г.';
comment on column index2020.comp_i10.higher_value is 'В каком году показатель "Отношение числа улиц с развитым стрит ритейлом к ощему числу улиц в городе" выше';




/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",	
	street_total_2019 "Всего улиц в городе, шт. (2019)",
	street_total_2020 "Всего улиц в городе, шт. (2020)",
	retail_street_total_2019 "Улиц с разв. стритрет., шт. (2019)",
	retail_street_total_2020 "Улиц с разв. стритрет., шт. (2020)",
	i10_2019 "Отнош. ул с разв. ретейл к общ числу ул(2019)",
	i10_2020 "Отнош. ул с разв. ретейл к общ числу ул(2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i10;
 */


