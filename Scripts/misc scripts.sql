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

	
	
-- Статистика по таблице типологии кварталов
drop table if exists tmp.city_quater_stat;
create table tmp.city_quater_stat as 
select
	b.id_gis,
	b.city "Город",
	b.region_name "Субъект РФ",
	coalesce(count(q.*), 0) "Кол-во кварталов в городе",
	coalesce(count(q.*) filter(where quater_class = 'Индивидуальная жилая городская среда'), 0) "Кол-во кварт. ИЖС",
	coalesce(count(q.*) filter(where quater_class = 'Историческая смешанная городская среда'), 0) "Кол-во кварт. Истор. смеш.",
	coalesce(count(q.*) filter(where quater_class = 'Cоветская периметральная городская среда'), 0) "Кол-во кварт. Советск. периметр.",
	coalesce(count(q.*) filter(where quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда') ), 0) "Кол-во кварт. Малоэтажн. многокв.",
	coalesce(count(q.*) filter(where quater_class = 'Среднеэтажная микрорайонная городская среда'), 0) "Кол-во кварт. Среднеэтажн. многокв.",
	coalesce(count(q.*) filter(where quater_class = 'Многоэтажная микрорайонная городская среда'), 0) "Кол-во кварт. Многоэтажн. многокв.",
	coalesce(count(q.*) filter(where quater_class = 'Нежилая городская среда'), 0) "Кол-во кварт. Нежилых",
	coalesce(count(q.*) filter(where quater_class is null), 0) "Кол-во кварт. Не классифиц.",
	coalesce(sum(q.area_ha), 0) "Cуммарная площ. кварталов, га",
	coalesce(sum(q.area_ha) filter(where quater_class = 'Индивидуальная жилая городская среда'), 0) "Cумм. площ. кварт. ИЖС, га",
	coalesce(sum(q.area_ha) filter(where quater_class = 'Историческая смешанная городская среда'), 0) "Cумм. площ. кварт. Истор. смеш., га",
	coalesce(sum(q.area_ha) filter(where quater_class = 'Cоветская периметральная городская среда'), 0) "Cумм. площ. кварт. Советск. периметр., га",
	coalesce(sum(q.area_ha) filter(where quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда') ), 0) "Cумм. площ. кварт. Малоэтажн. многокв., га",
	coalesce(sum(q.area_ha) filter(where quater_class = 'Среднеэтажная микрорайонная городская среда'), 0) "Cумм. площ. кварт. Среднеэтажн. многокв., га",
	coalesce(sum(q.area_ha) filter(where quater_class = 'Многоэтажная микрорайонная городская среда'), 0) "Cумм. площ. кварт. Многоэтажн. многокв., га",
	coalesce(sum(q.area_ha) filter(where quater_class = 'Нежилая городская среда'), 0) "Cумм. площ. кварт. Нежилых, га",
	coalesce(sum(q.area_ha) filter(where quater_class is null), 0) "Cумм. площ. кварт. Не классифиц., га",
	coalesce(round((sum(q.area_ha) filter(where quater_class = 'Индивидуальная жилая городская среда') * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. ИЖС",
	coalesce(round((sum(q.area_ha) filter(where quater_class = 'Историческая смешанная городская среда') * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Истор. смеш.",
	coalesce(round((sum(q.area_ha) filter(where quater_class = 'Cоветская периметральная городская среда') * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Советск. периметр.",
	coalesce(round((sum(q.area_ha) filter(where quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда') ) * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Малоэтажн. многокв.",
	coalesce(round((sum(q.area_ha) filter(where quater_class = 'Среднеэтажная микрорайонная городская среда') * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Среднеэтажн. многокв.",
	coalesce(round((sum(q.area_ha) filter(where quater_class = 'Многоэтажная микрорайонная городская среда') * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Многоэтажн. многокв.",
	coalesce(round((sum(q.area_ha) filter(where quater_class = 'Нежилая городская среда') * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Нежилых",
	coalesce(round((sum(q.area_ha) filter(where quater_class is null) * 100 / sum(q.area_ha))::numeric, 2), 0) "% кварт. Не классифиц."
from russia.city b
join tmp.tmp_quater_30 q using(id_gis)
group by b.id_gis, b.city, b.region_name
	
	


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




/* Подсчёт разной статистики по регионам для оценки туристической привлекательности */
/* Время расчёта < 30 сек. */
with urban_area as (
	select 
		r.name,
		sum(u.area_ha) * 10000 urban_area_m2
	from russia.region_boundary_land r
	join russia.city_built_area_light u 
		on st_intersects(st_centroid(u.geom), r.geom)
	group by r.name
),
okn_count as (
	select 
		c.region_name "name",
		count(o.*) total_okn
	from (
		select distinct region_name from russia.city
	) c
	left join russia.raw_okn o
		on (
			o."Регион" = c.region_name
				or (
					o."Регион" = 'г. Москва'
						and c.region_name = 'Город федерального значения Москва'
				)
				or (
					o."Регион" = 'г. Санкт-Петербург'
						and c.region_name = 'Город федерального значения Санкт-Петербург'
				)
				or (
					o."Регион" = 'г. Севастополь'
						and c.region_name = 'Город федерального значения Севастополь'
				)
				or (
					o."Регион" = 'Кемеровская область'
						and c.region_name = 'Кемеровская область — Кузбасс'
				)
				or (
					o."Регион" = 'Республика Адыгея (Адыгея)'
						and c.region_name = 'Республика Адыгея'
				)
				or (
					o."Регион" = 'Республика Северная Осетия - Алания'
						and c.region_name = 'Республика Северная Осетия — Алания'
				)
				or (
					o."Регион" = 'Республика Татарстан (Татарстан)'
						and c.region_name = 'Республика Татарстан'
				)
				or (
					o."Регион" = 'Чувашская Республика - Чувашия'
						and c.region_name = 'Чувашская Республика'
				)
		)
			and o."Id_4" not like '%Памятник археологии%'
	group by c.region_name
	order by total_okn desc
),
historic as (
	select
		r.name,
		coalesce(sum(q.area_ha * 10000), 0) historic_area_m2
	from russia.region_boundary_land r
	join (
		select
			c.region_name "name",
			q.area_ha
		from russia.city c
		left join russia.city_quater_type q 
			on c.id_gis = q.id_gis 
				and q.quater_class = 'Историческая смешанная городская среда'
	) q using("name")
	group by r.name
),
oopt as (
	select 
		r.name,
		round(sum(st_area(st_intersection(o.geom, r.geom)::geography))::numeric) oopt_area_m2
	from russia.region_boundary_land r
	join russia.oopt o 
		on st_intersects(o.geom, r.geom)
	group by r.name
),
climate as (
	select
		r.name,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'BSk')))::geography)::numeric), 0) area_BSk_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Cfa')))::geography)::numeric), 0) area_Cfa_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Cfb')))::geography)::numeric), 0) area_Cfb_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Csa')))::geography)::numeric), 0) area_Csa_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dfa')))::geography)::numeric), 0) area_Dfa_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dfb')))::geography)::numeric), 0) area_Dfb_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dfc')))::geography)::numeric), 0) area_Dfc_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dfd')))::geography)::numeric), 0) area_Dfd_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dsc')))::geography)::numeric), 0) area_Dsc_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dsd')))::geography)::numeric), 0) area_Dsd_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dwa')))::geography)::numeric), 0) area_Dwa_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dwb')))::geography)::numeric), 0) area_Dwb_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dwc')))::geography)::numeric), 0) area_Dwc_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'Dwd')))::geography)::numeric), 0) area_Dwd_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'EF')))::geography)::numeric), 0) area_EF_m2,
		coalesce(round(st_area((st_intersection(r.geom, st_union(k.geom) filter(where k."class" = 'ET')))::geography)::numeric), 0) area_ET_m2
	from russia.region_boundary_land r
	left join world.koppen_geiger_climate_classify k
		on st_intersects(r.geom, k.geom)
			and k.time_interval = '1976-2000'
	group by r.name, r.geom
),
region_by_auto as(
	select
		c1.region_name "name",
		count(c2.id_gis) num_region_by_auto,
		array_to_string(array_agg(c2.city || ' (' || c2.region_name || ')'), ', ') list_region_by_auto
	from russia.city c1
	left join russia.city c2
		on c1.id_gis <> c2.id_gis 
			and c2.region_capital is true
			and st_dwithin(st_centroid(c1.geom)::geography, st_centroid(c2.geom)::geography, 3 * 80000)
	where c1.region_capital is true
	group by c1.region_name 
),
region_by_train as(
	select
		c1.region_name "name",
		count(c2.id_gis) num_region_by_train,
		array_to_string(array_agg(c2.city || ' (' || c2.region_name || ')'), ', ') list_region_by_train
	from (select distinct on(c.id_gis) c.* from russia.city c join russia.rzd_railway_station s using(id_gis) where c.region_capital is true) c1
	join (select distinct on(c.id_gis) c.* from russia.city c join russia.rzd_railway_station s using(id_gis) where c.region_capital is true) c2
		on c1.id_gis <> c2.id_gis 
			and st_dwithin(st_centroid(c1.geom)::geography, st_centroid(c2.geom)::geography, 3 * 50000)
	where c1.city not in ('Брянск', 'Владикавказ', 'Казань', 'Краснодар', 'Нальчик', 'Рязань', 'Тула', 'Ставрополь', 'Томск', 'Чебоксары')
		and not(c1.city = 'Воронеж' and c2.city = 'Липецк')
		and not(c2.city = 'Воронеж' and c1.city = 'Липецк')	
	group by c1.region_name 
),
airport as (
	select
		r.name,
		count(a.*) total_airport	
	from russia.region_boundary_land r
	join world.airport_icao a
		on st_intersects(a.geom, r.geom)
	group by r.name
),
station as (
	select
		r.name,
		count(rs.*) total_railway_station	
	from russia.region_boundary_land r
	join russia.rzd_railway_station rs
		on st_intersects(rs.geom, r.geom)
	group by r.name
)
select distinct on(r.name)
	(row_number() over())::int id,
	r.name "Субъект РФ",
	round(st_area(r.geom::geography)::numeric) "Площадь, м2",
	coalesce(u.urban_area_m2, 0)  "Площ. урбан. терр., м2",
	coalesce(o.total_okn, 0)  "Всего ОКН, шт.",
	coalesce(h.historic_area_m2, 0)  "Площ. истор.-смеш. застр., м2",
	coalesce(oo.oopt_area_m2, 0)  "Площ. ООПТ, м2",
	coalesce(c.area_BSk_m2, 0) "Площ. в клим. зоне BSk, м2",
	coalesce(c.area_Cfa_m2, 0) "Площ. в клим. зоне Cfa, м2",
	coalesce(c.area_Cfb_m2, 0) "Площ. в клим. зоне Cfb, м2",
	coalesce(c.area_Csa_m2, 0) "Площ. в клим. зоне Csa, м2",
	coalesce(c.area_Dfa_m2, 0) "Площ. в клим. зоне Dfa, м2",
	coalesce(c.area_Dfb_m2, 0) "Площ. в клим. зоне Dfb, м2",
	coalesce(c.area_Dfc_m2, 0) "Площ. в клим. зоне Dfc, м2",
	coalesce(c.area_Dfd_m2, 0) "Площ. в клим. зоне Dfd, м2",
	coalesce(c.area_Dsc_m2, 0) "Площ. в клим. зоне Dsc, м2",
	coalesce(c.area_Dsd_m2, 0) "Площ. в клим. зоне Dsd, м2",
	coalesce(c.area_Dwa_m2, 0) "Площ. в клим. зоне Dwa, м2",
	coalesce(c.area_Dwb_m2, 0) "Площ. в клим. зоне Dwb, м2",
	coalesce(c.area_Dwc_m2, 0) "Площ. в клим. зоне Dwc, м2",
	coalesce(c.area_Dwd_m2, 0) "Площ. в клим. зоне Dwd, м2",
	coalesce(c.area_EF_m2, 0) "Площ. в клим. зоне EF, м2",
	coalesce(c.area_ET_m2, 0) "Площ. в клим. зоне ET, м2",
	coalesce(ra.num_region_by_auto, 0)  "Кол-во 3 ч. авт. дост.",
	coalesce(ra.list_region_by_auto, '')  "Список 3 ч. авт. дост.",
	coalesce(rt.num_region_by_train, 0)  "Кол-во 3 ч. жд. дост.",
	coalesce(rt.list_region_by_train, '')  "Список 3 ч. жд. дост.",
	coalesce(a.total_airport, 0)  "Всего аэропорт., шт.",
	coalesce(s.total_railway_station, 0)  "Всего жд. станц., шт."
