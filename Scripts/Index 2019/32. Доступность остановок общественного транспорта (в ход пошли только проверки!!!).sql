/* 32-й индикатор. Доступность остановок общественного транспорта */
/* Время расчёта ~ - часов */

drop materialized view if exists index2019.viz_i32 cascade;
create materialized view index2019.viz_i32 as 
with

	/* Выбираем дома и ближайшие к ним вершины графа */
	house as (
		select 
			h.id_gis,
			case when h.floor = 0 then 'house' else 'apartments' end house_type, -- Разбор на индивидуальные и многоквартирные
			h.population,
			g.id vid,
			st_makeline(h.geom, g.geom) start_geom -- линия от дома до вершины
		from index2019.tmp_pop_altermag_2018 h
		left join lateral (
			select id, the_geom geom
			from index2019.tmp_r643_vertices_pgr pn
			order by h.geom::geography <-> pn.the_geom::geography
			limit 1
		) g on true -- поиск ближайшей вершины
		where id_gis = 643 -- для дебага
--			and h.id = 2586 -- дебаг маршрута от конкретного дома
	),
	
	/* Выбираем остановки общественного транспорта и ближайшие к ним вершины графа */
	bus_stop as (
		select
			p.id_gis,
			g.id vid,
			st_makeline(g.geom, p.geom) end_geom -- линия от дома до вершины
		from index2019.data_poi p
		left join lateral (
			select id, the_geom geom
			from index2019.tmp_r643_vertices_pgr pn
			order by p.geom::geography <-> pn.the_geom::geography
			limit 1
		) g on true -- поиск ближайшей вершины
		where id_gis = 643 -- для дебага
		and rubrics = 'Остановка общественного транспорта'
	),
	
	/* Все пары маршрутных точек */
		directions as (
		select
			row_number() over() id,
			t.id_gis,
			t.vid to_point, -- вершина графа конца маршрута (остановка ОТ)
			array_agg(f.vid) from_point, -- массив вершин графа начала маршрута (дома)
			st_collect(f.start_geom),
			t.end_geom end_geom,
			st_astext(st_buffer(st_envelope(st_collect(t.end_geom, st_collect(f.start_geom)))::geography, 400,'quad_segs=1')::geometry) zone_geom -- бокс 400 м буфера от вершин начала и конца маршрута для фильтрации графа
		from bus_stop t
		join house f
			on f.id_gis = t.id_gis
				and st_dwithin(
					st_startpoint(f.start_geom)::geography,
					st_endpoint(t.end_geom)::geography,
					case
						when f.house_type = 'house' then 800
						else 500
					end,
					true) -- поиск всех останоок в заданном радиусе
		group by t.id_gis, t.vid, t.end_geom
--		limit 1
	) -- маршруты на парах вершин графа	(отправление - назначение)

/* Строим маршруты и выбираем самый короткий для каждой точки */
select distinct on (pt.start_vid)
	pt.start_vid from_point,
	r.to_point,
	h.house_type,
	h.population,
	r.id_gis,
	st_length(st_collect(array[h.start_geom, st_collect(geom), end_geom])::geography, true) route_len_m,
--	st_collect(st_collect(st_multi(st_linemerge(st_union(array[h.start_geom, st_union(geom), end_geom]))), st_startpoint(h.start_geom)), st_endpoint(end_geom))::geometry geom_viz, -- дебаг визуалка 
	st_union(array[h.start_geom, st_collect(geom), end_geom])::geometry(multilinestring, 4326) route_geom
from directions r
left join lateral pgr_dijkstra (
	'select
		id,
		source,
		target,
		st_length(geom::geography, true) as cost
	from index2019.tmp_r643
	where id_gis = '|| (select f.id_gis from directions f where f.id = r.id) ||
		'  and st_geomfromtext($$'|| (select f.zone_geom from directions f where f.id = r.id) ||'$$, 4326) && geom '::text, -- выборка графа по ббоксу
	(select f.from_point from directions f where f.id = r.id), -- начало маршрута
	(select t.to_point from directions t where t.id = r.id), -- конец маршрута
	false
) as pt on true
join index2019.tmp_r643 rd ON pt.edge = rd.id -- визуализация маршрута
left join house h on h.vid = pt.start_vid
--where pt.start_vid = 1972 -- для дебага
group by r.id_gis, r.to_point, pt.start_vid, r.end_geom, h.start_geom, h.house_type, h.population
order by pt.start_vid, st_length(st_union(st_union(st_union(geom), h.start_geom), end_geom)::geography, true);

/* Индексы */
create unique index on index2019.viz_i32 (from_point); -- Первичный ключ
create index on index2019.viz_i32 (to_point);
create index on index2019.viz_i32 (house_type);
create index on index2019.viz_i32 (population);
create index on index2019.viz_i32 (id_gis);
create index on index2019.viz_i32 (route_len_m);
create index on index2019.viz_i32 using gist(route_geom);

