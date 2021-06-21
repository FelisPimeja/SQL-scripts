/* Подсчёт площади промтерриторий у воды в границах городов */
/* Время расчёта ~ 1 час */
/* Выбираем города для расчёта */
drop table if exists t_city; 
create temp table t_city as
select * from russia.city
--where id_gis <= 100 -- дебаг
;
create index on t_city(id_gis);
create index on t_city using gist(geom)
;
/* Выбираем всю площадную воду в городах по списку */
drop table if exists water; 
create temp table water as 
-- Сначала выбираем площадную воду
select
	w.id,
	c.id_gis,
	w.type,
	w.name,
	w.other_tags,
	w.geom
from t_city c
left join russia.water_osm w
	on st_intersects(c.geom, w.geom)
		and (
			type in (
				'lake',
				'pond',
				'river',
				'riverbank',
				'stream',
				'water',
				'yes'
			)
			or type is null
		)
		and st_area(w.geom::geography) >= 5000 -- проверка по площади. Надо уточнить границу отсечки!!!
union all 
-- До кучи строим буфер от линейных водных объектов
select
	w.id,
	c.id_gis,
	w.type,
	w.name,
	w.other_tags,
	st_buffer(w.geom::geography, 2)::geometry geom
from t_city c
left join russia.waterway_osm w 
	on st_intersects(c.geom, w.geom)
		and w.type in ('river', 'canal')
		and w.intermittent is false
		and w.other_tags -> 'tunnel' is null
;
create index on water(id_gis);
create index on water using gist(geom);
create index on water using gist((geom::geography))
;
-- Выбираем все промтерритории в городах по списку 
drop table if exists industrial; 
create temp table industrial as 
select l.*
from t_city c
left join russia.landuse_osm l 
	on c.id_gis = l.id_gis
		and l.type in (
			'industrial',
--			'railway',
--			'military',
			'garages',
			'plant'
-- 			список надо будет уточнить
		)		
;
create index on industrial(id_gis);
create index on industrial using gist(geom);
create index on industrial using gist((geom::geography))
;
-- Выбираем промтерритории в радиусе 25 м от воды
-- добавить корректировку топологии!!!
-- вкорячить аварийное жильё!!!
drop table if exists w_industrial; 
create temp table w_industrial as 
select distinct on(i.id) i.*
from water w
join industrial i
	on st_dwithin(w.geom::geography, i.geom::geography, 25)
;
create index on w_industrial (id_gis);
create index on w_industrial using gist(geom);
create index on w_industrial using gist((geom::geography))
;
drop table if exists poi_1; 
create temp table poi_1 as 
select distinct on(p.id) p.* -- потому что я не избавлялся от накладывающихся полигонов в OSM
from w_industrial i
left join russia.poi_yandex_2020 p 
	on p.id_gis = i.id_gis
		and st_intersects(p.geom, i.geom) 
;
create index on poi_1(id_gis)
;
drop table if exists poi_2; 
create temp table poi_2 as
select distinct on(p.id) p.*
from russia.yandex_classifier_2021 c 
join poi_1 p 
	on p.category_name like '%' || c.category_name || '%'
where c.subclass  in ('Промышленное предприятие, завод', 'Автосервис, автотехцентр', 'Автосалон, авторынок', 'Гаражный кооператив', 'Шиномонтаж')
;
create index on poi_2 using gist((geom::geography))
;
drop table if exists poi; 
create temp table poi as
select p.*
from water w
join poi_2 p 
	on st_dwithin(p.geom::geography, w.geom::geography, 200)