from russia.region_boundary_land r
left join urban_area u using(name)
left join okn_count o using(name)
left join oopt oo using(name)
left join airport a using(name)
left join station s using(name)
left join historic h using(name)
left join climate c using(name)
left join region_by_auto ra using(name)
left join region_by_train rt using(name)
order by r.name;



/* Списки всех организаций для городов России (магазины, кафе, рестораны) */
select 
	b.id_gis,
	b.city "Город",
	b.region_name "Субъект РФ",
	p.rubrics "Категория",
	p.name "Название",
	count(*) "Число"
from russia.city b
left join (select distinct on(company_id) id_gis, rubrics, subrubrics, name from index2019.data_poi) p -- с фильтрацией по company_id, чтобы избежать дублирования
	on p.id_gis = b.id_gis 
		and (
			p.rubrics in ('Кафе','Ресторан', 'Быстрое питание')
				or p.rubrics like '%агазин%'
				or p.subrubrics = 'Продукты питания'
		)
where b.id_gis in (777,778)
group by b.id_gis, b.city, b.region_name, p.rubrics, p.name
order by id_gis, count(*) desc;




/* Список кадастровых кварталов по веломаршруту Москва - Санкт-Петербург */
drop table if exists buffer;
create temp table buffer as select 	st_buffer(geom::geography, 50)::geometry(polygon, 4326) geom from tmp.tmp_mos_spb_veloroute2;
create index on buffer using gist(geom);