/* Комментарии */
comment on materialized view index2019.viz_i32 is 
'Доступность остановок общественного транспорта.
Визуализация 32-го индикатора.';
comment on column index2019.viz_i32.from_point is 'Вершина графа от которой проложен маршрут';
comment on column index2019.viz_i32.to_point is 'Вершина графа к которой проложен маршрут';
comment on column index2019.viz_i32.house_type is 'Тип дома (индивидуальный, многоквартирный)';
comment on column index2019.viz_i32.population is 'Количество жителей в доме (Альтермаг)';
comment on column index2019.viz_i32.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i32.route_len_m is 'Длина маршрута в метрах';
comment on column index2019.viz_i32.route_geom is 'Геометрия маршрута';


/* 32-й индикатор. Доступность остановок общественного транспорта ~ 1 сек. */
drop materialized view if exists index2019.ind_i32;
create materialized view index2019.ind_i32 as

/* Суммируем население в радиусе доступности */
with i as (
	select
		id_gis,
		sum(population) pop_within_pt_radius
	from index2019.viz_i32
	where route_len_m <= (case when house_type = 'house' then 800 else 500 end) -- проверка длины маршрута
	group by id_gis
)

/* Собираем итоговые цифры */
select
	b.id_gis,
	b.city,
	b.region,
	nullif(p.pop2019, 0) population, -- общее население города
	nullif(i.pop_within_pt_radius, 0) pop_within_pt_radius, -- количество людей, проживающих в радиусе доступности от остановки общественного транспорта
	round(i.pop_within_pt_radius / nullif(p.pop2019, 0)::numeric, 4) i32
from index2019.data_boundary b
join index2019.data_pop_rosstat p using(id_gis)
join i using(id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i32 is 
'Доступность остановок общественного транспорта. 32-й индикатор.';
comment on column index2019.ind_i32.city is 'Город';
comment on column index2019.ind_i32.region is 'Субъект РФ';
comment on column index2019.ind_i32.population is 'Общее население города (по данным Росстата)';
comment on column index2019.ind_i32.pop_within_pt_radius is 'Количество людей, проживающих в радиусе доступности от остановки общественного транспорта';
comment on column index2019.ind_i32.i32 is '32-й индикатор';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i32;
create view index2019.comp_i32 as
select 
	b.id_gis::smallint,
	b.city,
	b.region,
	coalesce(i2.pop_total::int, 0) population_2018,
	coalesce(i1.pop_total, 0) population_2019,
	coalesce(i2.pop_instop::int, 0) populations_in_radius_2018,
	coalesce(i1.pop_instopsarea, 0) populations_in_radius_2019,
	coalesce(pt2.pt, 0) total_stops_2018,
	coalesce(pt1.pt, 0) total_stops_2019,
	coalesce(replace(i2.i32, ',','.')::numeric, 0) accessibility_2018,
	coalesce(i1.i32, 0) accessibility_2019,
	(case 
		when coalesce(i1.i32, 0) > coalesce(replace(i2.i32, ',','.')::numeric, 0)
			then 2019
	 	when coalesce(i1.i32, 0) = coalesce(replace(i2.i32, ',','.')::numeric, 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.data_boundary b
left join index2019.ind_i32 i1 using(id_gis)
left join index2018.i32_public_transport_access i2 on i1.id_gis = i2.id_gis::int
left join (select id_gis, count(*) pt from index2019.data_poi where rubrics = 'Остановка общественного транспорта' group by id_gis) pt1 on pt1.id_gis = b.id_gis
left join (select id_gis, count(*) pt from index2018.data_poi where rubrics = 'Остановка общественного транспорта' group by id_gis) pt2 on pt2.id_gis = b.id_gis
order by b.id_gis;

/* Комментарии */
comment on view index2019.comp_i32 is 'Сравнение с 2018 годом. 32-й индикатор. Доступность остановок общественного транспорта.';
comment on column index2019.comp_i32.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i32.city is 'Город';
comment on column index2019.comp_i32.region is 'Субъект РФ';
comment on column index2019.comp_i32.population_2018 is 'Население города на 2018 г., чел.';
comment on column index2019.comp_i32.population_2019 is 'Население города на 2019 г., чел.';
comment on column index2019.comp_i32.populations_in_radius_2018 is 'Население города в радиусе доступности остановки на 2018 г., чел.';
comment on column index2019.comp_i32.populations_in_radius_2019 is 'Население города в радиусе доступности остановки на 2019 г., чел.';
comment on column index2019.comp_i32.total_stops_2018 is 'Общее количество остановок общественного транспорта в городе на 2018 г., ед.';
comment on column index2019.comp_i32.total_stops_2019 is 'бщее количество остановок общественного транспорта в городе на 2019 г., ед.';
comment on column index2019.comp_i32.accessibility_2018 is 'Доступность остановок общественного транспорта на 2018 г.';
comment on column index2019.comp_i32.accessibility_2019 is 'Доступность остановок общественного транспорта на 2019 г.';
comment on column index2019.comp_i32.higher_value is 'В каком году показатель "Доступность остановок общественного транспорта" выше';