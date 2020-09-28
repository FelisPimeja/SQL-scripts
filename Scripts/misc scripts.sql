/* Здесь всё временное и проходное - "на всякий случай" */

--доступность остановок общественного транспорта для городов ВЭБа
select
	(row_number() over(order by i.pop_total desc))::int id,	
	b.id_gis,
	b.city "Город",
	b.region "Субъект РФ",
	i.pop_total "Население города (Росстат 2019 г.)" ,
	i.pop_instopsarea "Население в радиусе норматив. доступн. остановок ОТ",
	round(i.i32::numeric * 100) "Процент населения в радиусе доступности ОТ"
from veb_rf.city b
left join index2019.ind_i32 i using(id_gis);


-- Трамвайные линии для (Волгоград Нижний Новгород Санкт-Петербург (Красногвардейский раойн) Самара)
select r.*, b.id_gis
from russia.city_boundary b
join osm.railroads_ru r
	on st_intersects(r.geom, b.geom)
		and r.type = 'tram'
where b.city in (
	'Волгоград',
	'Нижний Новгород',
	'Санкт-Петербург',
	'Самара'
);


-- Статистика по плотности населения в урбанизированной части городов + ещё несколько показателей
-- Время расчёта ~ 30 сек.
with public_transport_stops as (
	select 
		id_gis,
		count(*) pt_stop_count
	from index2019.data_poi 
	where rubrics = 'Остановка общественного транспорта'
	group by id_gis
),

dist_1m_city as (
	select 
		b1.id_gis,
		b1.city,
		b1.geog,
		b2.id_gis id_gis2,
		b2.city,
		round((st_distance(b1.geog, b2.geog))::numeric / 1000) dist_1m_city
	from (
		select
			c.id_gis,
			c.city,
			st_centroid(c.geom)::geography geog,
			p.pop2020 pop
		from russia.city c
		left join index2020.data_pop_rosstat p using(id_gis)
	) b1
	left join lateral (
		select
			b2.id_gis,
			b2.city,
			b2.geog
		from (
			select
				c.id_gis,
				c.city,
				st_centroid(c.geom)::geography geog,
				p.pop2020 pop
			from russia.city c
			left join index2020.data_pop_rosstat p using(id_gis)
		) b2
			where b2.pop >= 1000000
		order by b1.geog <-> b2.geog
		limit 1
	) b2 on true
	where b1.geog is not null
),

sdz_density as (select id_gis, count(*) filter(where sdz is true) count_sdz	from index2019.data_poi	group by id_gis)

select
	c.id_gis,
	c.city "Город",
	c.region_name "Субъект РФ",
--	c.start_year "Год основания",
	round((st_area(c.geom::geography) / 10000)::numeric, 2) "Площадь города в границах, га",
	ba.area_ha "Площадь урбан. территории, га",
	p.pop2020 "Нас. по данным Росстата на 2020 г., чел.",
	coalesce((p.pop2020 / ba.area_ha)::int, 0) "Плотн. нас. урбан. части, чел./га",
	round((sd.count_sdz / (st_area(c.geom::geography) / 10000))::numeric, 2) "Плотность соц-досуг функций, ед./га",
	pt.pt_stop_count "Кол-во остановок общ. транспорта",
	d.dist_1m_city "Расстояние до ближ. миллионника, км.",
	coalesce(g.type, 'Нет') "Геостратегическая территория РФ",
	case when c.start_year < 1917 then 'Есть' else 'Нет' end "Наличие исторического центра"
from russia.city c
left join russia.city_built_area_light ba using(id_gis)
left join index2020.data_pop_rosstat p using(id_gis)
left join public_transport_stops pt using(id_gis)
left join dist_1m_city d using(id_gis)
left join sdz_density sd using(id_gis)
left join russia.geostrategic_territory g
	on st_intersects(g.geom, st_centroid(c.geom))
where c.geom is not null
order by p.pop2020 desc;

alter table traffic.collect_data_test2 drop constraint collect_data_test2_pkey

drop table if exists tmp.rast_test;
create table tmp.rast_test as select t1.rid, t1.filename, st_clip(t1.rast, 1, t3.geom, -999, true) rast from tmp.r_test1 t1 join tmp.t3 on st_intersects(t3.geom, t1.rast)

drop table tmp.cycle_rout_cadaster; 
create table tmp.cycle_rout_cadaster as 
select distinct on (p.id) p.* from cadastr2016.parcel p join tmp.route c on st_intersects(p.geom, c.buf);
create index on tmp.cycle_rout_cadaster using gist(geom);
alter table tmp.cycle_rout_cadaster add primary key(id);
create index on tmp.cycle_rout_cadaster(cad_ref);

alter table tmp.route add column buf geometry(polygon, 4326);
update  tmp.route set buf = st_buffer(geom::geography, 50)::geometry(polygon, 4326);
create index on  tmp.route using gist(buf);

create index on tmp.corridor using gist(geom);

alter table traffic.city_road_rebuild
	rename column id to road_segment_id
	
	