select
	p.cad_region || ':' || p.cad_district || ':' || p.cad_quater "№ кадастрового квартала"
from buffer r
left join cadastr2016.parcel p
	on st_intersects(r.geom, p.geom)
group by p.cad_region, p.cad_district, p.cad_quater
order by p.cad_region, p.cad_district, p.cad_quater;


/* Список муниципальных образований с иерархией вхождения по веломаршруту Москва - Санкт-Петербург */
with r0 as (
	select
		b.*
	from (select st_union(geom) geom from tmp.tmp_route) r
	left join osm.admin_ru b
		on st_intersects(r.geom, b.geom)
			and b.admin_level = 4
),
r1 as (
	select
		b.*
	from (select st_union(geom) geom from tmp.tmp_route) r
	left join osm.admin_ru b
		on st_intersects(r.geom, b.geom)
			and b.admin_level in (5, 6)
),
r2 as (
	select
		b.*
	from (select st_union(geom) geom from tmp.tmp_route) r
	left join osm.admin_ru b
		on st_intersects(r.geom, b.geom)
			and b.admin_level = 8
),
r_a as (
	select
		r0.name subject,
		r1.name raion,
		r1.geom
	from r0
	left join r1
		on st_area(st_intersection(r0.geom, r1.geom)::geography) >= st_area(r1.geom::geography) * 0.9
),
r_b as (
	select
		r_a.subject,
		r_a.raion,
		r2.name mo
	from r_a
	left join r2
		on st_area(st_intersection(r_a.geom, r2.geom)::geography) >= st_area(r2.geom::geography) * 0.9
)
select
	subject "Субъект РФ",
	raion "Муниц. район/Городской округ",
	mo "Муниц. образов./Городской район"
