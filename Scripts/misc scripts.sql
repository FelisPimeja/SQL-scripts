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

	
	
	
	
	


-- Статистика по проценту аварийного жилья и жилищной обеспеченности в городах РФ

drop table if exists tmp.tmp_city_stat;
create table tmp.tmp_city_stat as 
--explain
with resid_area as (
	select
		id_gis,
		round(((sum(area_m2 * case when levels is not null then levels else 1::int2 end) filter(where building_type in ('igs', 'mkd'))) / 1000)::numeric) resid_area
	from russia.building_classify
--	where id_gis = 778
	group by id_gis
),

hazard_area as (
	select
		id_gis,
		round((sum(area_total) / 1000)::numeric) hazard_area
	from russia.dwelling_hazardous
--	where id_gis = 778
	group by id_gis	
)

select
	c.id_gis,
	c.city "Город",
	c.region_name "Субъект РФ",
	b.resid_area "Всего жилья, тыс.м2",
	coalesce(h.hazard_area, 0) "Всего авар. жилья, тыс.м2",
	coalesce(round((h.hazard_area * 100 / nullif(b.resid_area, 0))::numeric, 2), 0) "% авар. жилья",
	r.pop2020 "Население на 2020 г., чел.",
	coalesce(round((b.resid_area * 1000 / nullif(r.pop2020, 0))::numeric, 2), 0) "Обеспеч. жильём, м2/чел."
from russia.city c
left join resid_area b using(id_gis)
left join hazard_area h using(id_gis)
left join russia.city_population_rosstat r using(id_gis);



-- Удалённость городов от локальных и региональных центров

drop table if exists city;
create temp table city as
select
	c.id_gis,
	c.city,
	c.region_name,
	(st_centroid(c.geom))::geography geog,
	cn.center,
	case
		when st_x(st_centroid(c.geom)) < 60
			then 'to_the_west'::text 
		else 'to_the_east'::text
	end position_relatively_to_ural
from russia.city c
left join tmp.tmp_center cn using(id_gis);

create index on city(id_gis);
create index on city(city);
create index on city(center);
create index on city(region_name);
create index on city using gist(geog);


drop table if exists tmp.tmp_city;
create table tmp.tmp_city as
with d_0 as (
	select
		c.id_gis,
		case
			when d.id_gis is not null 
				then true
			else false
		end "in_2h_msk_spb"
	from city c
	left join lateral (
		select
			d.id_gis,
			d.geog			
		from city d
		where st_dwithin(c.geog, d.geog, 100000)
			and d.center = 0
		limit 1
	) d on true
),

d_1 as (
	select
		c.id_gis,
		case
			when d.id_gis is not null 
				then true
			else false
		end "in_1_5h_betw_reg"
	from city c
	left join lateral (
		select
			d.id_gis,
			d.geog			
		from city d
		where st_dwithin(c.geog, d.geog, 75000)
			and d.center = 1
		limit 1
	) d on true
),
	
d_2 as (
	select
		c.id_gis,
		case
			when d.id_gis is not null 
				then true
			else false
		end "in_1h_reg"
	from city c
	left join lateral (
		select
			d.id_gis,
			d.geog			
		from city d
		where st_dwithin(c.geog, d.geog, 50000)
			and d.center = 2
		limit 1
	) d on true
),

d_3 as (
	select
		c.id_gis,
		case
			when d.id_gis is not null 
				then true
			else false
		end "in_0_5h_loc"
	from city c
	left join lateral (
		select
			d.id_gis,
			d.geog			
		from city d
		where st_dwithin(c.geog, d.geog, 25000)
			and d.center = 3
		limit 1
	) d on true
)

select 
	c.id_gis,
	c.city "Город",
	c.region_name "Субъект РФ",
	st_centroid(c.geom)::geometry(point, 4326) geom,
	cc.center "Центр",
	cc.position_relatively_to_ural "Полож. относит. Урала",
	d_0.in_2h_msk_spb "в 2 ч. от МСК/СПБ",
	d_1.in_1_5h_betw_reg "в 1.5 ч. от межрег ц.",
	d_2.in_1h_reg "в 1 ч. от рег ц.",
	d_3.in_0_5h_loc "в 0.5 ч. от лок. ц."
from russia.city c
left join city cc using(id_gis)
left join d_0 using(id_gis)
left join d_1 using(id_gis)
left join d_2 using(id_gis)
left join d_3 using(id_gis)
order by c.id_gis;


	