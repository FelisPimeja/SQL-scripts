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








/* Сведение рубрикатора Яндекса */
select
	distinct a.rubr,
	category,
	subrubrics,
	sdz,
	odz,
	greenz,
	leisurez,
	ipa,
	stretail,
	trade,
	food,
	services,
	find_center
from (select replace(unnest(string_to_array(replace(replace(cat_name, '""', '","'), '","', '";"'), ';')), '"', '') rubr from tmp.tmp_poi) a
left join (
	select distinct on(rubrics)
		rubrics,
		category,
		subrubrics,
		sdz,
		odz,
		greenz,
		leisurez,
		ipa,
		stretail,
		trade,
		food,
		services,
		find_center
	from index2019.data_poi
) r 
	on a.rubr = r.rubrics
order by rubr




-- Подсчёт площади и протяжённости промтерриторий у воды на 14 городов

-- Выбираем всю площадную воду в городах по списку 
drop table if exists water; 
create temp table water as 
	select w.*, c.id_gis, c.city
	from russia.city c
	left join osm.waterareas_ru w 
		on st_intersects(c.geom, w.geom)
--			and w.type = 'river'
	where c.city in (
		'Нижний Новгород',
		'Самара',
		'Казань',
		'Набережные Челны',
		'Уфа',
		'Ярославль',
		'Волгоград',
		'Пенза',
		'Тверь',
		'Тула',
		'Иваново',
		'Тольятти',
		'Пермь',
		'Астрахань'
	)
;
create index on water using gist(geom);
drop table if exists rivers; 

-- Выбираем нужные линейные реки в городах по списку
create temp table rivers as
	select w.*, c.id_gis, c.city
	from russia.city c
	left join osm.waterways_ru w 
		on st_dwithin(c.geom::geography, w.geom::geography, 500)
			and w.type = 'river'
			and w.name in ('Волга', 'Кама', 'Ока', 'Белая', 'Упа', 'Уводь', 'Сура')
	where c.city in (
		'Нижний Новгород',
		'Самара',
		'Казань',
		'Набережные Челны',
		'Уфа',
		'Ярославль',
		'Волгоград',
		'Пенза',
		'Тверь',
		'Тула',
		'Иваново',
		'Тольятти',
		'Пермь',
		'Астрахань'
	)	
;
create index on rivers using gist(geom);

-- Выбираем всю площадную воду пересекающуюся с линейными реками
drop table if exists waterareas; 
create temp table waterareas as
	select distinct on (w.geom)
		w.*
	from rivers r
	left join water w 
		on st_intersects(w.geom, r.geom)
;
create index on waterareas using gist(geom);
create index on waterareas using gist((geom::geography));

-- Выбираем все промтерритории в городах по списку 
drop table if exists industrial; 
create temp table industrial as 
	select l.*, c.id_gis
	from russia.city c
	left join osm.landusages_ru l 
		on st_intersects(c.geom, l.geom)
			and l.type in (
				'industrial',
				'railway',
				'military',
				'garages',
				'plant'
			)		
	where c.city in (
		'Нижний Новгород',
		'Самара',
		'Казань',
		'Набережные Челны',
		'Уфа',
		'Ярославль',
		'Волгоград',
		'Пенза',
		'Тверь',
		'Тула',
		'Иваново',
		'Тольятти',
		'Пермь',
		'Астрахань'
	)
;
create index on industrial using gist(geom);
create index on industrial using gist((geom::geography));

-- Выбираем промтерритории в радиусе 25 м от воды
drop table if exists w_industrial; 
create temp table w_industrial as 
	select i.*, w.city
	from waterareas w
	left join industrial i
		on st_dwithin(w.geom::geography, i.geom::geography, 25)
	order by city;
create index on w_industrial using gist(geom);
create index on w_industrial using gist((geom::geography));

drop table if exists tmp.shore_industrial; 
create table tmp.shore_industrial as 

-- Считаем статистику по прому (суммарная площадь, + протяжённость береговой линии через пересечение буфера от прома и контура площадной воды) 
with dis_w as (
	select id_gis, ST_Boundary(st_union(geom)) geom, st_union(geom) u_geom 
	from waterareas
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
len as (
	select
		id_gis,
		round((st_length(st_intersection(w.geom, i.geom)::geography) / 1000)::numeric, 2) sum_ind_len_km,
		sum_industrial_area_ha,
		st_multi(w.u_geom)::geometry(multipolygon, 4326) water_geom,
		st_multi(i.i_geom)::geometry(multipolygon, 4326) ind_geom,
		st_intersection(w.geom, i.geom) inter
	from dis_w w 
	join buf_ind i using(id_gis)
)
select
	c.city, l.*
from russia.city c 
join len l using(id_gis)
order by c.city;






























	