from r_b
order by subject, raion, mo;




/* Площадь территории исторической застройки */
select
	c.id_gis,
	c.city "Город",
	c.region_name "Субъект РФ",
	coalesce(sum(q.area_ha), 0) "Площадь истр. смеш. среды, га"
from russia.city c
left join russia.city_quater_type q 
	on c.id_gis = q.id_gis 
		and q.quater_class = 'Историческая смешанная городская среда'
group by c.id_gis, c.city, c.region_name
order by "Площадь истр. смеш. среды, га" desc;



/* Минимальные - Максимальные плотности населения для городов */
with density as (
	select 
		g.id,
		g.id_gis,
		z.pop
	from index2019.stat_zoning z
	left join index2019.data_hexgrid g 
		on g.id =z.id
	where z.id_gis IN (
		985,901,1021,1050,1067,991,1064,1034,1016,
		982,1078,1054,1062,1031,1065,1030,1046,1037,
		998,989,1083,1075,1066,1052,1048,1024,1012,
		1007,1000,1039,1044,999,990,1055,1023,1070,
		1069,1018,597,994,1019
	)
		and z.pop > 0
)
select 
	id_gis,
	min(pop) min_pop_density,
	max(pop) max_pop_density,
	avg(pop) avg_pop_density
from density 
group by id_gis
order by id_gis;






/* Статистика по населению и удалённости от ОКН для населённых пунктов следующих Субъектов: */
/* Тульская область, Ярославская область, Калужская область, Ивановская область, Костромская область,
	Московская область, Рязанская область, Владимирская область, Тверская область */

/* Собираем матрёшку административных границ */
/* Извлекаем Субъекты */
drop table if exists regions;
create temp table regions as
select * from osm.admin_ru
where admin_level = 4
	and name in (
	    'Тульская область',
	    'Ярославская область',
	    'Калужская область',
	    'Ивановская область',
	    'Костромская область',
	    'Московская область',
	    'Рязанская область',
	    'Владимирская область',
	    'Тверская область'
	);
create index on regions(name);
create index on regions using gist(geom);

/* Ищем как населённые пункты вложены по регионам */
drop table if exists  place_osm_1;
create temp table place_osm_1 as 
select
	p.*,
	r.name region
from regions r
left join osm.places_ru p
	on st_intersects(r.geom, p.geom)
		and p.type in ('city', 'hamlet', 'isolated_dwelling', 'town', 'village');
create index on place_osm_1 using gist(geom);

--select count(*) from place_osm_1