;
create index on poi(id_gis)
;
drop table if exists poi_stat; 
create temp table poi_stat as
select id_gis, count(*) poi_total from poi group by id_gis
;
/* Считаем статистику по прому (суммарная площадь, + протяжённость береговой линии через пересечение буфера от прома и контура площадной воды) */
drop table if exists tmp.shore_industrial; 
create table tmp.shore_industrial as 
with dis_w as (
	select
		id_gis,
		st_boundary(st_union(geom)) geom,
		st_union(geom) u_geom 
	from water
	group by id_gis
),
buf_ind as (
	select                                                                                                                               
		id_gis,
		st_union(st_buffer(geom::geography, 30)::geometry) geom,
		st_union(geom) i_geom,
		round((st_area(st_union(geom)::geography) / 10000)::numeric, 2) sum_industrial_area_ha
	from w_industrial i
	group by id_gis
),
count_ind as (
	select                                                                                                                               
		id_gis,
		count(*) count_ind
	from w_industrial i
	group by id_gis
),
len as (
	select
		id_gis,
		round((st_length(st_intersection(w.geom, i.geom)::geography) / 1000)::numeric, 2) sum_ind_len_km,
--		st_multi(w.u_geom)::geometry(multipolygon, 4326) water_geom,
--		st_multi(i.i_geom)::geometry(multipolygon, 4326) ind_geom,
--		st_intersection(w.geom, i.geom) inter,
		sum_industrial_area_ha
	from dis_w w 
	join buf_ind i using(id_gis)
)
select
	c.id_gis,
	c.city "Город",
	c.region_name "Субъект РФ",
	coalesce(l.sum_ind_len_km, 0) "Протяж береговой линии прома, км.",
	coalesce(p.poi_total, 0) "Всего пром объектов на берег линии",
	coalesce(i.count_ind, 0) "Всего пром терр на берег линии",
	coalesce(l.sum_industrial_area_ha, 0) "Площ пром терр на берег линии, га"
from t_city c 
left join len l using(id_gis)
left join poi_stat p using(id_gis)
left join count_ind i using(id_gis)
order by c.city
;


-- Классифицируем новостройки по расположенности у воды
drop table if exists mkd; 
create temp table mkd as 
select distinct on (m.id)
	m.id,
	m.id_gis,
	m.zhk_name,
	m.zhk_class,
	m.flat_price_per_m2_mean,
	case when w.id is not null then true else false end near_water -- расположение рядом с водой
from russia.new_mkd_100 m
left join water w
	on m.id_gis = w.id_gis	
		and st_dwithin(m.geom::geography, w.geom::geography, 50)
;
create index on mkd(id_gis);
create index on mkd(near_water);
create index on mkd(zhk_class);
create index on mkd(flat_price_per_m2_mean);

-- Считаем статы по новостройкам
drop table if exists tmp.mkd_stat; 
create table tmp.mkd_stat as 
select
	id_gis,
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Эконом'))::numeric, 2) "Ср ст м2 Эконом у воды",
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Комфорт'))::numeric, 2) "Ср ст м2 Комфорт у воды",
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Бизнес'))::numeric, 2) "Ср ст м2 Бизнес у воды",
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Премиум'))::numeric, 2) "Ср ст м2 Премиум у воды",
--	
	round((avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Эконом'))::numeric, 2) "Ср ст м2 Эконом не у воды",
	round((avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Комфорт'))::numeric, 2) "Ср ст м2 Комфорт не у воды",
	round((avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Бизнес'))::numeric, 2) "Ср ст м2 Бизнес у не воды",
	round((avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Премиум'))::numeric, 2) "Ср ст м2 Премиум не у воды",
--	
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Эконом') / avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Эконом') * 100 - 100)::numeric) "Превышен стоим Эконом у воды %",
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Комфорт') / avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Комфорт') * 100 - 100)::numeric) "Превышен стоим Комфорт у воды %",
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Бизнес') / avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Бизнес') * 100 - 100)::numeric) "Превышен стоим Бизнес у воды %",
	round((avg(flat_price_per_m2_mean) filter(where near_water is true and zhk_class = 'Премиум') / avg(flat_price_per_m2_mean) filter(where near_water is false and zhk_class = 'Премиум') * 100 - 100)::numeric) "Превышен стоим Премиум у воды %"
from mkd
group by id_gis;

--Для Excel
--select * from tmp.shore_industrial;
--select b.city "Город", b.region_name "Субъект РФ", m.*
--from tmp.mkd_stat m
--left join russia.city b using(id_gis);
