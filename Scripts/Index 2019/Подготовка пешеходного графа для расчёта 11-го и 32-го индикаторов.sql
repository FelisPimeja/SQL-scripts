/* Подготовка графа для расчёта 11-го и 32-го индикаторов (ЛОКАЛЬНЫЙ id_gis = 643)*/

drop table if exists index2019.tmp_r643;
create table index2019.tmp_r643 as

/* обрезка дорог по границам городов + выкидываем motorway */
with roads_clipped as (
	select 
		row_number() over() id,
		b.id_gis,
		case
			when st_within(r.geom, b.geom) then r.geom
			else st_collectionextract(st_intersection(r.geom, b.geom), 2)
		end geom -- оптимизация пересечения
	from routing.roads r
	join index2019.data_boundary b 
		on st_intersects(r.geom, b.geom)
			and b.id_gis = 643  -- для дебага
	where r.type not in ('motorway', 'motorway_link') -- выбрасываем автомагистрали из нашего пешеходного графа
),

/* два следующих подзапроса пересобирают граф с разбивкой на перекрёстках */
/* разбивка графа на сегменты */
segments as (
	select
		id_gis,
		st_makeline(lag((pt).geom, 1, null) over (partition by id order by id, (pt).path), (pt).geom)::geometry(linestring, 4326) geom
	from (select id, id_gis, st_dumppoints(geom) as pt from roads_clipped) as dumps
),

/* обратная сборка из сегментов с упрощением */
roads_rebuilt as (
	select
		id_gis,
		st_simplify((st_dump(st_linemerge(st_collect(geom)))).geom, 0.00003)::geometry(linestring, 4326) geom
	from segments
	where geom is not null
	group by id_gis
),
roads_rebuilt2 as (select row_number() over() id, id_gis, geom from roads_rebuilt), -- добавляем id (в предыдущем запросе этого нельзя сделать из за st_dump)

/* !!! отсюда и дальше - возможно, добавление вершин для домов и POI в граф не нужно, если использовать WithPoints функции pgRouting (нужно исследовать производительность) !!!  */

/* создание объединённого слоя остановок ОТ, домов и соцобъектов */
poi_and_houses as (
	select geom from index2019.tmp_pop_altermag_2018 -- ПОМЕНЯТЬ ССЫЛКУ КОГДА БУДУТ ФИНАЛЬНЫЕ ДАННЫЕ!!!
	where id_gis = 643 -- для дебага
	union
	select geom from index2019.data_poi
	where (stretail is true 
		or odz is true
		or rubrics = 'Остановка общественного транспорта')
		and id_gis = 643 -- для дебага
),

/* поиск точек на слое дорог, ближайших к остановкам ОТ, домам и соцобъектам */
nearest_points as (
	select 
		r.id,
		r.id_gis,
		st_multi(st_union(st_transform(st_closestpoint(st_transform(r.geom, 3857), st_transform(p.geom, 3857)), 4326)))::geometry(multipoint, 4326) geom --сборка мультиточек по id улицы 
	from poi_and_houses p
	join lateral(
		select id, id_gis, geom 
		from roads_rebuilt2 r
		order by r.geom <-> p.geom
		limit 1
	) r on true -- поиск ближайшей
	group by r.id, r.id_gis
),

/* добавляем вершины в точках, ближайших к остановкам ОТ и домам */
roads_final as (
	select 
		r.id_gis,
		(st_dump(case
			when p.geom is null then r.geom
			else (st_split(st_snap(r.geom, p.geom, 0.00001), p.geom))
		end)).geom::geometry(linestring, 4326) geom
	from roads_rebuilt2 r 
	left join nearest_points p using(id)
)

/* новый id + служебные поля */
select row_number() over() id, id_gis, null::int source, null::int target, geom from roads_final;

/* строим граф */
select pgr_createTopology('index2019.tmp_r643', 0.00001, 'geom');


/* Индексы */
create index tmp_r643_id_gis on index2019.tmp_r643 (id_gis);

/* Комментарии */
comment on table index2019.tmp_r643 is 'Пешеходный граф дорог для расчёта 11-го и 32-го индикаторов (id_gis = 643)';