/* Ищем как населённые пункты вложены по районам */
drop table if exists place_osm_2;
create temp table place_osm_2 as (
	select p.*, r.name raion
	from place_osm_1 p
	left join osm.admin_ru r
		on st_intersects(r.geom, p.geom)
			and r.admin_level = 6
);
create index on place_osm_2 using gist(geom);

--select count(*) from place_osm_2
--select * from place_osm1 limit 10

/* Ищем как населённые пункты вложены по поселениям */
drop table if exists place_osm;
create temp table place_osm as (
	select distinct on(p.id)
		p.id,
		p.name,
		p.type,
		p.population,
		p.geom,
		r.name poselenie,
		p.raion,
		p.region
	from place_osm_2 p
	left join osm.admin_ru r
		on st_intersects(r.geom, p.geom)
			and r.admin_level = 8
);
create index on place_osm(name);
create index on place_osm using gist(geom);
create index on place_osm using gist((geom::geography));

--select count(*) from place_osm

/* Ищем какие населённые пункты из третьего источника попадают в заданные регионы */
drop table if exists  place_stat;
create temp table place_stat as (
	select p.type, p.name, p.peoples population, p.geom
	from regions r
	join russia.place_all p
		on st_intersects(r.geom, p.geom)
			and p.level = 3
);
create index on place_stat(population);
create index on place_stat(name);
create index on place_stat(type);
create index on place_stat using gist(geom);
create index on place_stat using gist((geom::geography));

drop table if exists  okn;
create temp table okn as (
	select
		p.general_id,
		p.nativename "name",
		p.general__categorytype_value "type",
		p.geom
	from regions r
	join index2019.data_okn p
	 on st_intersects(r.geom, p.geom)
);
create index on okn(name);
create index on okn using gist(geom);
create index on okn using gist((geom::geography));

--select "type", count(*) from okn group by "type"
--select count(*) from okn

/* Сопоставляем точки населённых пунктов из OpenStreetMap и третьего источника */
drop table if exists  place;
create temp table place as
select
	p1.id,
	coalesce(p2.type, '') type_stat,
	p1.name,
--		p2.name name_stat,
	p1.type type_osm,
	case 
		when p2.population is null
			then p1.population
		else p2.population
	end population,
	case 
		when p2.population is not null
			then 'Росстат 2010'::text
		when p1.population is not null 
			then 'OpenStreetMap'::text
	end population_source,
	p1.geom,
	p1.poselenie,
	p1.raion,
	p1.region
from place_osm p1
left join lateral (
	select p2.*
	from place_stat p2
	where st_dwithin(p1.geom::geography, p2.geom::geography, 10000)
		and p1.name ilike p2.name
	order by p1.geom::geography <-> p2.geom::geography
	limit 1
) p2 on true;

--select * from place where population > 0
create index on place using gist(geom);
create index on place using gist((geom::geography));

--select count(*) from place

/* Проверяем расстояние от населённых пунктов до всех ОКН из реестра Минкульта в радиусе 100 км. */
drop table if exists  place_final;
create temp table place_final as 
select
	p.*,
	array_to_string(array_agg(o.name || ' (' || case when o.dist_km = 0 then '< 1'::text else o.dist_km::text end || ' км.)' order by dist_km), ', 
') okn_in_100km_radius
from place p
left join lateral (
	select
		o.name,
		o.general_id,
		o.type,
		round((st_distance(p.geom::geography, o.geom::geography) / 1000)::numeric) dist_km
	from okn o
	where st_dwithin(p.geom::geography, o.geom::geography, 100000)
	order by p.geom::geography <-> o.geom::geography
	limit 10
) o on true
group by
	p.id,
	p.type_stat,
	p.name,
	p.type_osm,
	p.population,
	p.population_source,
	p.geom,
	p.poselenie,
	p.raion,
	p.region
;

select
--	(row_number() over())::int id,
	type_stat "Тип н.п.",
	name "Название",
--	type_osm,
	population "Население, чел.",
	population_source "Насел., источник",
--	geom,
--	admin_id,
	poselenie "Поселение",
	raion "Район/Округ",
	region "Субъект РФ",
	okn_in_100km_radius "ОКН в 100 км. радиусе"
from place_final
where name is not null
order by region, raion, poselenie, population desc nulls last;
















/* Выборка населённых пунктов */
with p as (
select p.*, r.name name2
 from russia.osm_admin_boundary_region r
 left join "osm"."places_ru" p
  on st_intersects(r.geom, p.geom)
 	and p."type" in ('city', 'hamlet', 'isolated_dwelling', 'town', 'village')
 where r.id in (5,6,7,12,13,55,56,66,85)
)
select p.*, r2.name name3
 FROM osm.admin_ru r2
 left join p
  on st_intersects(r2.geom, p.geom)
 where r2.admin_level = 6
 	and (
		(p.name = 'Тверь' and p.name2 = 'Тверская область' and r2.name = 'городской округ Тверь') or
		(p.name = 'Ржев' and p.name2 = 'Тверская область' and r2.name = 'городской округ Ржев') or
		(p.name = 'Вышний Волочёк' and p.name2 = 'Тверская область' and r2.name = 'городской округ Вышний Волочёк') or
		(p.name = 'Торжок' and p.name2 = 'Тверская область' and r2.name = 'городской округ Торжок') or
		(p.name = 'Нелидово' and p.name2 = 'Тверская область' and r2.name = 'Нелидовский городской округ') or
		(p.name = 'Осташков' and p.name2 = 'Тверская область' and r2.name = 'Осташковский городской округ') or
		(p.name = 'Калязин' and p.name2 = 'Тверская область' and r2.name = 'Калязинский район') or
		(p.name = 'Торопец' and p.name2 = 'Тверская область' and r2.name = 'Торопецкий район') or
		(p.name = 'Старица' and p.name2 = 'Тверская область' and r2.name = 'Старицкий район') or
		(p.name = 'Городня' and p.name2 = 'Тверская область' and r2.name = 'Конаковский район') or
		(p.name = 'Берново' and p.name2 = 'Тверская область' and r2.name = 'Старицкий район') or
		(p.name = 'Светлица' and p.name2 = 'Тверская область' and r2.name = 'Осташковский городской округ') or
		(p.name = 'Василево' and p.name2 = 'Тверская область' and r2.name = 'Торжокский район') or
		(p.name = 'Волговерховье' and p.name2 = 'Тверская область' and r2.name = 'Осташковский городской округ') or
		(p.name = 'Калуга' and p.name2 = 'Калужская область' and r2.name = 'городской округ Калуга') or
		(p.name = 'Обнинск' and p.name2 = 'Калужская область' and r2.name = 'городской округ Обнинск') or
		(p.name = 'Малоярославец' and p.name2 = 'Калужская область' and r2.name = 'Малоярославецкий район') or
		(p.name = 'Козельск' and p.name2 = 'Калужская область' and r2.name = 'Козельский район') or
		(p.name = 'Боровск' and p.name2 = 'Калужская область' and r2.name = 'Боровский район') or
		(p.name = 'Таруса' and p.name2 = 'Калужская область' and r2.name = 'Тарусский район') or
		(p.name = 'Никола-Ленивец' and p.name2 = 'Калужская область' and r2.name = 'Дзержинский район') or
		(p.name = 'Климов Завод' and p.name2 = 'Калужская область' and r2.name = 'Юхновский район') or
		(p.name = 'Петрово' and p.name2 = 'Калужская область' and r2.name = 'Боровский район') or
		(p.name = 'Имени Льва Толстого' and p.name2 = 'Калужская область' and r2.name = 'Дзержинский район') or
		(p.name = 'Тула' and p.name2 = 'Тульская область' and r2.name = 'городской округ Тула') or
		(p.name = 'Алексин' and p.name2 = 'Тульская область' and r2.name = 'городской округ Алексин') or
		(p.name = 'Белёв' and p.name2 = 'Тульская область' and r2.name = 'Белёвский район') or
		(p.name = 'Одоев' and p.name2 = 'Тульская область' and r2.name = 'Одоевский район') or
		(p.name = 'Крапивна' and p.name2 = 'Тульская область' and r2.name = 'Щёкинский район') or
		(p.name = 'Монастырщино' and p.name2 = 'Тульская область' and r2.name = 'Кимовский район') or
		(p.name = 'Бяково' and p.name2 = 'Тульская область' and r2.name = 'Венёвский район') or
		(p.name = 'Гурьево' and p.name2 = 'Тульская область' and r2.name = 'Венёвский район') or
		(p.name = 'Страхово' and p.name2 = 'Тульская область' and r2.name = 'Заокский район') or
		(p.name = 'Ясная Поляна' and p.name2 = 'Тульская область' and r2.name = 'Щёкинский район') or
		(p.name = 'Рязань' and p.name2 = 'Рязанская область' and r2.name = 'городской округ Рязань') or
		(p.name = 'Касимов' and p.name2 = 'Рязанская область' and r2.name = 'городской округ Касимов') or
		(p.name = 'Спас-Клепики' and p.name2 = 'Рязанская область' and r2.name = 'Клепиковский район') or
		(p.name = 'Пощупово' and p.name2 = 'Рязанская область' and r2.name = 'Рыбновский район') or
		(p.name = 'Брыкин Бор' and p.name2 = 'Рязанская область' and r2.name = 'Спасский район') or
		(p.name = 'Выша' and p.name2 = 'Рязанская область' and r2.name = 'Шацкий район') or
		(p.name = 'Старая Рязань' and p.name2 = 'Рязанская область' and r2.name = 'Спасский район') or
		(p.name = 'Иваново' and p.name2 = 'Ивановская область' and r2.name = 'городской округ Иваново') or
		(p.name = 'Кинешма' and p.name2 = 'Ивановская область' and r2.name = 'городской округ Кинешма') or
		(p.name = 'Шуя' and p.name2 = 'Ивановская область' and r2.name = 'городской округ Шуя') or
		(p.name = 'Юрьевец' and p.name2 = 'Ивановская область' and r2.name = 'Юрьевецкий район') or
		(p.name = 'Палех' and p.name2 = 'Ивановская область' and r2.name = 'Палехский район') or
		(p.name = 'Плёс' and p.name2 = 'Ивановская область' and r2.name = 'Приволжский район') or
		(p.name = 'Решма' and p.name2 = 'Ивановская область' and r2.name = 'Кинешемский район') or
		(p.name = 'Худынино' and p.name2 = 'Ивановская область' and r2.name = 'Ивановский район') or
		(p.name = 'Уводь' and p.name2 = 'Ивановская область' and r2.name = 'Ивановский район') or
		(p.name = 'Тимирязево' and p.name2 = 'Ивановская область' and r2.name = 'Лухский район') or
		(p.name = 'Владимир' and p.name2 = 'Владимирская область' and r2.name = 'городской округ Владимир') or
		(p.name = 'Муром' and p.name2 = 'Владимирская область' and r2.name = 'городской округ Муром') or
		(p.name = 'Гусь-Хрустальный' and p.name2 = 'Владимирская область' and r2.name = 'городской округ Гусь-Хрустальный') or
		(p.name = 'Юрьев-Польский' and p.name2 = 'Владимирская область' and r2.name = 'Юрьев-Польский район') or
		(p.name = 'Гороховец' and p.name2 = 'Владимирская область' and r2.name = 'Гороховецкий район') or
		(p.name = 'Суздаль' and p.name2 = 'Владимирская область' and r2.name = 'Суздальский район') or
		(p.name = 'Боголюбово' and p.name2 = 'Владимирская область' and r2.name = 'Суздальский район') or
		(p.name = 'Кидекша' and p.name2 = 'Владимирская область' and r2.name = 'Суздальский район') or
		(p.name = 'Кострома' and p.name2 = 'Костромская область' and r2.name = 'городской округ Кострома') or
		(p.name = 'Буй' and p.name2 = 'Костромская область' and r2.name = 'городской округ Буй') or
		(p.name = 'Нерехта' and p.name2 = 'Костромская область' and r2.name = 'Нерехтский район') or
		(p.name = 'Галич' and p.name2 = 'Костромская область' and r2.name = 'городской округ Галич') or
		(p.name = 'Красное-на-Волге' and p.name2 = 'Костромская область' and r2.name = 'Красносельский район') or
		(p.name = 'Макарьев' and p.name2 = 'Костромская область' and r2.name = 'Макарьевский район') or
		(p.name = 'Солигалич' and p.name2 = 'Костромская область' and r2.name = 'Солигаличский район') or
		(p.name = 'Чухлома' and p.name2 = 'Костромская область' and r2.name = 'Чухломский район') or
		(p.name = 'Судиславль' and p.name2 = 'Костромская область' and r2.name = 'Судиславский район') or
		(p.name = 'Сусанино' and p.name2 = 'Костромская область' and r2.name = 'Сусанинский район') or
		(p.name = 'Кологрив' and p.name2 = 'Костромская область' and r2.name = 'Кологривский район') or
		(p.name = 'Щелыково' and p.name2 = 'Костромская область' and r2.name = 'Островский район') or
		(p.name = 'Троица' and p.name2 = 'Костромская область' and r2.name = 'Нерехтский район') or
		(p.name = 'Сумароково' and p.name2 = 'Костромская область' and r2.name = 'Сусанинский район') or
		(p.name = 'Ярославль' and p.name2 = 'Ярославская область' and r2.name = 'городской округ Ярославль') or
		(p.name = 'Рыбинск' and p.name2 = 'Ярославская область' and r2.name = 'городской округ Рыбинск') or
		(p.name = 'Тутаев' and p.name2 = 'Ярославская область' and r2.name = 'Тутаевский район') or
		(p.name = 'Переславль-Залесский' and p.name2 = 'Ярославская область' and r2.name = 'городской округ Переславль-Залесский') or
		(p.name = 'Углич' and p.name2 = 'Ярославская область' and r2.name = 'Угличский район') or
		(p.name = 'Ростов' and p.name2 = 'Ярославская область' and r2.name = 'Ростовский район') or
		(p.name = 'Мышкин' and p.name2 = 'Ярославская область' and r2.name = 'Мышкинский район') or
		(p.name = 'Борисоглебский' and p.name2 = 'Ярославская область' and r2.name = 'Борисоглебский район') or
		(p.name = 'Карабиха' and p.name2 = 'Ярославская область' and r2.name = 'Ярославский район') or
		(p.name = 'Подольск' and p.name2 = 'Московская область' and r2.name = 'городской округ Подольск') or
		(p.name = 'Коломна' and p.name2 = 'Московская область' and r2.name = 'Коломенский городской округ') or
		(p.name = 'Серпухов' and p.name2 = 'Московская область' and r2.name = 'городской округ Серпухов') or
		(p.name = 'Орехово-Зуево' and p.name2 = 'Московская область' and r2.name = 'Орехово-Зуевский городской округ') or
		(p.name = 'Ногинск' and p.name2 = 'Московская область' and r2.name = 'Богородский городской округ') or
		(p.name = 'Сергиев Посад' and p.name2 = 'Московская область' and r2.name = 'Сергиево-Посадский городской округ') or
		(p.name = 'Клин' and p.name2 = 'Московская область' and r2.name = 'городской округ Клин') or
		(p.name = 'Егорьевск' and p.name2 = 'Московская область' and r2.name = 'городской округ Егорьевск') or
		(p.name = 'Чехов' and p.name2 = 'Московская область' and r2.name = 'городской округ Чехов') or
		(p.name = 'Дмитров' and p.name2 = 'Московская область' and r2.name = 'Дмитровский городской округ') or
		(p.name = 'Павловский Посад' and p.name2 = 'Московская область' and r2.name = 'городской округ Павловский Посад') or
		(p.name = 'Дзержинский' and p.name2 = 'Московская область' and r2.name = 'городской округ Дзержинский') or
		(p.name = 'Солнечногорск' and p.name2 = 'Московская область' and r2.name = 'городской округ Солнечногорск') or
		(p.name = 'Кашира' and p.name2 = 'Московская область' and r2.name = 'городской округ Кашира') or
		(p.name = 'Истра' and p.name2 = 'Московская область' and r2.name = 'городской округ Истра') or
		(p.name = 'Можайск' and p.name2 = 'Московская область' and r2.name = 'Можайский городской округ') or
		(p.name = 'Озёры' and p.name2 = 'Московская область' and r2.name = 'городской округ Озёры') or
		(p.name = 'Зарайск' and p.name2 = 'Московская область' and r2.name = 'городской округ Зарайск') or
		(p.name = 'Бронницы' and p.name2 = 'Московская область' and r2.name = 'городской округ Бронницы') or
		(p.name = 'Звенигород' and p.name2 = 'Московская область' and r2.name = 'Одинцовский городской округ') or
		(p.name = 'Монино' and p.name2 = 'Московская область' and r2.name = 'городской округ Щёлково') or
		(p.name = 'Кубинка' and p.name2 = 'Московская область' and r2.name = 'Одинцовский городской округ') or
		(p.name = 'Волоколамск' and p.name2 = 'Московская область' and r2.name = 'Волоколамский городской округ') or
		(p.name = 'Руза' and p.name2 = 'Московская область' and r2.name = 'Рузский городской округ') or
		(p.name = 'Талдом' and p.name2 = 'Московская область' and r2.name = 'Талдомский городской округ') or
		(p.name = 'Большие Вязёмы' and p.name2 = 'Московская область' and r2.name = 'Одинцовский городской округ') or
		(p.name = 'Верея' and p.name2 = 'Московская область' and r2.name = 'Наро-Фоминский городской округ') or
		(p.name = 'Горки Ленинские' and p.name2 = 'Московская область' and r2.name = 'Ленинский городской округ') or
		(p.name = 'Марфино' and p.name2 = 'Московская область' and r2.name = 'городской округ Мытищи') or
		(p.name = 'Архангельское' and p.name2 = 'Московская область' and r2.name = 'городской округ Красногорск') or
		(p.name = 'Данки' and p.name2 = 'Московская область' and r2.name = 'городской округ Серпухов') or
		(p.name = 'Мураново' and p.name2 = 'Московская область' and r2.name = 'Пушкинский городской округ') or
		(p.name = 'Мелихово' and p.name2 = 'Московская область' and r2.name = 'городской округ Чехов') or
		(p.name = 'Теряево' and p.name2 = 'Московская область' and r2.name = 'Волоколамский городской округ')
	)
;

















	