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




/* Статистика по вхождению объектов всех рубрик в границы городов */
create table trash.city_all_rubrics_stat as 
select
    b.id_gis,
    b.city,
    b.region,
    case when (count(p.*) filter(where p.category_new ilike '%Спортивный магазин%') ) > 0 then 1::smallint else 0::smallint end "Спортивный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Оптовый магазин%') ) > 0 then 1::smallint else 0::smallint end "Оптовый магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин аквариумов%') ) > 0 then 1::smallint else 0::smallint end "Магазин аквариумов",
    case when (count(p.*) filter(where p.category_new ilike '%Офис интернет-магазина%') ) > 0 then 1::smallint else 0::smallint end "Офис интернет-магазина",
    case when (count(p.*) filter(where p.category_new ilike '%Ювелирные изделия оптом%') ) > 0 then 1::smallint else 0::smallint end "Ювелирные изделия оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для животных оптом%') ) > 0 then 1::smallint else 0::smallint end "Товары для животных оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Табачная продукция оптом%') ) > 0 then 1::smallint else 0::smallint end "Табачная продукция оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Стройматериалы оптом%') ) > 0 then 1::smallint else 0::smallint end "Стройматериалы оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Посуда оптом%') ) > 0 then 1::smallint else 0::smallint end "Посуда оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Оптовая компания%') ) > 0 then 1::smallint else 0::smallint end "Оптовая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Одежда оптом%') ) > 0 then 1::smallint else 0::smallint end "Одежда оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Нижнее бельё оптом%') ) > 0 then 1::smallint else 0::smallint end "Нижнее бельё оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Компьютеры и комплектующие оптом%') ) > 0 then 1::smallint else 0::smallint end "Компьютеры и комплектующие оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Кожаные изделия оптом%') ) > 0 then 1::smallint else 0::smallint end "Кожаные изделия оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Канцтовары оптом%') ) > 0 then 1::smallint else 0::smallint end "Канцтовары оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Детские товары оптом%') ) > 0 then 1::smallint else 0::smallint end "Детские товары оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Галантерейные изделия оптом%') ) > 0 then 1::smallint else 0::smallint end "Галантерейные изделия оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Вина и винные напитки оптом%') ) > 0 then 1::smallint else 0::smallint end "Вина и винные напитки оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Бытовая техника оптом%') ) > 0 then 1::smallint else 0::smallint end "Бытовая техника оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Безалкогольные напитки оптом%') ) > 0 then 1::smallint else 0::smallint end "Безалкогольные напитки оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Алкогольная продукция оптом%') ) > 0 then 1::smallint else 0::smallint end "Алкогольная продукция оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильная парковка%') ) > 0 then 1::smallint else 0::smallint end "Автомобильная парковка",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильные грузоперевозки%') ) > 0 then 1::smallint else 0::smallint end "Автомобильные грузоперевозки",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильный завод%') ) > 0 then 1::smallint else 0::smallint end "Автомобильный завод",
    case when (count(p.*) filter(where p.category_new ilike '%Автотранспортное предприятие, автобаза%') ) > 0 then 1::smallint else 0::smallint end "Автотранспортное предприятие, автобаза",
    case when (count(p.*) filter(where p.category_new ilike '%Агентство недвижимости%') ) > 0 then 1::smallint else 0::smallint end "Агентство недвижимости",
    case when (count(p.*) filter(where p.category_new ilike '%Агентство по подписке%') ) > 0 then 1::smallint else 0::smallint end "Агентство по подписке",
    case when (count(p.*) filter(where p.category_new ilike '%Аграрная инфраструктура%') ) > 0 then 1::smallint else 0::smallint end "Аграрная инфраструктура",
    case when (count(p.*) filter(where p.category_new ilike '%Алмазная резка%') ) > 0 then 1::smallint else 0::smallint end "Алмазная резка",
    case when (count(p.*) filter(where p.category_new ilike '%Антенны%') ) > 0 then 1::smallint else 0::smallint end "Антенны",
    case when (count(p.*) filter(where p.category_new ilike '%Аренда зарядных устройств%') ) > 0 then 1::smallint else 0::smallint end "Аренда зарядных устройств",
    case when (count(p.*) filter(where p.category_new ilike '%Аренда и заказ самолётов, вертолётов%') ) > 0 then 1::smallint else 0::smallint end "Аренда и заказ самолётов, вертолётов",
    case when (count(p.*) filter(where p.category_new ilike '%Аренда строительной и спецтехники%') ) > 0 then 1::smallint else 0::smallint end "Аренда строительной и спецтехники",
    case when (count(p.*) filter(where p.category_new ilike '%Аренда теплоходов%') ) > 0 then 1::smallint else 0::smallint end "Аренда теплоходов",
    case when (count(p.*) filter(where p.category_new ilike '%Арт-объект%') ) > 0 then 1::smallint else 0::smallint end "Арт-объект",
    case when (count(p.*) filter(where p.category_new ilike '%Архитектурное бюро%') ) > 0 then 1::smallint else 0::smallint end "Архитектурное бюро",
    case when (count(p.*) filter(where p.category_new ilike '%Ассоциации и промышленные союзы%') ) > 0 then 1::smallint else 0::smallint end "Ассоциации и промышленные союзы",
    case when (count(p.*) filter(where p.category_new ilike '%Аутсорсинг%') ) > 0 then 1::smallint else 0::smallint end "Аутсорсинг",
    case when (count(p.*) filter(where p.category_new ilike '%Аэродром%') ) > 0 then 1::smallint else 0::smallint end "Аэродром",
    case when (count(p.*) filter(where p.category_new ilike '%Аэросъёмка%') ) > 0 then 1::smallint else 0::smallint end "Аэросъёмка",
    case when (count(p.*) filter(where p.category_new ilike '%АЭС, ГЭС, ТЭС%') ) > 0 then 1::smallint else 0::smallint end "АЭС, ГЭС, ТЭС",
    case when (count(p.*) filter(where p.category_new ilike '%Банковское оборудование%') ) > 0 then 1::smallint else 0::smallint end "Банковское оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Безопасность труда%') ) > 0 then 1::smallint else 0::smallint end "Безопасность труда",
    case when (count(p.*) filter(where p.category_new ilike '%Бизнес-инкубатор%') ) > 0 then 1::smallint else 0::smallint end "Бизнес-инкубатор",
    case when (count(p.*) filter(where p.category_new ilike '%Бизнес-центр%') ) > 0 then 1::smallint else 0::smallint end "Бизнес-центр",
    case when (count(p.*) filter(where p.category_new ilike '%Биотуалеты, туалетные кабины%') ) > 0 then 1::smallint else 0::smallint end "Биотуалеты, туалетные кабины",
    case when (count(p.*) filter(where p.category_new ilike '%Биржа%') ) > 0 then 1::smallint else 0::smallint end "Биржа",
    case when (count(p.*) filter(where p.category_new ilike '%Бронирование VIP-залов в аэропортах%') ) > 0 then 1::smallint else 0::smallint end "Бронирование VIP-залов в аэропортах",
    case when (count(p.*) filter(where p.category_new ilike '%Букмекерская контора%') ) > 0 then 1::smallint else 0::smallint end "Букмекерская контора",
    case when (count(p.*) filter(where p.category_new ilike '%Буровое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Буровое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Буровые работы%') ) > 0 then 1::smallint else 0::smallint end "Буровые работы",
    case when (count(p.*) filter(where p.category_new ilike '%Быстровозводимые здания%') ) > 0 then 1::smallint else 0::smallint end "Быстровозводимые здания",
    case when (count(p.*) filter(where p.category_new ilike '%Бытовые услуги%') ) > 0 then 1::smallint else 0::smallint end "Бытовые услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Бюро пропусков, пост охраны%') ) > 0 then 1::smallint else 0::smallint end "Бюро пропусков, пост охраны",
    case when (count(p.*) filter(where p.category_new ilike '%Вакуумное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Вакуумное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Вездеходы, гидроциклы, снегоходы%') ) > 0 then 1::smallint else 0::smallint end "Вездеходы, гидроциклы, снегоходы",
    case when (count(p.*) filter(where p.category_new ilike '%Велопарковка%') ) > 0 then 1::smallint else 0::smallint end "Велопарковка",
    case when (count(p.*) filter(where p.category_new ilike '%Вендинговое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Вендинговое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Верёвки, канаты, тросы%') ) > 0 then 1::smallint else 0::smallint end "Верёвки, канаты, тросы",
    case when (count(p.*) filter(where p.category_new ilike '%Вертолётная площадка%') ) > 0 then 1::smallint else 0::smallint end "Вертолётная площадка",
    case when (count(p.*) filter(where p.category_new ilike '%Весы и весоизмерительное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Весы и весоизмерительное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Взрывные работы%') ) > 0 then 1::smallint else 0::smallint end "Взрывные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Взрывчатые вещества%') ) > 0 then 1::smallint else 0::smallint end "Взрывчатые вещества",
    case when (count(p.*) filter(where p.category_new ilike '%Внешнеторговые и внешнеэкономические организации%') ) > 0 then 1::smallint else 0::smallint end "Внешнеторговые и внешнеэкономические организации",
    case when (count(p.*) filter(where p.category_new ilike '%Водоканал, водное хозяйство%') ) > 0 then 1::smallint else 0::smallint end "Водоканал, водное хозяйство",
    case when (count(p.*) filter(where p.category_new ilike '%Водоочистка, водоочистное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Водоочистка, водоочистное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Водопад%') ) > 0 then 1::smallint else 0::smallint end "Водопад",
    case when (count(p.*) filter(where p.category_new ilike '%Водоразборная колонка%') ) > 0 then 1::smallint else 0::smallint end "Водоразборная колонка",
    case when (count(p.*) filter(where p.category_new ilike '%Вольер животных%') ) > 0 then 1::smallint else 0::smallint end "Вольер животных",
    case when (count(p.*) filter(where p.category_new ilike '%Вулкан%') ) > 0 then 1::smallint else 0::smallint end "Вулкан",
    case when (count(p.*) filter(where p.category_new ilike '%Въездной знак%') ) > 0 then 1::smallint else 0::smallint end "Въездной знак",
    case when (count(p.*) filter(where p.category_new ilike '%Вывоз мусора и отходов%') ) > 0 then 1::smallint else 0::smallint end "Вывоз мусора и отходов",
    case when (count(p.*) filter(where p.category_new ilike '%Выращивание и продажа грибов%') ) > 0 then 1::smallint else 0::smallint end "Выращивание и продажа грибов",
    case when (count(p.*) filter(where p.category_new ilike '%Выставочные стенды%') ) > 0 then 1::smallint else 0::smallint end "Выставочные стенды",
    case when (count(p.*) filter(where p.category_new ilike '%Газовые баллоны%') ) > 0 then 1::smallint else 0::smallint end "Газовые баллоны",
    case when (count(p.*) filter(where p.category_new ilike '%Гаражный кооператив%') ) > 0 then 1::smallint else 0::smallint end "Гаражный кооператив",
    case when (count(p.*) filter(where p.category_new ilike '%Гейзер%') ) > 0 then 1::smallint else 0::smallint end "Гейзер",
    case when (count(p.*) filter(where p.category_new ilike '%Двери%') ) > 0 then 1::smallint else 0::smallint end "Двери",
    case when (count(p.*) filter(where p.category_new ilike '%Геодезическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Геодезическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Геология, геофизика%') ) > 0 then 1::smallint else 0::smallint end "Геология, геофизика",
    case when (count(p.*) filter(where p.category_new ilike '%Геологоразведочное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Геологоразведочное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Геофизическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Геофизическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Геральдика и генеалогия%') ) > 0 then 1::smallint else 0::smallint end "Геральдика и генеалогия",
    case when (count(p.*) filter(where p.category_new ilike '%Гидравлическое и пневматическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Гидравлическое и пневматическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Гидроабразивная резка%') ) > 0 then 1::smallint else 0::smallint end "Гидроабразивная резка",
    case when (count(p.*) filter(where p.category_new ilike '%Гидрометеорология%') ) > 0 then 1::smallint else 0::smallint end "Гидрометеорология",
    case when (count(p.*) filter(where p.category_new ilike '%Гипсовые изделия%') ) > 0 then 1::smallint else 0::smallint end "Гипсовые изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Гобелены%') ) > 0 then 1::smallint else 0::smallint end "Гобелены",
    case when (count(p.*) filter(where p.category_new ilike '%Горная вершина%') ) > 0 then 1::smallint else 0::smallint end "Горная вершина",
    case when (count(p.*) filter(where p.category_new ilike '%Горнодобывающее оборудование%') ) > 0 then 1::smallint else 0::smallint end "Горнодобывающее оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Горнолыжный комплекс%') ) > 0 then 1::smallint else 0::smallint end "Горнолыжный комплекс",
    case when (count(p.*) filter(where p.category_new ilike '%Городская телефонная сеть%') ) > 0 then 1::smallint else 0::smallint end "Городская телефонная сеть",
    case when (count(p.*) filter(where p.category_new ilike '%Городское благоустройство%') ) > 0 then 1::smallint else 0::smallint end "Городское благоустройство",
    case when (count(p.*) filter(where p.category_new ilike '%Горячая линия%') ) > 0 then 1::smallint else 0::smallint end "Горячая линия",
    case when (count(p.*) filter(where p.category_new ilike '%Гостиница для животных%') ) > 0 then 1::smallint else 0::smallint end "Гостиница для животных",
    case when (count(p.*) filter(where p.category_new ilike '%Гравёрные работы%') ) > 0 then 1::smallint else 0::smallint end "Гравёрные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Гражданская оборона%') ) > 0 then 1::smallint else 0::smallint end "Гражданская оборона",
    case when (count(p.*) filter(where p.category_new ilike '%Грили, мангалы%') ) > 0 then 1::smallint else 0::smallint end "Грили, мангалы",
    case when (count(p.*) filter(where p.category_new ilike '%Грузовые авиаперевозки%') ) > 0 then 1::smallint else 0::smallint end "Грузовые авиаперевозки",
    case when (count(p.*) filter(where p.category_new ilike '%Дата-центр%') ) > 0 then 1::smallint else 0::smallint end "Дата-центр",
    case when (count(p.*) filter(where p.category_new ilike '%Девелопмент недвижимости%') ) > 0 then 1::smallint else 0::smallint end "Девелопмент недвижимости",
    case when (count(p.*) filter(where p.category_new ilike '%Дезинфекция, дезинсекция, дератизация%') ) > 0 then 1::smallint else 0::smallint end "Дезинфекция, дезинсекция, дератизация",
    case when (count(p.*) filter(where p.category_new ilike '%Декоративный объект, доска почёта%') ) > 0 then 1::smallint else 0::smallint end "Декоративный объект, доска почёта",
    case when (count(p.*) filter(where p.category_new ilike '%Деловой туризм%') ) > 0 then 1::smallint else 0::smallint end "Деловой туризм",
    case when (count(p.*) filter(where p.category_new ilike '%Дельфинарий, океанариум%') ) > 0 then 1::smallint else 0::smallint end "Дельфинарий, океанариум",
    case when (count(p.*) filter(where p.category_new ilike '%Денежные переводы%') ) > 0 then 1::smallint else 0::smallint end "Денежные переводы",
    case when (count(p.*) filter(where p.category_new ilike '%Депозитарии и реестродержатели%') ) > 0 then 1::smallint else 0::smallint end "Депозитарии и реестродержатели",
    case when (count(p.*) filter(where p.category_new ilike '%Деревообрабатывающее оборудование%') ) > 0 then 1::smallint else 0::smallint end "Деревообрабатывающее оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Деревообрабатывающее предприятие%') ) > 0 then 1::smallint else 0::smallint end "Деревообрабатывающее предприятие",
    case when (count(p.*) filter(where p.category_new ilike '%Детская площадка%') ) > 0 then 1::smallint else 0::smallint end "Детская площадка",
    case when (count(p.*) filter(where p.category_new ilike '%Детский дом%') ) > 0 then 1::smallint else 0::smallint end "Детский дом",
    case when (count(p.*) filter(where p.category_new ilike '%Детский приют%') ) > 0 then 1::smallint else 0::smallint end "Детский приют",
    case when (count(p.*) filter(where p.category_new ilike '%Дизайн интерьеров%') ) > 0 then 1::smallint else 0::smallint end "Дизайн интерьеров",
    case when (count(p.*) filter(where p.category_new ilike '%Дилинговый центр%') ) > 0 then 1::smallint else 0::smallint end "Дилинговый центр",
    case when (count(p.*) filter(where p.category_new ilike '%Дисконтные системы и купонаторы%') ) > 0 then 1::smallint else 0::smallint end "Дисконтные системы и купонаторы",
    case when (count(p.*) filter(where p.category_new ilike '%Добыча природных ресурсов%') ) > 0 then 1::smallint else 0::smallint end "Добыча природных ресурсов",
    case when (count(p.*) filter(where p.category_new ilike '%Домашний персонал%') ) > 0 then 1::smallint else 0::smallint end "Домашний персонал",
    case when (count(p.*) filter(where p.category_new ilike '%Дом моды%') ) > 0 then 1::smallint else 0::smallint end "Дом моды",
    case when (count(p.*) filter(where p.category_new ilike '%Домофоны%') ) > 0 then 1::smallint else 0::smallint end "Домофоны",
    case when (count(p.*) filter(where p.category_new ilike '%Дом ребёнка%') ) > 0 then 1::smallint else 0::smallint end "Дом ребёнка",
    case when (count(p.*) filter(where p.category_new ilike '%Дорожно-строительная техника%') ) > 0 then 1::smallint else 0::smallint end "Дорожно-строительная техника",
    case when (count(p.*) filter(where p.category_new ilike '%Дорожные материалы%') ) > 0 then 1::smallint else 0::smallint end "Дорожные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Доставка воды%') ) > 0 then 1::smallint else 0::smallint end "Доставка воды",
    case when (count(p.*) filter(where p.category_new ilike '%Доставка еды и обедов%') ) > 0 then 1::smallint else 0::smallint end "Доставка еды и обедов",
    case when (count(p.*) filter(where p.category_new ilike '%Достопримечательность%') ) > 0 then 1::smallint else 0::smallint end "Достопримечательность",
    case when (count(p.*) filter(where p.category_new ilike '%Душ%') ) > 0 then 1::smallint else 0::smallint end "Душ",
    case when (count(p.*) filter(where p.category_new ilike '%Ёлки и ёлочные игрушки%') ) > 0 then 1::smallint else 0::smallint end "Ёлки и ёлочные игрушки",
    case when (count(p.*) filter(where p.category_new ilike '%Ёлочный базар%') ) > 0 then 1::smallint else 0::smallint end "Ёлочный базар",
    case when (count(p.*) filter(where p.category_new ilike '%Ёмкостное оборудование, резервуары%') ) > 0 then 1::smallint else 0::smallint end "Ёмкостное оборудование, резервуары",
    case when (count(p.*) filter(where p.category_new ilike '%Жалюзи и рулонные шторы%') ) > 0 then 1::smallint else 0::smallint end "Жалюзи и рулонные шторы",
    case when (count(p.*) filter(where p.category_new ilike '%Железнодорожная пассажирская компания%') ) > 0 then 1::smallint else 0::smallint end "Железнодорожная пассажирская компания",
    case when (count(p.*) filter(where p.category_new ilike '%Железнодорожная техника и оборудование%') ) > 0 then 1::smallint else 0::smallint end "Железнодорожная техника и оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Железнодорожные грузоперевозки%') ) > 0 then 1::smallint else 0::smallint end "Железнодорожные грузоперевозки",
    case when (count(p.*) filter(where p.category_new ilike '%Железнодорожные и авиабилеты%') ) > 0 then 1::smallint else 0::smallint end "Железнодорожные и авиабилеты",
    case when (count(p.*) filter(where p.category_new ilike '%Животноводческое хозяйство%') ) > 0 then 1::smallint else 0::smallint end "Животноводческое хозяйство",
    case when (count(p.*) filter(where p.category_new ilike '%Жилищный отдел%') ) > 0 then 1::smallint else 0::smallint end "Жилищный отдел",
    case when (count(p.*) filter(where p.category_new ilike '%Жилой комплекс%') ) > 0 then 1::smallint else 0::smallint end "Жилой комплекс",
    case when (count(p.*) filter(where p.category_new ilike '%Жильё посуточно%') ) > 0 then 1::smallint else 0::smallint end "Жильё посуточно",
    case when (count(p.*) filter(where p.category_new ilike '%Замки и запорные устройства%') ) > 0 then 1::smallint else 0::smallint end "Замки и запорные устройства",
    case when (count(p.*) filter(where p.category_new ilike '%Заповедник%') ) > 0 then 1::smallint else 0::smallint end "Заповедник",
    case when (count(p.*) filter(where p.category_new ilike '%Кожевенное сырьё%') ) > 0 then 1::smallint else 0::smallint end "Кожевенное сырьё",
    case when (count(p.*) filter(where p.category_new ilike '%Земляные работы%') ) > 0 then 1::smallint else 0::smallint end "Земляные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Зерно и зерноотходы%') ) > 0 then 1::smallint else 0::smallint end "Зерно и зерноотходы",
    case when (count(p.*) filter(where p.category_new ilike '%Зимние развлечения%') ) > 0 then 1::smallint else 0::smallint end "Зимние развлечения",
    case when (count(p.*) filter(where p.category_new ilike '%Зимние сады, веранды, террасы%') ) > 0 then 1::smallint else 0::smallint end "Зимние сады, веранды, террасы",
    case when (count(p.*) filter(where p.category_new ilike '%Зоосалон, зоопарикмахерская%') ) > 0 then 1::smallint else 0::smallint end "Зоосалон, зоопарикмахерская",
    case when (count(p.*) filter(where p.category_new ilike '%Игорное и развлекательное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Игорное и развлекательное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление витражей%') ) > 0 then 1::smallint else 0::smallint end "Изготовление витражей",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление и монтаж зеркал%') ) > 0 then 1::smallint else 0::smallint end "Изготовление и монтаж зеркал",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление и оптовая продажа сувениров%') ) > 0 then 1::smallint else 0::smallint end "Изготовление и оптовая продажа сувениров",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление и ремонт музыкальных инструментов%') ) > 0 then 1::smallint else 0::smallint end "Изготовление и ремонт музыкальных инструментов",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление макетов%') ) > 0 then 1::smallint else 0::smallint end "Изготовление макетов",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление номерных знаков%') ) > 0 then 1::smallint else 0::smallint end "Изготовление номерных знаков",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление печатей и штампов%') ) > 0 then 1::smallint else 0::smallint end "Изготовление печатей и штампов",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление пластиковых карт%') ) > 0 then 1::smallint else 0::smallint end "Изготовление пластиковых карт",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление террариумов%') ) > 0 then 1::smallint else 0::smallint end "Изготовление террариумов",
    case when (count(p.*) filter(where p.category_new ilike '%Издательские услуги%') ) > 0 then 1::smallint else 0::smallint end "Издательские услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Изоляционные работы%') ) > 0 then 1::smallint else 0::smallint end "Изоляционные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Изыскательские работы%') ) > 0 then 1::smallint else 0::smallint end "Изыскательские работы",
    case when (count(p.*) filter(where p.category_new ilike '%Инвестиционная компания%') ) > 0 then 1::smallint else 0::smallint end "Инвестиционная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Инженерная инфраструктура%') ) > 0 then 1::smallint else 0::smallint end "Инженерная инфраструктура",
    case when (count(p.*) filter(where p.category_new ilike '%Инжиниринг%') ) > 0 then 1::smallint else 0::smallint end "Инжиниринг",
    case when (count(p.*) filter(where p.category_new ilike '%Инкассация%') ) > 0 then 1::smallint else 0::smallint end "Инкассация",
    case when (count(p.*) filter(where p.category_new ilike '%Инструментальная промышленность%') ) > 0 then 1::smallint else 0::smallint end "Инструментальная промышленность",
    case when (count(p.*) filter(where p.category_new ilike '%Интеллектуальные здания%') ) > 0 then 1::smallint else 0::smallint end "Интеллектуальные здания",
    case when (count(p.*) filter(where p.category_new ilike '%Интернет-провайдер%') ) > 0 then 1::smallint else 0::smallint end "Интернет-провайдер",
    case when (count(p.*) filter(where p.category_new ilike '%Информационная безопасность%') ) > 0 then 1::smallint else 0::smallint end "Информационная безопасность",
    case when (count(p.*) filter(where p.category_new ilike '%Информационная служба%') ) > 0 then 1::smallint else 0::smallint end "Информационная служба",
    case when (count(p.*) filter(where p.category_new ilike '%Информационное агентство%') ) > 0 then 1::smallint else 0::smallint end "Информационное агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Информационный интернет-сайт%') ) > 0 then 1::smallint else 0::smallint end "Информационный интернет-сайт",
    case when (count(p.*) filter(where p.category_new ilike '%Инфраструктура отдыха%') ) > 0 then 1::smallint else 0::smallint end "Инфраструктура отдыха",
    case when (count(p.*) filter(where p.category_new ilike '%Ипотечное агентство%') ) > 0 then 1::smallint else 0::smallint end "Ипотечное агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Кабель и провод%') ) > 0 then 1::smallint else 0::smallint end "Кабель и провод",
    case when (count(p.*) filter(where p.category_new ilike '%Кабельное телевидение%') ) > 0 then 1::smallint else 0::smallint end "Кабельное телевидение",
    case when (count(p.*) filter(where p.category_new ilike '%Кадастровые работы%') ) > 0 then 1::smallint else 0::smallint end "Кадастровые работы",
    case when (count(p.*) filter(where p.category_new ilike '%Кадровое агентство%') ) > 0 then 1::smallint else 0::smallint end "Кадровое агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Камера хранения%') ) > 0 then 1::smallint else 0::smallint end "Камера хранения",
    case when (count(p.*) filter(where p.category_new ilike '%Камины, печи%') ) > 0 then 1::smallint else 0::smallint end "Камины, печи",
    case when (count(p.*) filter(where p.category_new ilike '%Камнеобрабатывающее оборудование%') ) > 0 then 1::smallint else 0::smallint end "Камнеобрабатывающее оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Картографическое производство%') ) > 0 then 1::smallint else 0::smallint end "Картографическое производство",
    case when (count(p.*) filter(where p.category_new ilike '%Кассовые аппараты и расходные материалы%') ) > 0 then 1::smallint else 0::smallint end "Кассовые аппараты и расходные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Квартиры в новостройках%') ) > 0 then 1::smallint else 0::smallint end "Квартиры в новостройках",
    case when (count(p.*) filter(where p.category_new ilike '%Кинооборудование%') ) > 0 then 1::smallint else 0::smallint end "Кинооборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Кинопрокатная компания%') ) > 0 then 1::smallint else 0::smallint end "Кинопрокатная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Киностудия%') ) > 0 then 1::smallint else 0::smallint end "Киностудия",
    case when (count(p.*) filter(where p.category_new ilike '%Кладбище%') ) > 0 then 1::smallint else 0::smallint end "Кладбище",
    case when (count(p.*) filter(where p.category_new ilike '%Клининговое оборудование и инвентарь%') ) > 0 then 1::smallint else 0::smallint end "Клининговое оборудование и инвентарь",
    case when (count(p.*) filter(where p.category_new ilike '%Клининговые услуги%') ) > 0 then 1::smallint else 0::smallint end "Клининговые услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Клуб любителей животных%') ) > 0 then 1::smallint else 0::smallint end "Клуб любителей животных",
    case when (count(p.*) filter(where p.category_new ilike '%Ключ, ручей%') ) > 0 then 1::smallint else 0::smallint end "Ключ, ручей",
    case when (count(p.*) filter(where p.category_new ilike '%Коворкинг%') ) > 0 then 1::smallint else 0::smallint end "Коворкинг",
    case when (count(p.*) filter(where p.category_new ilike '%Коллекторское агентство%') ) > 0 then 1::smallint else 0::smallint end "Коллекторское агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Колл-центр%') ) > 0 then 1::smallint else 0::smallint end "Колл-центр",
    case when (count(p.*) filter(where p.category_new ilike '%Колодец%') ) > 0 then 1::smallint else 0::smallint end "Колодец",
    case when (count(p.*) filter(where p.category_new ilike '%Комбикорма и кормовые добавки%') ) > 0 then 1::smallint else 0::smallint end "Комбикорма и кормовые добавки",
    case when (count(p.*) filter(where p.category_new ilike '%Конная амуниция%') ) > 0 then 1::smallint else 0::smallint end "Конная амуниция",
    case when (count(p.*) filter(where p.category_new ilike '%Конструкторское бюро%') ) > 0 then 1::smallint else 0::smallint end "Конструкторское бюро",
    case when (count(p.*) filter(where p.category_new ilike '%Консьерж-сервис%') ) > 0 then 1::smallint else 0::smallint end "Консьерж-сервис",
    case when (count(p.*) filter(where p.category_new ilike '%Контейнерные перевозки%') ) > 0 then 1::smallint else 0::smallint end "Контейнерные перевозки",
    case when (count(p.*) filter(where p.category_new ilike '%Контейнеры%') ) > 0 then 1::smallint else 0::smallint end "Контейнеры",
    case when (count(p.*) filter(where p.category_new ilike '%Контрольно-измерительные приборы%') ) > 0 then 1::smallint else 0::smallint end "Контрольно-измерительные приборы",
    case when (count(p.*) filter(where p.category_new ilike '%Конференц-зал%') ) > 0 then 1::smallint else 0::smallint end "Конференц-зал",
    case when (count(p.*) filter(where p.category_new ilike '%Концертные и театральные агентства%') ) > 0 then 1::smallint else 0::smallint end "Концертные и театральные агентства",
    case when (count(p.*) filter(where p.category_new ilike '%Копировальный центр%') ) > 0 then 1::smallint else 0::smallint end "Копировальный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Космодром%') ) > 0 then 1::smallint else 0::smallint end "Космодром",
    case when (count(p.*) filter(where p.category_new ilike '%Котлы и котельное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Котлы и котельное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Коттеджный посёлок%') ) > 0 then 1::smallint else 0::smallint end "Коттеджный посёлок",
    case when (count(p.*) filter(where p.category_new ilike '%Кофемашины, кофейные автоматы%') ) > 0 then 1::smallint else 0::smallint end "Кофемашины, кофейные автоматы",
    case when (count(p.*) filter(where p.category_new ilike '%КПП%') ) > 0 then 1::smallint else 0::smallint end "КПП",
    case when (count(p.*) filter(where p.category_new ilike '%Красители для ткани%') ) > 0 then 1::smallint else 0::smallint end "Красители для ткани",
    case when (count(p.*) filter(where p.category_new ilike '%Криогенная техника%') ) > 0 then 1::smallint else 0::smallint end "Криогенная техника",
    case when (count(p.*) filter(where p.category_new ilike '%Кровельные работы%') ) > 0 then 1::smallint else 0::smallint end "Кровельные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Лазерная резка и гравировка%') ) > 0 then 1::smallint else 0::smallint end "Лазерная резка и гравировка",
    case when (count(p.*) filter(where p.category_new ilike '%Лесничество, лесхоз%') ) > 0 then 1::smallint else 0::smallint end "Лесничество, лесхоз",
    case when (count(p.*) filter(where p.category_new ilike '%Лесной массив%') ) > 0 then 1::smallint else 0::smallint end "Лесной массив",
    case when (count(p.*) filter(where p.category_new ilike '%Лесозаготовительная техника%') ) > 0 then 1::smallint else 0::smallint end "Лесозаготовительная техника",
    case when (count(p.*) filter(where p.category_new ilike '%Лесозаготовка, продажа леса%') ) > 0 then 1::smallint else 0::smallint end "Лесозаготовка, продажа леса",
    case when (count(p.*) filter(where p.category_new ilike '%Лесопарк%') ) > 0 then 1::smallint else 0::smallint end "Лесопарк",
    case when (count(p.*) filter(where p.category_new ilike '%Лесоустройство, лесовосстановление%') ) > 0 then 1::smallint else 0::smallint end "Лесоустройство, лесовосстановление",
    case when (count(p.*) filter(where p.category_new ilike '%Лизинговая компания%') ) > 0 then 1::smallint else 0::smallint end "Лизинговая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Литейное производство%') ) > 0 then 1::smallint else 0::smallint end "Литейное производство",
    case when (count(p.*) filter(where p.category_new ilike '%Логистическая компания%') ) > 0 then 1::smallint else 0::smallint end "Логистическая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Лотереи%') ) > 0 then 1::smallint else 0::smallint end "Лотереи",
    case when (count(p.*) filter(where p.category_new ilike '%Магистральные перевозки почты%') ) > 0 then 1::smallint else 0::smallint end "Магистральные перевозки почты",
    case when (count(p.*) filter(where p.category_new ilike '%Магниты и магнитные системы%') ) > 0 then 1::smallint else 0::smallint end "Магниты и магнитные системы",
    case when (count(p.*) filter(where p.category_new ilike '%Маркетинговые услуги%') ) > 0 then 1::smallint else 0::smallint end "Маркетинговые услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Маркировка товаров, штриховое кодирование%') ) > 0 then 1::smallint else 0::smallint end "Маркировка товаров, штриховое кодирование",
    case when (count(p.*) filter(where p.category_new ilike '%Материалы для полиграфии%') ) > 0 then 1::smallint else 0::smallint end "Материалы для полиграфии",
    case when (count(p.*) filter(where p.category_new ilike '%Материально-техническое снабжение%') ) > 0 then 1::smallint else 0::smallint end "Материально-техническое снабжение",
    case when (count(p.*) filter(where p.category_new ilike '%Машиностроительный завод%') ) > 0 then 1::smallint else 0::smallint end "Машиностроительный завод",
    case when (count(p.*) filter(where p.category_new ilike '%Мебельная фабрика%') ) > 0 then 1::smallint else 0::smallint end "Мебельная фабрика",
    case when (count(p.*) filter(where p.category_new ilike '%Медико-социальная экспертиза%') ) > 0 then 1::smallint else 0::smallint end "Медико-социальная экспертиза",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинская комиссия%') ) > 0 then 1::smallint else 0::smallint end "Медицинская комиссия",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинская помощь на дому%') ) > 0 then 1::smallint else 0::smallint end "Медицинская помощь на дому",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинские информационные услуги%') ) > 0 then 1::smallint else 0::smallint end "Медицинские информационные услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Международная организация%') ) > 0 then 1::smallint else 0::smallint end "Международная организация",
    case when (count(p.*) filter(where p.category_new ilike '%Мелиоративные работы%') ) > 0 then 1::smallint else 0::smallint end "Мелиоративные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Место для пикника%') ) > 0 then 1::smallint else 0::smallint end "Место для пикника",
    case when (count(p.*) filter(where p.category_new ilike '%Место событий, локальный ориентир%') ) > 0 then 1::smallint else 0::smallint end "Место событий, локальный ориентир",
    case when (count(p.*) filter(where p.category_new ilike '%Металлические заборы и ограждения%') ) > 0 then 1::smallint else 0::smallint end "Металлические заборы и ограждения",
    case when (count(p.*) filter(where p.category_new ilike '%Металлоискатели%') ) > 0 then 1::smallint else 0::smallint end "Металлоискатели",
    case when (count(p.*) filter(where p.category_new ilike '%Металлургическое предприятие%') ) > 0 then 1::smallint else 0::smallint end "Металлургическое предприятие",
    case when (count(p.*) filter(where p.category_new ilike '%Меховая компания%') ) > 0 then 1::smallint else 0::smallint end "Меховая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Микрофинансирование%') ) > 0 then 1::smallint else 0::smallint end "Микрофинансирование",
    case when (count(p.*) filter(where p.category_new ilike '%Могилы известных людей%') ) > 0 then 1::smallint else 0::smallint end "Могилы известных людей",
    case when (count(p.*) filter(where p.category_new ilike '%Молочная кухня%') ) > 0 then 1::smallint else 0::smallint end "Молочная кухня",
    case when (count(p.*) filter(where p.category_new ilike '%Монтаж и обслуживание систем водоснабжения и канализации%') ) > 0 then 1::smallint else 0::smallint end "Монтаж и обслуживание систем водоснабжения и канализации",
    case when (count(p.*) filter(where p.category_new ilike '%Монтажные работы%') ) > 0 then 1::smallint else 0::smallint end "Монтажные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Мусорная площадка%') ) > 0 then 1::smallint else 0::smallint end "Мусорная площадка",
    case when (count(p.*) filter(where p.category_new ilike '%Мухтарлык%') ) > 0 then 1::smallint else 0::smallint end "Мухтарлык",
    case when (count(p.*) filter(where p.category_new ilike '%Надувные конструкции и изделия%') ) > 0 then 1::smallint else 0::smallint end "Надувные конструкции и изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Налоговые консультанты%') ) > 0 then 1::smallint else 0::smallint end "Налоговые консультанты",
    case when (count(p.*) filter(where p.category_new ilike '%Нанесение покрытий%') ) > 0 then 1::smallint else 0::smallint end "Нанесение покрытий",
    case when (count(p.*) filter(where p.category_new ilike '%Научно-производственная организация%') ) > 0 then 1::smallint else 0::smallint end "Научно-производственная организация",
    case when (count(p.*) filter(where p.category_new ilike '%Небанковская кредитная организация%') ) > 0 then 1::smallint else 0::smallint end "Небанковская кредитная организация",
    case when (count(p.*) filter(where p.category_new ilike '%Негосударственный пенсионный фонд%') ) > 0 then 1::smallint else 0::smallint end "Негосударственный пенсионный фонд",
    case when (count(p.*) filter(where p.category_new ilike '%Непассажирская станция%') ) > 0 then 1::smallint else 0::smallint end "Непассажирская станция",
    case when (count(p.*) filter(where p.category_new ilike '%Нерудные материалы%') ) > 0 then 1::smallint else 0::smallint end "Нерудные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Нетканые материалы%') ) > 0 then 1::smallint else 0::smallint end "Нетканые материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Нефтегазовая компания%') ) > 0 then 1::smallint else 0::smallint end "Нефтегазовая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Нефтегазовое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Нефтегазовое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Озеро%') ) > 0 then 1::smallint else 0::smallint end "Озеро",
    case when (count(p.*) filter(where p.category_new ilike '%Нефтепродукты%') ) > 0 then 1::smallint else 0::smallint end "Нефтепродукты",
    case when (count(p.*) filter(where p.category_new ilike '%Новые технологии%') ) > 0 then 1::smallint else 0::smallint end "Новые технологии",
    case when (count(p.*) filter(where p.category_new ilike '%Обмен валюты%') ) > 0 then 1::smallint else 0::smallint end "Обмен валюты",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование для лёгкой промышленности%') ) > 0 then 1::smallint else 0::smallint end "Оборудование для лёгкой промышленности",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование для переработки пластмасс%') ) > 0 then 1::smallint else 0::smallint end "Оборудование для переработки пластмасс",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование для производства окон%') ) > 0 then 1::smallint else 0::smallint end "Оборудование для производства окон",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование для ресторанов%') ) > 0 then 1::smallint else 0::smallint end "Оборудование для ресторанов",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование для химчисток и прачечных%') ) > 0 then 1::smallint else 0::smallint end "Оборудование для химчисток и прачечных",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование и материалы для салонов красоты%') ) > 0 then 1::smallint else 0::smallint end "Оборудование и материалы для салонов красоты",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование и монтаж мусоропроводов%') ) > 0 then 1::smallint else 0::smallint end "Оборудование и монтаж мусоропроводов",
    case when (count(p.*) filter(where p.category_new ilike '%Оборудование и продукция для гостиниц%') ) > 0 then 1::smallint else 0::smallint end "Оборудование и продукция для гостиниц",
    case when (count(p.*) filter(where p.category_new ilike '%Обслуживание бассейнов%') ) > 0 then 1::smallint else 0::smallint end "Обслуживание бассейнов",
    case when (count(p.*) filter(where p.category_new ilike '%Обслуживание электросетей%') ) > 0 then 1::smallint else 0::smallint end "Обслуживание электросетей",
    case when (count(p.*) filter(where p.category_new ilike '%Обувная компания%') ) > 0 then 1::smallint else 0::smallint end "Обувная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Обувные материалы и фурнитура%') ) > 0 then 1::smallint else 0::smallint end "Обувные материалы и фурнитура",
    case when (count(p.*) filter(where p.category_new ilike '%Обучение за рубежом%') ) > 0 then 1::smallint else 0::smallint end "Обучение за рубежом",
    case when (count(p.*) filter(where p.category_new ilike '%Общежитие%') ) > 0 then 1::smallint else 0::smallint end "Общежитие",
    case when (count(p.*) filter(where p.category_new ilike '%Огнезащита%') ) > 0 then 1::smallint else 0::smallint end "Огнезащита",
    case when (count(p.*) filter(where p.category_new ilike '%Огнеупоры%') ) > 0 then 1::smallint else 0::smallint end "Огнеупоры",
    case when (count(p.*) filter(where p.category_new ilike '%Озеленение помещений%') ) > 0 then 1::smallint else 0::smallint end "Озеленение помещений",
    case when (count(p.*) filter(where p.category_new ilike '%Окрасочное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Окрасочное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Оператор каршеринга%') ) > 0 then 1::smallint else 0::smallint end "Оператор каршеринга",
    case when (count(p.*) filter(where p.category_new ilike '%Оператор сотовой связи%') ) > 0 then 1::smallint else 0::smallint end "Оператор сотовой связи",
    case when (count(p.*) filter(where p.category_new ilike '%Оператор спутниковой связи%') ) > 0 then 1::smallint else 0::smallint end "Оператор спутниковой связи",
    case when (count(p.*) filter(where p.category_new ilike '%Оптические приборы и оборудование%') ) > 0 then 1::smallint else 0::smallint end "Оптические приборы и оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Организация аукционов и тендеров%') ) > 0 then 1::smallint else 0::smallint end "Организация аукционов и тендеров",
    case when (count(p.*) filter(where p.category_new ilike '%Организация и обслуживание выставок%') ) > 0 then 1::smallint else 0::smallint end "Организация и обслуживание выставок",
    case when (count(p.*) filter(where p.category_new ilike '%Организация и проведение детских праздников%') ) > 0 then 1::smallint else 0::smallint end "Организация и проведение детских праздников",
    case when (count(p.*) filter(where p.category_new ilike '%Организация конференций и семинаров%') ) > 0 then 1::smallint else 0::smallint end "Организация конференций и семинаров",
    case when (count(p.*) filter(where p.category_new ilike '%Ортопедический салон%') ) > 0 then 1::smallint else 0::smallint end "Ортопедический салон",
    case when (count(p.*) filter(where p.category_new ilike '%Оружие и средства самозащиты%') ) > 0 then 1::smallint else 0::smallint end "Оружие и средства самозащиты",
    case when (count(p.*) filter(where p.category_new ilike '%Освидетельствование газовых баллонов%') ) > 0 then 1::smallint else 0::smallint end "Освидетельствование газовых баллонов",
    case when (count(p.*) filter(where p.category_new ilike '%Оснащение лабораторий%') ) > 0 then 1::smallint else 0::smallint end "Оснащение лабораторий",
    case when (count(p.*) filter(where p.category_new ilike '%Остановка беспилотника%') ) > 0 then 1::smallint else 0::smallint end "Остановка беспилотника",
    case when (count(p.*) filter(where p.category_new ilike '%Остановка маршрутного такси%') ) > 0 then 1::smallint else 0::smallint end "Остановка маршрутного такси",
    case when (count(p.*) filter(where p.category_new ilike '%Остекление балконов и лоджий%') ) > 0 then 1::smallint else 0::smallint end "Остекление балконов и лоджий",
    case when (count(p.*) filter(where p.category_new ilike '%Отопительное оборудование и системы%') ) > 0 then 1::smallint else 0::smallint end "Отопительное оборудование и системы",
    case when (count(p.*) filter(where p.category_new ilike '%Офис продаж%') ) > 0 then 1::smallint else 0::smallint end "Офис продаж",
    case when (count(p.*) filter(where p.category_new ilike '%Охранное предприятие%') ) > 0 then 1::smallint else 0::smallint end "Охранное предприятие",
    case when (count(p.*) filter(where p.category_new ilike '%Оцифровка%') ) > 0 then 1::smallint else 0::smallint end "Оцифровка",
    case when (count(p.*) filter(where p.category_new ilike '%Очистные сооружения и оборудование%') ) > 0 then 1::smallint else 0::smallint end "Очистные сооружения и оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Пагода%') ) > 0 then 1::smallint else 0::smallint end "Пагода",
    case when (count(p.*) filter(where p.category_new ilike '%Парк культуры и отдыха%') ) > 0 then 1::smallint else 0::smallint end "Парк культуры и отдыха",
    case when (count(p.*) filter(where p.category_new ilike '%Парковочная зона%') ) > 0 then 1::smallint else 0::smallint end "Парковочная зона",
    case when (count(p.*) filter(where p.category_new ilike '%Партнеры Яндекс.Такси%') ) > 0 then 1::smallint else 0::smallint end "Партнеры Яндекс.Такси",
    case when (count(p.*) filter(where p.category_new ilike '%Парфюмерно-косметическая компания%') ) > 0 then 1::smallint else 0::smallint end "Парфюмерно-косметическая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Перевал%') ) > 0 then 1::smallint else 0::smallint end "Перевал",
    case when (count(p.*) filter(where p.category_new ilike '%Перевозка грузов водным транспортом%') ) > 0 then 1::smallint else 0::smallint end "Перевозка грузов водным транспортом",
    case when (count(p.*) filter(where p.category_new ilike '%Перевозка негабаритных грузов%') ) > 0 then 1::smallint else 0::smallint end "Перевозка негабаритных грузов",
    case when (count(p.*) filter(where p.category_new ilike '%Перевозка нефтепродуктов%') ) > 0 then 1::smallint else 0::smallint end "Перевозка нефтепродуктов",
    case when (count(p.*) filter(where p.category_new ilike '%Переезды%') ) > 0 then 1::smallint else 0::smallint end "Переезды",
    case when (count(p.*) filter(where p.category_new ilike '%Переоборудование транспортных средств%') ) > 0 then 1::smallint else 0::smallint end "Переоборудование транспортных средств",
    case when (count(p.*) filter(where p.category_new ilike '%Печать на футболках%') ) > 0 then 1::smallint else 0::smallint end "Печать на футболках",
    case when (count(p.*) filter(where p.category_new ilike '%Пивоваренное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Пивоваренное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Пивоваренный завод%') ) > 0 then 1::smallint else 0::smallint end "Пивоваренный завод",
    case when (count(p.*) filter(where p.category_new ilike '%Пиломатериалы%') ) > 0 then 1::smallint else 0::smallint end "Пиломатериалы",
    case when (count(p.*) filter(where p.category_new ilike '%Пирсинг-салон%') ) > 0 then 1::smallint else 0::smallint end "Пирсинг-салон",
    case when (count(p.*) filter(where p.category_new ilike '%Питомник растений%') ) > 0 then 1::smallint else 0::smallint end "Питомник растений",
    case when (count(p.*) filter(where p.category_new ilike '%Питьевые галереи и источники%') ) > 0 then 1::smallint else 0::smallint end "Питьевые галереи и источники",
    case when (count(p.*) filter(where p.category_new ilike '%Пищевое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Пищевое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Пищевое сырьё%') ) > 0 then 1::smallint else 0::smallint end "Пищевое сырьё",
    case when (count(p.*) filter(where p.category_new ilike '%Плазменная резка металла%') ) > 0 then 1::smallint else 0::smallint end "Плазменная резка металла",
    case when (count(p.*) filter(where p.category_new ilike '%Пластмассовые и пластиковые изделия%') ) > 0 then 1::smallint else 0::smallint end "Пластмассовые и пластиковые изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Платные базы данных%') ) > 0 then 1::smallint else 0::smallint end "Платные базы данных",
    case when (count(p.*) filter(where p.category_new ilike '%Плёнки архитектурные, декоративные, защитные%') ) > 0 then 1::smallint else 0::smallint end "Плёнки архитектурные, декоративные, защитные",
    case when (count(p.*) filter(where p.category_new ilike '%Пломбираторы и пломбы безопасности%') ) > 0 then 1::smallint else 0::smallint end "Пломбираторы и пломбы безопасности",
    case when (count(p.*) filter(where p.category_new ilike '%Площадка для вождения%') ) > 0 then 1::smallint else 0::smallint end "Площадка для вождения",
    case when (count(p.*) filter(where p.category_new ilike '%Пограничный переход%') ) > 0 then 1::smallint else 0::smallint end "Пограничный переход",
    case when (count(p.*) filter(where p.category_new ilike '%Подводные работы%') ) > 0 then 1::smallint else 0::smallint end "Подводные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Подземные работы%') ) > 0 then 1::smallint else 0::smallint end "Подземные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Подшипники%') ) > 0 then 1::smallint else 0::smallint end "Подшипники",
    case when (count(p.*) filter(where p.category_new ilike '%Подъёмное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Подъёмное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Пожарное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Пожарное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Пожарные части и службы%') ) > 0 then 1::smallint else 0::smallint end "Пожарные части и службы",
    case when (count(p.*) filter(where p.category_new ilike '%Покрытия для площадок%') ) > 0 then 1::smallint else 0::smallint end "Покрытия для площадок",
    case when (count(p.*) filter(where p.category_new ilike '%Полигон ТБО%') ) > 0 then 1::smallint else 0::smallint end "Полигон ТБО",
    case when (count(p.*) filter(where p.category_new ilike '%Полиграфическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Полиграфическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Полимерные материалы%') ) > 0 then 1::smallint else 0::smallint end "Полимерные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Политическая партия%') ) > 0 then 1::smallint else 0::smallint end "Политическая партия",
    case when (count(p.*) filter(where p.category_new ilike '%Помощь в оформлении виз и загранпаспортов%') ) > 0 then 1::smallint else 0::smallint end "Помощь в оформлении виз и загранпаспортов",
    case when (count(p.*) filter(where p.category_new ilike '%Пост ДПС%') ) > 0 then 1::smallint else 0::smallint end "Пост ДПС",
    case when (count(p.*) filter(where p.category_new ilike '%Потребительская кооперация%') ) > 0 then 1::smallint else 0::smallint end "Потребительская кооперация",
    case when (count(p.*) filter(where p.category_new ilike '%Почтовые рассылки%') ) > 0 then 1::smallint else 0::smallint end "Почтовые рассылки",
    case when (count(p.*) filter(where p.category_new ilike '%Пошив и оптовая продажа головных уборов%') ) > 0 then 1::smallint else 0::smallint end "Пошив и оптовая продажа головных уборов",
    case when (count(p.*) filter(where p.category_new ilike '%Предприятие связи%') ) > 0 then 1::smallint else 0::smallint end "Предприятие связи",
    case when (count(p.*) filter(where p.category_new ilike '%Придорожная зона отдыха%') ) > 0 then 1::smallint else 0::smallint end "Придорожная зона отдыха",
    case when (count(p.*) filter(where p.category_new ilike '%Приём вторсырья%') ) > 0 then 1::smallint else 0::smallint end "Приём вторсырья",
    case when (count(p.*) filter(where p.category_new ilike '%Приём металлолома%') ) > 0 then 1::smallint else 0::smallint end "Приём металлолома",
    case when (count(p.*) filter(where p.category_new ilike '%Природа%') ) > 0 then 1::smallint else 0::smallint end "Природа",
    case when (count(p.*) filter(where p.category_new ilike '%Пристань%') ) > 0 then 1::smallint else 0::smallint end "Пристань",
    case when (count(p.*) filter(where p.category_new ilike '%Проверка на полиграфе%') ) > 0 then 1::smallint else 0::smallint end "Проверка на полиграфе",
    case when (count(p.*) filter(where p.category_new ilike '%Программное обеспечение%') ) > 0 then 1::smallint else 0::smallint end "Программное обеспечение",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа бассейнов и оборудования%') ) > 0 then 1::smallint else 0::smallint end "Продажа бассейнов и оборудования",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа готового бизнеса и франшиз%') ) > 0 then 1::smallint else 0::smallint end "Продажа готового бизнеса и франшиз",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа живых бабочек%') ) > 0 then 1::smallint else 0::smallint end "Продажа живых бабочек",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа земельных участков%') ) > 0 then 1::smallint else 0::smallint end "Продажа земельных участков",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа и аренда коммерческой недвижимости%') ) > 0 then 1::smallint else 0::smallint end "Продажа и аренда коммерческой недвижимости",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа и обслуживание лифтов%') ) > 0 then 1::smallint else 0::smallint end "Продажа и обслуживание лифтов",
    case when (count(p.*) filter(where p.category_new ilike '%Продажа и ремонт автобусов%') ) > 0 then 1::smallint else 0::smallint end "Продажа и ремонт автобусов",
    case when (count(p.*) filter(where p.category_new ilike '%Продюсерский центр%') ) > 0 then 1::smallint else 0::smallint end "Продюсерский центр",
    case when (count(p.*) filter(where p.category_new ilike '%Проектная организация%') ) > 0 then 1::smallint else 0::smallint end "Проектная организация",
    case when (count(p.*) filter(where p.category_new ilike '%Проекторы и мультимедийное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Проекторы и мультимедийное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Производственное предприятие%') ) > 0 then 1::smallint else 0::smallint end "Производственное предприятие",
    case when (count(p.*) filter(where p.category_new ilike '%Производство и оптовая продажа часов%') ) > 0 then 1::smallint else 0::smallint end "Производство и оптовая продажа часов",
    case when (count(p.*) filter(where p.category_new ilike '%Производство и продажа аттракционов%') ) > 0 then 1::smallint else 0::smallint end "Производство и продажа аттракционов",
    case when (count(p.*) filter(where p.category_new ilike '%Производство и продажа бумаги%') ) > 0 then 1::smallint else 0::smallint end "Производство и продажа бумаги",
    case when (count(p.*) filter(where p.category_new ilike '%Производство продуктов питания%') ) > 0 then 1::smallint else 0::smallint end "Производство продуктов питания",
    case when (count(p.*) filter(where p.category_new ilike '%Производство чулочно-носочной продукции%') ) > 0 then 1::smallint else 0::smallint end "Производство чулочно-носочной продукции",
    case when (count(p.*) filter(where p.category_new ilike '%Прокладка кабеля%') ) > 0 then 1::smallint else 0::smallint end "Прокладка кабеля",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленная инфраструктура%') ) > 0 then 1::smallint else 0::smallint end "Промышленная инфраструктура",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленная очистка сооружений и оборудования%') ) > 0 then 1::smallint else 0::smallint end "Промышленная очистка сооружений и оборудования",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленная химия%') ) > 0 then 1::smallint else 0::smallint end "Промышленная химия",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленное строительство%') ) > 0 then 1::smallint else 0::smallint end "Промышленное строительство",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленное холодильное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Промышленное холодильное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленные печи%') ) > 0 then 1::smallint else 0::smallint end "Промышленные печи",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленный альпинизм%') ) > 0 then 1::smallint else 0::smallint end "Промышленный альпинизм",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленный дизайн%') ) > 0 then 1::smallint else 0::smallint end "Промышленный дизайн",
    case when (count(p.*) filter(where p.category_new ilike '%Противопожарные системы%') ) > 0 then 1::smallint else 0::smallint end "Противопожарные системы",
    case when (count(p.*) filter(where p.category_new ilike '%Профсоюз%') ) > 0 then 1::smallint else 0::smallint end "Профсоюз",
    case when (count(p.*) filter(where p.category_new ilike '%Прочие кассы%') ) > 0 then 1::smallint else 0::smallint end "Прочие кассы",
    case when (count(p.*) filter(where p.category_new ilike '%Публичный центр правовой информации%') ) > 0 then 1::smallint else 0::smallint end "Публичный центр правовой информации",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт взимания платы%') ) > 0 then 1::smallint else 0::smallint end "Пункт взимания платы",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт выдачи%') ) > 0 then 1::smallint else 0::smallint end "Пункт выдачи",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт выдачи страховых полисов%') ) > 0 then 1::smallint else 0::smallint end "Пункт выдачи страховых полисов",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт предрейсового осмотра%') ) > 0 then 1::smallint else 0::smallint end "Пункт предрейсового осмотра",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт раздельного сбора мусора%') ) > 0 then 1::smallint else 0::smallint end "Пункт раздельного сбора мусора",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт сбора населения во время чрезвычайных ситуаций%') ) > 0 then 1::smallint else 0::smallint end "Пункт сбора населения во время чрезвычайных ситуаций",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт сбора помощи%') ) > 0 then 1::smallint else 0::smallint end "Пункт сбора помощи",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт техосмотра%') ) > 0 then 1::smallint else 0::smallint end "Пункт техосмотра",
    case when (count(p.*) filter(where p.category_new ilike '%Работа за рубежом%') ) > 0 then 1::smallint else 0::smallint end "Работа за рубежом",
    case when (count(p.*) filter(where p.category_new ilike '%Радиационный контроль%') ) > 0 then 1::smallint else 0::smallint end "Радиационный контроль",
    case when (count(p.*) filter(where p.category_new ilike '%Радиокомпания%') ) > 0 then 1::smallint else 0::smallint end "Радиокомпания",
    case when (count(p.*) filter(where p.category_new ilike '%Радиоуправляемые и стендовые модели%') ) > 0 then 1::smallint else 0::smallint end "Радиоуправляемые и стендовые модели",
    case when (count(p.*) filter(where p.category_new ilike '%Распространители косметики и бытовой химии%') ) > 0 then 1::smallint else 0::smallint end "Распространители косметики и бытовой химии",
    case when (count(p.*) filter(where p.category_new ilike '%Расчётно-кассовый центр%') ) > 0 then 1::smallint else 0::smallint end "Расчётно-кассовый центр",
    case when (count(p.*) filter(where p.category_new ilike '%Регистрация доменов%') ) > 0 then 1::smallint else 0::smallint end "Регистрация доменов",
    case when (count(p.*) filter(where p.category_new ilike '%Регистрация и ликвидация предприятий%') ) > 0 then 1::smallint else 0::smallint end "Регистрация и ликвидация предприятий",
    case when (count(p.*) filter(where p.category_new ilike '%Редакция СМИ%') ) > 0 then 1::smallint else 0::smallint end "Редакция СМИ",
    case when (count(p.*) filter(where p.category_new ilike '%Редукторы%') ) > 0 then 1::smallint else 0::smallint end "Редукторы",
    case when (count(p.*) filter(where p.category_new ilike '%Резиновые и резинотехнические изделия%') ) > 0 then 1::smallint else 0::smallint end "Резиновые и резинотехнические изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Рекламная продукция%') ) > 0 then 1::smallint else 0::smallint end "Рекламная продукция",
    case when (count(p.*) filter(where p.category_new ilike '%Рекламное оборудование и материалы%') ) > 0 then 1::smallint else 0::smallint end "Рекламное оборудование и материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Религиозные товары%') ) > 0 then 1::smallint else 0::smallint end "Религиозные товары",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт АКПП%') ) > 0 then 1::smallint else 0::smallint end "Ремонт АКПП",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт велосипедов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт велосипедов",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт гидравлического и пневматического оборудования%') ) > 0 then 1::smallint else 0::smallint end "Ремонт гидравлического и пневматического оборудования",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт двигателей%') ) > 0 then 1::smallint else 0::smallint end "Ремонт двигателей",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт и дублирование автомобильных ключей и брелоков%') ) > 0 then 1::smallint else 0::smallint end "Ремонт и дублирование автомобильных ключей и брелоков",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт измерительных приборов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт измерительных приборов",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт кассовых аппаратов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт кассовых аппаратов",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт климатических систем%') ) > 0 then 1::smallint else 0::smallint end "Ремонт климатических систем",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт лодок%') ) > 0 then 1::smallint else 0::smallint end "Ремонт лодок",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт мебели%') ) > 0 then 1::smallint else 0::smallint end "Ремонт мебели",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт медицинской техники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт медицинской техники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт мототехники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт мототехники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт оргтехники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт оргтехники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт оружия%') ) > 0 then 1::smallint else 0::smallint end "Ремонт оружия",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт очков%') ) > 0 then 1::smallint else 0::smallint end "Ремонт очков",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт персонального электротранспорта%') ) > 0 then 1::smallint else 0::smallint end "Ремонт персонального электротранспорта",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт промышленного оборудования%') ) > 0 then 1::smallint else 0::smallint end "Ремонт промышленного оборудования",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт промышленных холодильников%') ) > 0 then 1::smallint else 0::smallint end "Ремонт промышленных холодильников",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт садовой техники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт садовой техники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт сельскохозяйственной техники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт сельскохозяйственной техники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт спортивного инвентаря%') ) > 0 then 1::smallint else 0::smallint end "Ремонт спортивного инвентаря",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт товаров для рыбалки%') ) > 0 then 1::smallint else 0::smallint end "Ремонт товаров для рыбалки",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт торгового оборудования%') ) > 0 then 1::smallint else 0::smallint end "Ремонт торгового оборудования",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт турбин%') ) > 0 then 1::smallint else 0::smallint end "Ремонт турбин",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт фотоаппаратов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт фотоаппаратов",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт часов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт часов",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт электронных сигарет%') ) > 0 then 1::smallint else 0::smallint end "Ремонт электронных сигарет",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт электрооборудования%') ) > 0 then 1::smallint else 0::smallint end "Ремонт электрооборудования",
    case when (count(p.*) filter(where p.category_new ilike '%Реставрационная мастерская%') ) > 0 then 1::smallint else 0::smallint end "Реставрационная мастерская",
    case when (count(p.*) filter(where p.category_new ilike '%Ретритный центр%') ) > 0 then 1::smallint else 0::smallint end "Ретритный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Рольставни%') ) > 0 then 1::smallint else 0::smallint end "Рольставни",
    case when (count(p.*) filter(where p.category_new ilike '%Рукава и шланги%') ) > 0 then 1::smallint else 0::smallint end "Рукава и шланги",
    case when (count(p.*) filter(where p.category_new ilike '%Рыбное хозяйство, рыбоводство%') ) > 0 then 1::smallint else 0::smallint end "Рыбное хозяйство, рыбоводство",
    case when (count(p.*) filter(where p.category_new ilike '%Садоводческие товарищества и общества%') ) > 0 then 1::smallint else 0::smallint end "Садоводческие товарищества и общества",
    case when (count(p.*) filter(where p.category_new ilike '%3D-печать%') ) > 0 then 1::smallint else 0::smallint end "3D-печать",
    case when (count(p.*) filter(where p.category_new ilike '%Садовый центр%') ) > 0 then 1::smallint else 0::smallint end "Садовый центр",
    case when (count(p.*) filter(where p.category_new ilike '%Салон эротического массажа%') ) > 0 then 1::smallint else 0::smallint end "Салон эротического массажа",
    case when (count(p.*) filter(where p.category_new ilike '%Самогонное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Самогонное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Саморегулируемая организация%') ) > 0 then 1::smallint else 0::smallint end "Саморегулируемая организация",
    case when (count(p.*) filter(where p.category_new ilike '%Санаторно-курортное объединение%') ) > 0 then 1::smallint else 0::smallint end "Санаторно-курортное объединение",
    case when (count(p.*) filter(where p.category_new ilike '%Санитарно-эпидемиологическая служба%') ) > 0 then 1::smallint else 0::smallint end "Санитарно-эпидемиологическая служба",
    case when (count(p.*) filter(where p.category_new ilike '%Сантехнические работы%') ) > 0 then 1::smallint else 0::smallint end "Сантехнические работы",
    case when (count(p.*) filter(where p.category_new ilike '%Сборка мебели%') ) > 0 then 1::smallint else 0::smallint end "Сборка мебели",
    case when (count(p.*) filter(where p.category_new ilike '%Сварочное оборудование и материалы%') ) > 0 then 1::smallint else 0::smallint end "Сварочное оборудование и материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Сварочные работы%') ) > 0 then 1::smallint else 0::smallint end "Сварочные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Светодиодные системы освещения%') ) > 0 then 1::smallint else 0::smallint end "Светодиодные системы освещения",
    case when (count(p.*) filter(where p.category_new ilike '%Светопрозрачные конструкции%') ) > 0 then 1::smallint else 0::smallint end "Светопрозрачные конструкции",
    case when (count(p.*) filter(where p.category_new ilike '%Сейфы%') ) > 0 then 1::smallint else 0::smallint end "Сейфы",
    case when (count(p.*) filter(where p.category_new ilike '%Селекция и семеноводство%') ) > 0 then 1::smallint else 0::smallint end "Селекция и семеноводство",
    case when (count(p.*) filter(where p.category_new ilike '%Сельскохозяйственная продукция%') ) > 0 then 1::smallint else 0::smallint end "Сельскохозяйственная продукция",
    case when (count(p.*) filter(where p.category_new ilike '%Сельскохозяйственная техника%') ) > 0 then 1::smallint else 0::smallint end "Сельскохозяйственная техника",
    case when (count(p.*) filter(where p.category_new ilike '%Сельскохозяйственное предприятие%') ) > 0 then 1::smallint else 0::smallint end "Сельскохозяйственное предприятие",
    case when (count(p.*) filter(where p.category_new ilike '%Сервисный центр МВД Украины%') ) > 0 then 1::smallint else 0::smallint end "Сервисный центр МВД Украины",
    case when (count(p.*) filter(where p.category_new ilike '%Сертификация продукции и услуг%') ) > 0 then 1::smallint else 0::smallint end "Сертификация продукции и услуг",
    case when (count(p.*) filter(where p.category_new ilike '%Сестринские услуги%') ) > 0 then 1::smallint else 0::smallint end "Сестринские услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Сетевое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Сетевое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Системы безопасности и охраны%') ) > 0 then 1::smallint else 0::smallint end "Системы безопасности и охраны",
    case when (count(p.*) filter(where p.category_new ilike '%Системы вентиляции%') ) > 0 then 1::smallint else 0::smallint end "Системы вентиляции",
    case when (count(p.*) filter(where p.category_new ilike '%Системы водоснабжения, отопления, канализации%') ) > 0 then 1::smallint else 0::smallint end "Системы водоснабжения, отопления, канализации",
    case when (count(p.*) filter(where p.category_new ilike '%Системы перегородок%') ) > 0 then 1::smallint else 0::smallint end "Системы перегородок",
    case when (count(p.*) filter(where p.category_new ilike '%Сквер%') ) > 0 then 1::smallint else 0::smallint end "Сквер",
    case when (count(p.*) filter(where p.category_new ilike '%Складские услуги%') ) > 0 then 1::smallint else 0::smallint end "Складские услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Складское оборудование%') ) > 0 then 1::smallint else 0::smallint end "Складское оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Скупка золота и ювелирных изделий%') ) > 0 then 1::smallint else 0::smallint end "Скупка золота и ювелирных изделий",
    case when (count(p.*) filter(where p.category_new ilike '%Служба газового хозяйства%') ) > 0 then 1::smallint else 0::smallint end "Служба газового хозяйства",
    case when (count(p.*) filter(where p.category_new ilike '%Служба спасения%') ) > 0 then 1::smallint else 0::smallint end "Служба спасения",
    case when (count(p.*) filter(where p.category_new ilike '%Смазочные материалы%') ) > 0 then 1::smallint else 0::smallint end "Смазочные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Снабжение строительных объектов%') ) > 0 then 1::smallint else 0::smallint end "Снабжение строительных объектов",
    case when (count(p.*) filter(where p.category_new ilike '%Снос зданий%') ) > 0 then 1::smallint else 0::smallint end "Снос зданий",
    case when (count(p.*) filter(where p.category_new ilike '%Собачья площадка%') ) > 0 then 1::smallint else 0::smallint end "Собачья площадка",
    case when (count(p.*) filter(where p.category_new ilike '%Согласование наружной рекламы%') ) > 0 then 1::smallint else 0::smallint end "Согласование наружной рекламы",
    case when (count(p.*) filter(where p.category_new ilike '%Согласование перепланировок%') ) > 0 then 1::smallint else 0::smallint end "Согласование перепланировок",
    case when (count(p.*) filter(where p.category_new ilike '%Социологические исследования%') ) > 0 then 1::smallint else 0::smallint end "Социологические исследования",
    case when (count(p.*) filter(where p.category_new ilike '%Специализированные строительные работы%') ) > 0 then 1::smallint else 0::smallint end "Специализированные строительные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивная касса%') ) > 0 then 1::smallint else 0::smallint end "Спортивная касса",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивная одежда и обувь%') ) > 0 then 1::smallint else 0::smallint end "Спортивная одежда и обувь",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивное объединение%') ) > 0 then 1::smallint else 0::smallint end "Спортивное объединение",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивное питание%') ) > 0 then 1::smallint else 0::smallint end "Спортивное питание",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивный инвентарь и оборудование%') ) > 0 then 1::smallint else 0::smallint end "Спортивный инвентарь и оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Справочная аптек%') ) > 0 then 1::smallint else 0::smallint end "Справочная аптек",
    case when (count(p.*) filter(where p.category_new ilike '%Справочник%') ) > 0 then 1::smallint else 0::smallint end "Справочник",
    case when (count(p.*) filter(where p.category_new ilike '%Спутниковое телевидение%') ) > 0 then 1::smallint else 0::smallint end "Спутниковое телевидение",
    case when (count(p.*) filter(where p.category_new ilike '%Средства безопасности дорожного движения%') ) > 0 then 1::smallint else 0::smallint end "Средства безопасности дорожного движения",
    case when (count(p.*) filter(where p.category_new ilike '%Стандартизация и метрология%') ) > 0 then 1::smallint else 0::smallint end "Стандартизация и метрология",
    case when (count(p.*) filter(where p.category_new ilike '%Станция зарядки электромобилей%') ) > 0 then 1::smallint else 0::smallint end "Станция зарядки электромобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Станция скоростного городского транспорта%') ) > 0 then 1::smallint else 0::smallint end "Станция скоростного городского транспорта",
    case when (count(p.*) filter(where p.category_new ilike '%Стекольная мастерская%') ) > 0 then 1::smallint else 0::smallint end "Стекольная мастерская",
    case when (count(p.*) filter(where p.category_new ilike '%Столярные работы%') ) > 0 then 1::smallint else 0::smallint end "Столярные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Стоянка такси%') ) > 0 then 1::smallint else 0::smallint end "Стоянка такси",
    case when (count(p.*) filter(where p.category_new ilike '%Строительные и отделочные работы%') ) > 0 then 1::smallint else 0::smallint end "Строительные и отделочные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Строительный кооператив%') ) > 0 then 1::smallint else 0::smallint end "Строительный кооператив",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство бань и саун%') ) > 0 then 1::smallint else 0::smallint end "Строительство бань и саун",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство дачных домов и коттеджей%') ) > 0 then 1::smallint else 0::smallint end "Строительство дачных домов и коттеджей",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство и монтаж бассейнов, аквапарков%') ) > 0 then 1::smallint else 0::smallint end "Строительство и монтаж бассейнов, аквапарков",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство и обслуживание инженерных сетей%') ) > 0 then 1::smallint else 0::smallint end "Строительство и обслуживание инженерных сетей",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство и оснащение АЗС%') ) > 0 then 1::smallint else 0::smallint end "Строительство и оснащение АЗС",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство и ремонт дорог%') ) > 0 then 1::smallint else 0::smallint end "Строительство и ремонт дорог",
    case when (count(p.*) filter(where p.category_new ilike '%Строительство и ремонт железнодорожных путей%') ) > 0 then 1::smallint else 0::smallint end "Строительство и ремонт железнодорожных путей",
    case when (count(p.*) filter(where p.category_new ilike '%Студия веб-дизайна%') ) > 0 then 1::smallint else 0::smallint end "Студия веб-дизайна",
    case when (count(p.*) filter(where p.category_new ilike '%Студия графического дизайна%') ) > 0 then 1::smallint else 0::smallint end "Студия графического дизайна",
    case when (count(p.*) filter(where p.category_new ilike '%Студия дизайна%') ) > 0 then 1::smallint else 0::smallint end "Студия дизайна",
    case when (count(p.*) filter(where p.category_new ilike '%Студия ландшафтного дизайна%') ) > 0 then 1::smallint else 0::smallint end "Студия ландшафтного дизайна",
    case when (count(p.*) filter(where p.category_new ilike '%Судовое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Судовое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Судостроение, судоремонт%') ) > 0 then 1::smallint else 0::smallint end "Судостроение, судоремонт",
    case when (count(p.*) filter(where p.category_new ilike '%Сцена%') ) > 0 then 1::smallint else 0::smallint end "Сцена",
    case when (count(p.*) filter(where p.category_new ilike '%Сыроварня%') ) > 0 then 1::smallint else 0::smallint end "Сыроварня",
    case when (count(p.*) filter(where p.category_new ilike '%Сырьё для текстильной промышленности%') ) > 0 then 1::smallint else 0::smallint end "Сырьё для текстильной промышленности",
    case when (count(p.*) filter(where p.category_new ilike '%Такси%') ) > 0 then 1::smallint else 0::smallint end "Такси",
    case when (count(p.*) filter(where p.category_new ilike '%Таксидермия%') ) > 0 then 1::smallint else 0::smallint end "Таксидермия",
    case when (count(p.*) filter(where p.category_new ilike '%Таксофон%') ) > 0 then 1::smallint else 0::smallint end "Таксофон",
    case when (count(p.*) filter(where p.category_new ilike '%Таможенный брокер%') ) > 0 then 1::smallint else 0::smallint end "Таможенный брокер",
    case when (count(p.*) filter(where p.category_new ilike '%Таможенный склад%') ) > 0 then 1::smallint else 0::smallint end "Таможенный склад",
    case when (count(p.*) filter(where p.category_new ilike '%Тара и упаковочные материалы%') ) > 0 then 1::smallint else 0::smallint end "Тара и упаковочные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Твёрдое топливо%') ) > 0 then 1::smallint else 0::smallint end "Твёрдое топливо",
    case when (count(p.*) filter(where p.category_new ilike '%Творческий коллектив%') ) > 0 then 1::smallint else 0::smallint end "Творческий коллектив",
    case when (count(p.*) filter(where p.category_new ilike '%Театрально-концертная касса%') ) > 0 then 1::smallint else 0::smallint end "Театрально-концертная касса",
    case when (count(p.*) filter(where p.category_new ilike '%Текстильная компания%') ) > 0 then 1::smallint else 0::smallint end "Текстильная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Текстильное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Текстильное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Телекоммуникационная компания%') ) > 0 then 1::smallint else 0::smallint end "Телекоммуникационная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Телекоммуникационное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Телекоммуникационное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Телекомпания%') ) > 0 then 1::smallint else 0::smallint end "Телекомпания",
    case when (count(p.*) filter(where p.category_new ilike '%Тенты, шатры, навесы%') ) > 0 then 1::smallint else 0::smallint end "Тенты, шатры, навесы",
    case when (count(p.*) filter(where p.category_new ilike '%Тепличное хозяйство%') ) > 0 then 1::smallint else 0::smallint end "Тепличное хозяйство",
    case when (count(p.*) filter(where p.category_new ilike '%Фестиваль%') ) > 0 then 1::smallint else 0::smallint end "Фестиваль",
    case when (count(p.*) filter(where p.category_new ilike '%Теплоизоляционные материалы%') ) > 0 then 1::smallint else 0::smallint end "Теплоизоляционные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Теплоснабжение%') ) > 0 then 1::smallint else 0::smallint end "Теплоснабжение",
    case when (count(p.*) filter(where p.category_new ilike '%Терминал аэропорта%') ) > 0 then 1::smallint else 0::smallint end "Терминал аэропорта",
    case when (count(p.*) filter(where p.category_new ilike '%Технические и медицинские газы%') ) > 0 then 1::smallint else 0::smallint end "Технические и медицинские газы",
    case when (count(p.*) filter(where p.category_new ilike '%Техническое обслуживание зданий%') ) > 0 then 1::smallint else 0::smallint end "Техническое обслуживание зданий",
    case when (count(p.*) filter(where p.category_new ilike '%Технопарк%') ) > 0 then 1::smallint else 0::smallint end "Технопарк",
    case when (count(p.*) filter(where p.category_new ilike '%Товарные знаки%') ) > 0 then 1::smallint else 0::smallint end "Товарные знаки",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для бани и сауны%') ) > 0 then 1::smallint else 0::smallint end "Товары для бани и сауны",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для интерьера%') ) > 0 then 1::smallint else 0::smallint end "Товары для интерьера",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для кондитеров%') ) > 0 then 1::smallint else 0::smallint end "Товары для кондитеров",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для отдыха и туризма%') ) > 0 then 1::smallint else 0::smallint end "Товары для отдыха и туризма",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для охоты%') ) > 0 then 1::smallint else 0::smallint end "Товары для охоты",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для подводного плавания%') ) > 0 then 1::smallint else 0::smallint end "Товары для подводного плавания",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для праздника%') ) > 0 then 1::smallint else 0::smallint end "Товары для праздника",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для пчеловодства%') ) > 0 then 1::smallint else 0::smallint end "Товары для пчеловодства",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для рыбалки%') ) > 0 then 1::smallint else 0::smallint end "Товары для рыбалки",
    case when (count(p.*) filter(where p.category_new ilike '%Товары и услуги для паломников%') ) > 0 then 1::smallint else 0::smallint end "Товары и услуги для паломников",
    case when (count(p.*) filter(where p.category_new ilike '%Товары народного потребления%') ) > 0 then 1::smallint else 0::smallint end "Товары народного потребления",
    case when (count(p.*) filter(where p.category_new ilike '%Топливные карты%') ) > 0 then 1::smallint else 0::smallint end "Топливные карты",
    case when (count(p.*) filter(where p.category_new ilike '%Торговая точка%') ) > 0 then 1::smallint else 0::smallint end "Торговая точка",
    case when (count(p.*) filter(where p.category_new ilike '%Торговое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Торговое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Торгово-промышленная палата%') ) > 0 then 1::smallint else 0::smallint end "Торгово-промышленная палата",
    case when (count(p.*) filter(where p.category_new ilike '%Трамвайное депо%') ) > 0 then 1::smallint else 0::smallint end "Трамвайное депо",
    case when (count(p.*) filter(where p.category_new ilike '%Транспортёры и конвейеры%') ) > 0 then 1::smallint else 0::smallint end "Транспортёры и конвейеры",
    case when (count(p.*) filter(where p.category_new ilike '%Транспортная инфраструктура%') ) > 0 then 1::smallint else 0::smallint end "Транспортная инфраструктура",
    case when (count(p.*) filter(where p.category_new ilike '%Транспортная касса%') ) > 0 then 1::smallint else 0::smallint end "Транспортная касса",
    case when (count(p.*) filter(where p.category_new ilike '%Троллейбусный парк%') ) > 0 then 1::smallint else 0::smallint end "Троллейбусный парк",
    case when (count(p.*) filter(where p.category_new ilike '%Тротуарная плитка%') ) > 0 then 1::smallint else 0::smallint end "Тротуарная плитка",
    case when (count(p.*) filter(where p.category_new ilike '%Трубочисты%') ) > 0 then 1::smallint else 0::smallint end "Трубочисты",
    case when (count(p.*) filter(where p.category_new ilike '%Трубы и трубопроводная арматура%') ) > 0 then 1::smallint else 0::smallint end "Трубы и трубопроводная арматура",
    case when (count(p.*) filter(where p.category_new ilike '%ТСЖ%') ) > 0 then 1::smallint else 0::smallint end "ТСЖ",
    case when (count(p.*) filter(where p.category_new ilike '%Туалет%') ) > 0 then 1::smallint else 0::smallint end "Туалет",
    case when (count(p.*) filter(where p.category_new ilike '%Туристический клуб%') ) > 0 then 1::smallint else 0::smallint end "Туристический клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Угольная компания%') ) > 0 then 1::smallint else 0::smallint end "Угольная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Удобрения%') ) > 0 then 1::smallint else 0::smallint end "Удобрения",
    case when (count(p.*) filter(where p.category_new ilike '%Удостоверяющий центр%') ) > 0 then 1::smallint else 0::smallint end "Удостоверяющий центр",
    case when (count(p.*) filter(where p.category_new ilike '%Умные устройства Яндекса%') ) > 0 then 1::smallint else 0::smallint end "Умные устройства Яндекса",
    case when (count(p.*) filter(where p.category_new ilike '%Управление водными путями и их обслуживание%') ) > 0 then 1::smallint else 0::smallint end "Управ. водными путями и их обслуживание",
    case when (count(p.*) filter(where p.category_new ilike '%Управление городским транспортом и его обслуживание %') ) > 0 then 1::smallint else 0::smallint end "Управ. гор. транспортом и его обслуж. ",
    case when (count(p.*) filter(where p.category_new ilike '%Управление железными дорогами и их обслуживание %') ) > 0 then 1::smallint else 0::smallint end "Управ. железными дорогами и их обслуживание ",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги ассенизаторов%') ) > 0 then 1::smallint else 0::smallint end "Услуги ассенизаторов",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги водителя без автомобиля%') ) > 0 then 1::smallint else 0::smallint end "Услуги водителя без автомобиля",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги вышивки%') ) > 0 then 1::smallint else 0::smallint end "Услуги вышивки",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги грузчиков%') ) > 0 then 1::smallint else 0::smallint end "Услуги грузчиков",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги для ювелиров%') ) > 0 then 1::smallint else 0::smallint end "Услуги для ювелиров",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги репетиторов%') ) > 0 then 1::smallint else 0::smallint end "Услуги репетиторов",
    case when (count(p.*) filter(where p.category_new ilike '%Услуги частных специалистов%') ) > 0 then 1::smallint else 0::smallint end "Услуги частных специалистов",
    case when (count(p.*) filter(where p.category_new ilike '%Спа-салон%') ) > 0 then 1::smallint else 0::smallint end "Спа-салон",
    case when (count(p.*) filter(where p.category_new ilike '%IP-телефония%') ) > 0 then 1::smallint else 0::smallint end "IP-телефония",
    case when (count(p.*) filter(where p.category_new ilike '%IT-компания%') ) > 0 then 1::smallint else 0::smallint end "IT-компания",
    case when (count(p.*) filter(where p.category_new ilike '%STENOGRAFFIA%') ) > 0 then 1::smallint else 0::smallint end "STENOGRAFFIA",
    case when (count(p.*) filter(where p.category_new ilike '%Установка ГБО%') ) > 0 then 1::smallint else 0::smallint end "Установка ГБО",
    case when (count(p.*) filter(where p.category_new ilike '%Установка кондиционеров%') ) > 0 then 1::smallint else 0::smallint end "Установка кондиционеров",
    case when (count(p.*) filter(where p.category_new ilike '%Установка, ремонт и вскрытие замков%') ) > 0 then 1::smallint else 0::smallint end "Установка, ремонт и вскрытие замков",
    case when (count(p.*) filter(where p.category_new ilike '%Устройство сетей%') ) > 0 then 1::smallint else 0::smallint end "Устройство сетей",
    case when (count(p.*) filter(where p.category_new ilike '%Утилизация отходов%') ) > 0 then 1::smallint else 0::smallint end "Утилизация отходов",
    case when (count(p.*) filter(where p.category_new ilike '%Учебное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Учебное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Факторинговая компания%') ) > 0 then 1::smallint else 0::smallint end "Факторинговая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Катера, лодки, яхты%') ) > 0 then 1::smallint else 0::smallint end "Катера, лодки, яхты",
    case when (count(p.*) filter(where p.category_new ilike '%Школа охраны%') ) > 0 then 1::smallint else 0::smallint end "Школа охраны",
    case when (count(p.*) filter(where p.category_new ilike '%Центр профориентации%') ) > 0 then 1::smallint else 0::smallint end "Центр профориентации",
    case when (count(p.*) filter(where p.category_new ilike '%Курьерские услуги%') ) > 0 then 1::smallint else 0::smallint end "Курьерские услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Бытовая химия оптом%') ) > 0 then 1::smallint else 0::smallint end "Бытовая химия оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Хозтовары оптом%') ) > 0 then 1::smallint else 0::smallint end "Хозтовары оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин хозтоваров и бытовой химии%') ) > 0 then 1::smallint else 0::smallint end "Магазин хозтоваров и бытовой химии",
    case when (count(p.*) filter(where p.category_new ilike '%Герметики%') ) > 0 then 1::smallint else 0::smallint end "Герметики",
    case when (count(p.*) filter(where p.category_new ilike '%Обувная косметика%') ) > 0 then 1::smallint else 0::smallint end "Обувная косметика",
    case when (count(p.*) filter(where p.category_new ilike '%Средства защиты растений%') ) > 0 then 1::smallint else 0::smallint end "Средства защиты растений",
    case when (count(p.*) filter(where p.category_new ilike '%Средства индивидуальной защиты%') ) > 0 then 1::smallint else 0::smallint end "Средства индивидуальной защиты",
    case when (count(p.*) filter(where p.category_new ilike '%Детейлинг%') ) > 0 then 1::smallint else 0::smallint end "Детейлинг",
    case when (count(p.*) filter(where p.category_new ilike '%Аварийная служба%') ) > 0 then 1::smallint else 0::smallint end "Аварийная служба",
    case when (count(p.*) filter(where p.category_new ilike '%Коммунальная служба%') ) > 0 then 1::smallint else 0::smallint end "Коммунальная служба",
    case when (count(p.*) filter(where p.category_new ilike '%Аварийно-спасательное оборудование и техника%') ) > 0 then 1::smallint else 0::smallint end "Аварийно-спасательное оборудование и техника",
    case when (count(p.*) filter(where p.category_new ilike '%Авиакомпания%') ) > 0 then 1::smallint else 0::smallint end "Авиакомпания",
    case when (count(p.*) filter(where p.category_new ilike '%Автобусные междугородные перевозки%') ) > 0 then 1::smallint else 0::smallint end "Автобусные междугородные перевозки",
    case when (count(p.*) filter(where p.category_new ilike '%Автовокзал, автостанция%') ) > 0 then 1::smallint else 0::smallint end "Автовокзал, автостанция",
    case when (count(p.*) filter(where p.category_new ilike '%Заказ автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Заказ автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Грузовые автомобили, грузовая техника%') ) > 0 then 1::smallint else 0::smallint end "Грузовые автомобили, грузовая техника",
    case when (count(p.*) filter(where p.category_new ilike '%Выкуп автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Выкуп автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Автофургоны и автодома%') ) > 0 then 1::smallint else 0::smallint end "Автофургоны и автодома",
    case when (count(p.*) filter(where p.category_new ilike '%Авторынок%') ) > 0 then 1::smallint else 0::smallint end "Авторынок",
    case when (count(p.*) filter(where p.category_new ilike '%Мотосалон%') ) > 0 then 1::smallint else 0::smallint end "Мотосалон",
    case when (count(p.*) filter(where p.category_new ilike '%Автоподбор%') ) > 0 then 1::smallint else 0::smallint end "Автоподбор",
    case when (count(p.*) filter(where p.category_new ilike '%Автосалон%') ) > 0 then 1::smallint else 0::smallint end "Автосалон",
    case when (count(p.*) filter(where p.category_new ilike '%Автоломбард%') ) > 0 then 1::smallint else 0::smallint end "Автоломбард",
    case when (count(p.*) filter(where p.category_new ilike '%Автоаукцион%') ) > 0 then 1::smallint else 0::smallint end "Автоаукцион",
    case when (count(p.*) filter(where p.category_new ilike '%Спецтехника и спецавтомобили%') ) > 0 then 1::smallint else 0::smallint end "Спецтехника и спецавтомобили",
    case when (count(p.*) filter(where p.category_new ilike '%Автосервис, автотехцентр%') ) > 0 then 1::smallint else 0::smallint end "Автосервис, автотехцентр",
    case when (count(p.*) filter(where p.category_new ilike '%Автотехпомощь, эвакуация автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Автотехпомощь, эвакуация автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Автоэкспертиза, оценка автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Автоэкспертиза, оценка автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Оклейка машин%') ) > 0 then 1::smallint else 0::smallint end "Оклейка машин",
    case when (count(p.*) filter(where p.category_new ilike '%Мониторинг автотранспорта%') ) > 0 then 1::smallint else 0::smallint end "Мониторинг автотранспорта",
    case when (count(p.*) filter(where p.category_new ilike '%Студия автотюнинга%') ) > 0 then 1::smallint else 0::smallint end "Студия автотюнинга",
    case when (count(p.*) filter(where p.category_new ilike '%Тонирование стёкол%') ) > 0 then 1::smallint else 0::smallint end "Тонирование стёкол",
    case when (count(p.*) filter(where p.category_new ilike '%Автомойка%') ) > 0 then 1::smallint else 0::smallint end "Автомойка",
    case when (count(p.*) filter(where p.category_new ilike '%Кузовной ремонт%') ) > 0 then 1::smallint else 0::smallint end "Кузовной ремонт",
    case when (count(p.*) filter(where p.category_new ilike '%Авторазбор%') ) > 0 then 1::smallint else 0::smallint end "Авторазбор",
    case when (count(p.*) filter(where p.category_new ilike '%Автошкола%') ) > 0 then 1::smallint else 0::smallint end "Автошкола",
    case when (count(p.*) filter(where p.category_new ilike '%Адвокаты%') ) > 0 then 1::smallint else 0::smallint end "Адвокаты",
    case when (count(p.*) filter(where p.category_new ilike '%Администрация%') ) > 0 then 1::smallint else 0::smallint end "Администрация",
    case when (count(p.*) filter(where p.category_new ilike '%АГНС, АГЗС, АГНКС%') ) > 0 then 1::smallint else 0::smallint end "АГНС, АГЗС, АГНКС",
    case when (count(p.*) filter(where p.category_new ilike '%АЗС%') ) > 0 then 1::smallint else 0::smallint end "АЗС",
    case when (count(p.*) filter(where p.category_new ilike '%Амбулатория, здравпункт, медпункт%') ) > 0 then 1::smallint else 0::smallint end "Амбулатория, здравпункт, медпункт",
    case when (count(p.*) filter(where p.category_new ilike '%Фитопродукция, БАДы%') ) > 0 then 1::smallint else 0::smallint end "Фитопродукция, БАДы",
    case when (count(p.*) filter(where p.category_new ilike '%Аптека%') ) > 0 then 1::smallint else 0::smallint end "Аптека",
    case when (count(p.*) filter(where p.category_new ilike '%Стадион%') ) > 0 then 1::smallint else 0::smallint end "Стадион",
    case when (count(p.*) filter(where p.category_new ilike '%Блок стадиона%') ) > 0 then 1::smallint else 0::smallint end "Блок стадиона",
    case when (count(p.*) filter(where p.category_new ilike '%Архив%') ) > 0 then 1::smallint else 0::smallint end "Архив",
    case when (count(p.*) filter(where p.category_new ilike '%Архивные услуги%') ) > 0 then 1::smallint else 0::smallint end "Архивные услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Обувное ателье%') ) > 0 then 1::smallint else 0::smallint end "Обувное ателье",
    case when (count(p.*) filter(where p.category_new ilike '%Ателье по пошиву одежды%') ) > 0 then 1::smallint else 0::smallint end "Ателье по пошиву одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Аудиторская компания%') ) > 0 then 1::smallint else 0::smallint end "Аудиторская компания",
    case when (count(p.*) filter(where p.category_new ilike '%Аэроклуб%') ) > 0 then 1::smallint else 0::smallint end "Аэроклуб",
    case when (count(p.*) filter(where p.category_new ilike '%База гидросамолётов%') ) > 0 then 1::smallint else 0::smallint end "База гидросамолётов",
    case when (count(p.*) filter(where p.category_new ilike '%Аэропорт%') ) > 0 then 1::smallint else 0::smallint end "Аэропорт",
    case when (count(p.*) filter(where p.category_new ilike '%Банк%') ) > 0 then 1::smallint else 0::smallint end "Банк",
    case when (count(p.*) filter(where p.category_new ilike '%Банкетный зал%') ) > 0 then 1::smallint else 0::smallint end "Банкетный зал",
    case when (count(p.*) filter(where p.category_new ilike '%Банкомат%') ) > 0 then 1::smallint else 0::smallint end "Банкомат",
    case when (count(p.*) filter(where p.category_new ilike '%Баня%') ) > 0 then 1::smallint else 0::smallint end "Баня",
    case when (count(p.*) filter(where p.category_new ilike '%Бар, паб%') ) > 0 then 1::smallint else 0::smallint end "Бар, паб",
    case when (count(p.*) filter(where p.category_new ilike '%Бар безалкогольных напитков%') ) > 0 then 1::smallint else 0::smallint end "Бар безалкогольных напитков",
    case when (count(p.*) filter(where p.category_new ilike '%Бассейн%') ) > 0 then 1::smallint else 0::smallint end "Бассейн",
    case when (count(p.*) filter(where p.category_new ilike '%Библиотека%') ) > 0 then 1::smallint else 0::smallint end "Библиотека",
    case when (count(p.*) filter(where p.category_new ilike '%Бизнес-школа%') ) > 0 then 1::smallint else 0::smallint end "Бизнес-школа",
    case when (count(p.*) filter(where p.category_new ilike '%Бильярдный клуб%') ) > 0 then 1::smallint else 0::smallint end "Бильярдный клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Больница для взрослых%') ) > 0 then 1::smallint else 0::smallint end "Больница для взрослых",
    case when (count(p.*) filter(where p.category_new ilike '%Боулинг-клуб%') ) > 0 then 1::smallint else 0::smallint end "Боулинг-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Булочная, пекарня%') ) > 0 then 1::smallint else 0::smallint end "Булочная, пекарня",
    case when (count(p.*) filter(where p.category_new ilike '%Бухгалтерские курсы%') ) > 0 then 1::smallint else 0::smallint end "Бухгалтерские курсы",
    case when (count(p.*) filter(where p.category_new ilike '%Бухгалтерские услуги%') ) > 0 then 1::smallint else 0::smallint end "Бухгалтерские услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Музей%') ) > 0 then 1::smallint else 0::smallint end "Музей",
    case when (count(p.*) filter(where p.category_new ilike '%Багетные изделия%') ) > 0 then 1::smallint else 0::smallint end "Багетные изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Деловые услуги для предпринимателей%') ) > 0 then 1::smallint else 0::smallint end "Деловые услуги для предпринимателей",
    case when (count(p.*) filter(where p.category_new ilike '%Быстрое питание%') ) > 0 then 1::smallint else 0::smallint end "Быстрое питание",
    case when (count(p.*) filter(where p.category_new ilike '%Фудкорт%') ) > 0 then 1::smallint else 0::smallint end "Фудкорт",
    case when (count(p.*) filter(where p.category_new ilike '%Кофе с собой%') ) > 0 then 1::smallint else 0::smallint end "Кофе с собой",
    case when (count(p.*) filter(where p.category_new ilike '%Бюро переводов%') ) > 0 then 1::smallint else 0::smallint end "Бюро переводов",
    case when (count(p.*) filter(where p.category_new ilike '%Статистическая организация%') ) > 0 then 1::smallint else 0::smallint end "Статистическая организация",
    case when (count(p.*) filter(where p.category_new ilike '%Министерства, ведомства, государственные службы%') ) > 0 then 1::smallint else 0::smallint end "Министерства, ведомства, государственные службы",
    case when (count(p.*) filter(where p.category_new ilike '%Вейп шоп%') ) > 0 then 1::smallint else 0::smallint end "Вейп шоп",
    case when (count(p.*) filter(where p.category_new ilike '%Ветеринарная лаборатория%') ) > 0 then 1::smallint else 0::smallint end "Ветеринарная лаборатория",
    case when (count(p.*) filter(where p.category_new ilike '%Ветеринарная клиника%') ) > 0 then 1::smallint else 0::smallint end "Ветеринарная клиника",
    case when (count(p.*) filter(where p.category_new ilike '%Лаборатория ветеринарно-санитарной экспертизы%') ) > 0 then 1::smallint else 0::smallint end "Лаборатория ветеринарно-санитарной экспертизы",
    case when (count(p.*) filter(where p.category_new ilike '%Видеопроизводство%') ) > 0 then 1::smallint else 0::smallint end "Видеопроизводство",
    case when (count(p.*) filter(where p.category_new ilike '%Видеосъёмка%') ) > 0 then 1::smallint else 0::smallint end "Видеосъёмка",
    case when (count(p.*) filter(where p.category_new ilike '%Съёмка виртуальных туров и панорам%') ) > 0 then 1::smallint else 0::smallint end "Съёмка виртуальных туров и панорам",
    case when (count(p.*) filter(where p.category_new ilike '%Визажисты, стилисты%') ) > 0 then 1::smallint else 0::smallint end "Визажисты, стилисты",
    case when (count(p.*) filter(where p.category_new ilike '%Визовые центры иностранных государств%') ) > 0 then 1::smallint else 0::smallint end "Визовые центры иностранных государств",
    case when (count(p.*) filter(where p.category_new ilike '%Водная база, лодочная станция%') ) > 0 then 1::smallint else 0::smallint end "Водная база, лодочная станция",
    case when (count(p.*) filter(where p.category_new ilike '%Военкомат%') ) > 0 then 1::smallint else 0::smallint end "Военкомат",
    case when (count(p.*) filter(where p.category_new ilike '%Военная, кадетская школа%') ) > 0 then 1::smallint else 0::smallint end "Военная, кадетская школа",
    case when (count(p.*) filter(where p.category_new ilike '%Воскресная школа%') ) > 0 then 1::smallint else 0::smallint end "Воскресная школа",
    case when (count(p.*) filter(where p.category_new ilike '%Хореографическое училище%') ) > 0 then 1::smallint else 0::smallint end "Хореографическое училище",
    case when (count(p.*) filter(where p.category_new ilike '%ВУЗ%') ) > 0 then 1::smallint else 0::smallint end "ВУЗ",
    case when (count(p.*) filter(where p.category_new ilike '%Гимназия%') ) > 0 then 1::smallint else 0::smallint end "Гимназия",
    case when (count(p.*) filter(where p.category_new ilike '%Центр планирования семьи%') ) > 0 then 1::smallint else 0::smallint end "Центр планирования семьи",
    case when (count(p.*) filter(where p.category_new ilike '%Гинекологическая клиника%') ) > 0 then 1::smallint else 0::smallint end "Гинекологическая клиника",
    case when (count(p.*) filter(where p.category_new ilike '%Продуктовый гипермаркет%') ) > 0 then 1::smallint else 0::smallint end "Продуктовый гипермаркет",
    case when (count(p.*) filter(where p.category_new ilike '%Строительный гипермаркет%') ) > 0 then 1::smallint else 0::smallint end "Строительный гипермаркет",
    case when (count(p.*) filter(where p.category_new ilike '%Гипермаркет%') ) > 0 then 1::smallint else 0::smallint end "Гипермаркет",
    case when (count(p.*) filter(where p.category_new ilike '%Гольф-клуб%') ) > 0 then 1::smallint else 0::smallint end "Гольф-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Мини-гольф%') ) > 0 then 1::smallint else 0::smallint end "Мини-гольф",
    case when (count(p.*) filter(where p.category_new ilike '%Госпиталь%') ) > 0 then 1::smallint else 0::smallint end "Госпиталь",
    case when (count(p.*) filter(where p.category_new ilike '%Гостиница%') ) > 0 then 1::smallint else 0::smallint end "Гостиница",
    case when (count(p.*) filter(where p.category_new ilike '%Государственная служба безопасности%') ) > 0 then 1::smallint else 0::smallint end "Государственная служба безопасности",
    case when (count(p.*) filter(where p.category_new ilike '%Вневедомственная охрана%') ) > 0 then 1::smallint else 0::smallint end "Вневедомственная охрана",
    case when (count(p.*) filter(where p.category_new ilike '%Дайвинг%') ) > 0 then 1::smallint else 0::smallint end "Дайвинг",
    case when (count(p.*) filter(where p.category_new ilike '%Детективное агентство%') ) > 0 then 1::smallint else 0::smallint end "Детективное агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Детская больница%') ) > 0 then 1::smallint else 0::smallint end "Детская больница",
    case when (count(p.*) filter(where p.category_new ilike '%Детская поликлиника%') ) > 0 then 1::smallint else 0::smallint end "Детская поликлиника",
    case when (count(p.*) filter(where p.category_new ilike '%Детское игровое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Детское игровое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Детские игрушки и игры%') ) > 0 then 1::smallint else 0::smallint end "Детские игрушки и игры",
    case when (count(p.*) filter(where p.category_new ilike '%Детский магазин%') ) > 0 then 1::smallint else 0::smallint end "Детский магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Детский лагерь отдыха%') ) > 0 then 1::smallint else 0::smallint end "Детский лагерь отдыха",
    case when (count(p.*) filter(where p.category_new ilike '%Детский сад%') ) > 0 then 1::smallint else 0::smallint end "Детский сад",
    case when (count(p.*) filter(where p.category_new ilike '%Диагностический центр%') ) > 0 then 1::smallint else 0::smallint end "Диагностический центр",
    case when (count(p.*) filter(where p.category_new ilike '%Медсанчасть%') ) > 0 then 1::smallint else 0::smallint end "Медсанчасть",
    case when (count(p.*) filter(where p.category_new ilike '%Танцплощадка%') ) > 0 then 1::smallint else 0::smallint end "Танцплощадка",
    case when (count(p.*) filter(where p.category_new ilike '%Ночной клуб%') ) > 0 then 1::smallint else 0::smallint end "Ночной клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Диспансер%') ) > 0 then 1::smallint else 0::smallint end "Диспансер",
    case when (count(p.*) filter(where p.category_new ilike '%Хоспис%') ) > 0 then 1::smallint else 0::smallint end "Хоспис",
    case when (count(p.*) filter(where p.category_new ilike '%Ночлежный дом%') ) > 0 then 1::smallint else 0::smallint end "Ночлежный дом",
    case when (count(p.*) filter(where p.category_new ilike '%Дом инвалидов и престарелых%') ) > 0 then 1::smallint else 0::smallint end "Дом инвалидов и престарелых",
    case when (count(p.*) filter(where p.category_new ilike '%Карнавальные, театральные и танцевальные костюмы%') ) > 0 then 1::smallint else 0::smallint end "Карнавальные, театральные и танцевальные костюмы",
    case when (count(p.*) filter(where p.category_new ilike '%Картинг%') ) > 0 then 1::smallint else 0::smallint end "Картинг",
    case when (count(p.*) filter(where p.category_new ilike '%Квадромаршруты%') ) > 0 then 1::smallint else 0::smallint end "Квадромаршруты",
    case when (count(p.*) filter(where p.category_new ilike '%Каток%') ) > 0 then 1::smallint else 0::smallint end "Каток",
    case when (count(p.*) filter(where p.category_new ilike '%Католический храм%') ) > 0 then 1::smallint else 0::smallint end "Католический храм",
    case when (count(p.*) filter(where p.category_new ilike '%Кофейня%') ) > 0 then 1::smallint else 0::smallint end "Кофейня",
    case when (count(p.*) filter(where p.category_new ilike '%Кафе%') ) > 0 then 1::smallint else 0::smallint end "Кафе",
    case when (count(p.*) filter(where p.category_new ilike '%Антикафе%') ) > 0 then 1::smallint else 0::smallint end "Антикафе",
    case when (count(p.*) filter(where p.category_new ilike '%Квесты%') ) > 0 then 1::smallint else 0::smallint end "Квесты",
    case when (count(p.*) filter(where p.category_new ilike '%Кейтеринг%') ) > 0 then 1::smallint else 0::smallint end "Кейтеринг",
    case when (count(p.*) filter(where p.category_new ilike '%Кинотеатр%') ) > 0 then 1::smallint else 0::smallint end "Кинотеатр",
    case when (count(p.*) filter(where p.category_new ilike '%Инфокиоск%') ) > 0 then 1::smallint else 0::smallint end "Инфокиоск",
    case when (count(p.*) filter(where p.category_new ilike '%Точка продажи прессы%') ) > 0 then 1::smallint else 0::smallint end "Точка продажи прессы",
    case when (count(p.*) filter(where p.category_new ilike '%Медцентр, клиника%') ) > 0 then 1::smallint else 0::smallint end "Медцентр, клиника",
    case when (count(p.*) filter(where p.category_new ilike '%Частнопрактикующие врачи%') ) > 0 then 1::smallint else 0::smallint end "Частнопрактикующие врачи",
    case when (count(p.*) filter(where p.category_new ilike '%Клуб досуга%') ) > 0 then 1::smallint else 0::smallint end "Клуб досуга",
    case when (count(p.*) filter(where p.category_new ilike '%Клуб охотников и рыболовов%') ) > 0 then 1::smallint else 0::smallint end "Клуб охотников и рыболовов",
    case when (count(p.*) filter(where p.category_new ilike '%Букинистический магазин%') ) > 0 then 1::smallint else 0::smallint end "Букинистический магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Учебная литература%') ) > 0 then 1::smallint else 0::smallint end "Учебная литература",
    case when (count(p.*) filter(where p.category_new ilike '%Настольные и интеллектуальные игры%') ) > 0 then 1::smallint else 0::smallint end "Настольные и интеллектуальные игры",
    case when (count(p.*) filter(where p.category_new ilike '%Книжный магазин%') ) > 0 then 1::smallint else 0::smallint end "Книжный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин комиксов%') ) > 0 then 1::smallint else 0::smallint end "Магазин комиксов",
    case when (count(p.*) filter(where p.category_new ilike '%Колледж%') ) > 0 then 1::smallint else 0::smallint end "Колледж",
    case when (count(p.*) filter(where p.category_new ilike '%Техникум%') ) > 0 then 1::smallint else 0::smallint end "Техникум",
    case when (count(p.*) filter(where p.category_new ilike '%Компьютерные курсы%') ) > 0 then 1::smallint else 0::smallint end "Компьютерные курсы",
    case when (count(p.*) filter(where p.category_new ilike '%Компьютерный ремонт и услуги%') ) > 0 then 1::smallint else 0::smallint end "Компьютерный ремонт и услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Торты на заказ%') ) > 0 then 1::smallint else 0::smallint end "Торты на заказ",
    case when (count(p.*) filter(where p.category_new ilike '%Кондитерская%') ) > 0 then 1::smallint else 0::smallint end "Кондитерская",
    case when (count(p.*) filter(where p.category_new ilike '%Морг%') ) > 0 then 1::smallint else 0::smallint end "Морг",
    case when (count(p.*) filter(where p.category_new ilike '%Конный клуб%') ) > 0 then 1::smallint else 0::smallint end "Конный клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Посольство, консульство%') ) > 0 then 1::smallint else 0::smallint end "Посольство, консульство",
    case when (count(p.*) filter(where p.category_new ilike '%Концертный зал%') ) > 0 then 1::smallint else 0::smallint end "Концертный зал",
    case when (count(p.*) filter(where p.category_new ilike '%Консерватория%') ) > 0 then 1::smallint else 0::smallint end "Консерватория",
    case when (count(p.*) filter(where p.category_new ilike '%Коррекция зрения%') ) > 0 then 1::smallint else 0::smallint end "Коррекция зрения",
    case when (count(p.*) filter(where p.category_new ilike '%Косметология%') ) > 0 then 1::smallint else 0::smallint end "Косметология",
    case when (count(p.*) filter(where p.category_new ilike '%Шугаринг%') ) > 0 then 1::smallint else 0::smallint end "Шугаринг",
    case when (count(p.*) filter(where p.category_new ilike '%Салон бровей и ресниц%') ) > 0 then 1::smallint else 0::smallint end "Салон бровей и ресниц",
    case when (count(p.*) filter(where p.category_new ilike '%Лазерная эпиляция%') ) > 0 then 1::smallint else 0::smallint end "Лазерная эпиляция",
    case when (count(p.*) filter(where p.category_new ilike '%Кредитный брокер%') ) > 0 then 1::smallint else 0::smallint end "Кредитный брокер",
    case when (count(p.*) filter(where p.category_new ilike '%Брокерская компания%') ) > 0 then 1::smallint else 0::smallint end "Брокерская компания",
    case when (count(p.*) filter(where p.category_new ilike '%Культурный центр%') ) > 0 then 1::smallint else 0::smallint end "Культурный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Курсы и мастер-классы%') ) > 0 then 1::smallint else 0::smallint end "Курсы и мастер-классы",
    case when (count(p.*) filter(where p.category_new ilike '%Курсы иностранных языков%') ) > 0 then 1::smallint else 0::smallint end "Курсы иностранных языков",
    case when (count(p.*) filter(where p.category_new ilike '%Лазертаг%') ) > 0 then 1::smallint else 0::smallint end "Лазертаг",
    case when (count(p.*) filter(where p.category_new ilike '%Лицей%') ) > 0 then 1::smallint else 0::smallint end "Лицей",
    case when (count(p.*) filter(where p.category_new ilike '%Логопеды%') ) > 0 then 1::smallint else 0::smallint end "Логопеды",
    case when (count(p.*) filter(where p.category_new ilike '%Ломбард%') ) > 0 then 1::smallint else 0::smallint end "Ломбард",
    case when (count(p.*) filter(where p.category_new ilike '%Комиссионный магазин%') ) > 0 then 1::smallint else 0::smallint end "Комиссионный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Лыжная база%') ) > 0 then 1::smallint else 0::smallint end "Лыжная база",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин фиксированной цены%') ) > 0 then 1::smallint else 0::smallint end "Магазин фиксированной цены",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для дома%') ) > 0 then 1::smallint else 0::smallint end "Товары для дома",
    case when (count(p.*) filter(where p.category_new ilike '%Товары по каталогам%') ) > 0 then 1::smallint else 0::smallint end "Товары по каталогам",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин беговелов и самокатов%') ) > 0 then 1::smallint else 0::smallint end "Магазин беговелов и самокатов",
    case when (count(p.*) filter(where p.category_new ilike '%Аниме-магазин%') ) > 0 then 1::smallint else 0::smallint end "Аниме-магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Антикварный магазин%') ) > 0 then 1::smallint else 0::smallint end "Антикварный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Веломагазин%') ) > 0 then 1::smallint else 0::smallint end "Веломагазин",
    case when (count(p.*) filter(where p.category_new ilike '%Интернет-магазин%') ) > 0 then 1::smallint else 0::smallint end "Интернет-магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин смешанных товаров%') ) > 0 then 1::smallint else 0::smallint end "Магазин смешанных товаров",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин беспошлинной торговли%') ) > 0 then 1::smallint else 0::smallint end "Магазин беспошлинной торговли",
    case when (count(p.*) filter(where p.category_new ilike '%Автоакустика%') ) > 0 then 1::smallint else 0::smallint end "Автоакустика",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильные отопители%') ) > 0 then 1::smallint else 0::smallint end "Автомобильные отопители",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильные прицепы%') ) > 0 then 1::smallint else 0::smallint end "Автомобильные прицепы",
    case when (count(p.*) filter(where p.category_new ilike '%Автокосметика, автохимия%') ) > 0 then 1::smallint else 0::smallint end "Автокосметика, автохимия",
    case when (count(p.*) filter(where p.category_new ilike '%Автокондиционеры%') ) > 0 then 1::smallint else 0::smallint end "Автокондиционеры",
    case when (count(p.*) filter(where p.category_new ilike '%Автокресла%') ) > 0 then 1::smallint else 0::smallint end "Автокресла",
    case when (count(p.*) filter(where p.category_new ilike '%Автоаксессуары%') ) > 0 then 1::smallint else 0::smallint end "Автоаксессуары",
    case when (count(p.*) filter(where p.category_new ilike '%Автоателье%') ) > 0 then 1::smallint else 0::smallint end "Автоателье",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильные радиаторы%') ) > 0 then 1::smallint else 0::smallint end "Автомобильные радиаторы",
    case when (count(p.*) filter(where p.category_new ilike '%Автомобильные тахографы%') ) > 0 then 1::smallint else 0::smallint end "Автомобильные тахографы",
    case when (count(p.*) filter(where p.category_new ilike '%Автомоечное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Автомоечное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Парики, накладные пряди, волосы для наращивания%') ) > 0 then 1::smallint else 0::smallint end "Парики, накладные пряди, волосы для наращивания",
    case when (count(p.*) filter(where p.category_new ilike '%Паркет%') ) > 0 then 1::smallint else 0::smallint end "Паркет",
    case when (count(p.*) filter(where p.category_new ilike '%Автосвет%') ) > 0 then 1::smallint else 0::smallint end "Автосвет",
    case when (count(p.*) filter(where p.category_new ilike '%Автосервисное и гаражное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Автосервисное и гаражное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Автосигнализация%') ) > 0 then 1::smallint else 0::smallint end "Автосигнализация",
    case when (count(p.*) filter(where p.category_new ilike '%Автостёкла%') ) > 0 then 1::smallint else 0::smallint end "Автостёкла",
    case when (count(p.*) filter(where p.category_new ilike '%Автотенты и пологи%') ) > 0 then 1::smallint else 0::smallint end "Автотенты и пологи",
    case when (count(p.*) filter(where p.category_new ilike '%Автоэмали, автомобильные краски%') ) > 0 then 1::smallint else 0::smallint end "Автоэмали, автомобильные краски",
    case when (count(p.*) filter(where p.category_new ilike '%Бронированные стёкла%') ) > 0 then 1::smallint else 0::smallint end "Бронированные стёкла",
    case when (count(p.*) filter(where p.category_new ilike '%Запчасти для автобусов%') ) > 0 then 1::smallint else 0::smallint end "Запчасти для автобусов",
    case when (count(p.*) filter(where p.category_new ilike '%Запчасти для мототехники%') ) > 0 then 1::smallint else 0::smallint end "Запчасти для мототехники",
    case when (count(p.*) filter(where p.category_new ilike '%Перевозка автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Перевозка автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Производство и оптовая продажа автозапчастей%') ) > 0 then 1::smallint else 0::smallint end "Производство и оптовая продажа автозапчастей",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин автозапчастей и автотоваров%') ) > 0 then 1::smallint else 0::smallint end "Магазин автозапчастей и автотоваров",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин алкогольных напитков%') ) > 0 then 1::smallint else 0::smallint end "Магазин алкогольных напитков",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин пляжных товаров%') ) > 0 then 1::smallint else 0::smallint end "Магазин пляжных товаров",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин белья и купальников%') ) > 0 then 1::smallint else 0::smallint end "Магазин белья и купальников",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин бижутерии%') ) > 0 then 1::smallint else 0::smallint end "Магазин бижутерии",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин бильярда%') ) > 0 then 1::smallint else 0::smallint end "Магазин бильярда",
    case when (count(p.*) filter(where p.category_new ilike '%Диспоузеры%') ) > 0 then 1::smallint else 0::smallint end "Диспоузеры",
    case when (count(p.*) filter(where p.category_new ilike '%Электросчетчики%') ) > 0 then 1::smallint else 0::smallint end "Электросчетчики",
    case when (count(p.*) filter(where p.category_new ilike '%Запчасти и аксессуары для бытовой техники%') ) > 0 then 1::smallint else 0::smallint end "Запчасти и аксессуары для бытовой техники",
    case when (count(p.*) filter(where p.category_new ilike '%Кондиционеры%') ) > 0 then 1::smallint else 0::smallint end "Кондиционеры",
    case when (count(p.*) filter(where p.category_new ilike '%Электронагреватели%') ) > 0 then 1::smallint else 0::smallint end "Электронагреватели",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин бытовой техники%') ) > 0 then 1::smallint else 0::smallint end "Магазин бытовой техники",
    case when (count(p.*) filter(where p.category_new ilike '%Водонагреватели%') ) > 0 then 1::smallint else 0::smallint end "Водонагреватели",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин верхней одежды%') ) > 0 then 1::smallint else 0::smallint end "Магазин верхней одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Фильтры для воды%') ) > 0 then 1::smallint else 0::smallint end "Фильтры для воды",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин воды%') ) > 0 then 1::smallint else 0::smallint end "Магазин воды",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин галантереи и аксессуаров%') ) > 0 then 1::smallint else 0::smallint end "Магазин галантереи и аксессуаров",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин головных уборов%') ) > 0 then 1::smallint else 0::smallint end "Магазин головных уборов",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин детского питания%') ) > 0 then 1::smallint else 0::smallint end "Магазин детского питания",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин детской обуви%') ) > 0 then 1::smallint else 0::smallint end "Магазин детской обуви",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин детской одежды%') ) > 0 then 1::smallint else 0::smallint end "Магазин детской одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин джинсовой одежды%') ) > 0 then 1::smallint else 0::smallint end "Магазин джинсовой одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Шины и диски%') ) > 0 then 1::smallint else 0::smallint end "Шины и диски",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин для будущих мам%') ) > 0 then 1::smallint else 0::smallint end "Магазин для будущих мам",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин для садоводов%') ) > 0 then 1::smallint else 0::smallint end "Магазин для садоводов",
    case when (count(p.*) filter(where p.category_new ilike '%Тепличное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Тепличное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин канцтоваров%') ) > 0 then 1::smallint else 0::smallint end "Магазин канцтоваров",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин ковров%') ) > 0 then 1::smallint else 0::smallint end "Магазин ковров",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин кожи и меха%') ) > 0 then 1::smallint else 0::smallint end "Магазин кожи и меха",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин мяса, колбас%') ) > 0 then 1::smallint else 0::smallint end "Магазин мяса, колбас",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин кулинарии%') ) > 0 then 1::smallint else 0::smallint end "Магазин кулинарии",
    case when (count(p.*) filter(where p.category_new ilike '%Мебель для спальни%') ) > 0 then 1::smallint else 0::smallint end "Мебель для спальни",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин мебели%') ) > 0 then 1::smallint else 0::smallint end "Магазин мебели",
    case when (count(p.*) filter(where p.category_new ilike '%Детская мебель%') ) > 0 then 1::smallint else 0::smallint end "Детская мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Корпусная мебель%') ) > 0 then 1::smallint else 0::smallint end "Корпусная мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Мебель для ванных комнат%') ) > 0 then 1::smallint else 0::smallint end "Мебель для ванных комнат",
    case when (count(p.*) filter(where p.category_new ilike '%Мебель для кухни%') ) > 0 then 1::smallint else 0::smallint end "Мебель для кухни",
    case when (count(p.*) filter(where p.category_new ilike '%Мебель для офиса%') ) > 0 then 1::smallint else 0::smallint end "Мебель для офиса",
    case when (count(p.*) filter(where p.category_new ilike '%Мебель на заказ%') ) > 0 then 1::smallint else 0::smallint end "Мебель на заказ",
    case when (count(p.*) filter(where p.category_new ilike '%Мебельная фурнитура и комплектующие%') ) > 0 then 1::smallint else 0::smallint end "Мебельная фурнитура и комплектующие",
    case when (count(p.*) filter(where p.category_new ilike '%Металлическая мебель%') ) > 0 then 1::smallint else 0::smallint end "Металлическая мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Мягкая мебель%') ) > 0 then 1::smallint else 0::smallint end "Мягкая мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Садовая мебель%') ) > 0 then 1::smallint else 0::smallint end "Садовая мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Стеллажи%') ) > 0 then 1::smallint else 0::smallint end "Стеллажи",
    case when (count(p.*) filter(where p.category_new ilike '%Шкафы-купе%') ) > 0 then 1::smallint else 0::smallint end "Шкафы-купе",
    case when (count(p.*) filter(where p.category_new ilike '%Эксклюзивная мебель%') ) > 0 then 1::smallint else 0::smallint end "Эксклюзивная мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин медицинских товаров%') ) > 0 then 1::smallint else 0::smallint end "Магазин медицинских товаров",
    case when (count(p.*) filter(where p.category_new ilike '%Массажное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Массажное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Ветеринарные препараты и оборудование%') ) > 0 then 1::smallint else 0::smallint end "Ветеринарные препараты и оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Фармацевтическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Фармацевтическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Стоматологические материалы и оборудование%') ) > 0 then 1::smallint else 0::smallint end "Стоматологические материалы и оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для здоровья%') ) > 0 then 1::smallint else 0::smallint end "Товары для здоровья",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинское оборудование, медтехника%') ) > 0 then 1::smallint else 0::smallint end "Медицинское оборудование, медтехника",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинские изделия и расходные материалы%') ) > 0 then 1::smallint else 0::smallint end "Медицинские изделия и расходные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинская мебель%') ) > 0 then 1::smallint else 0::smallint end "Медицинская мебель",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин наглядных учебных пособий%') ) > 0 then 1::smallint else 0::smallint end "Магазин наглядных учебных пособий",
    case when (count(p.*) filter(where p.category_new ilike '%Филателия%') ) > 0 then 1::smallint else 0::smallint end "Филателия",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин нумизматики%') ) > 0 then 1::smallint else 0::smallint end "Магазин нумизматики",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин обоев%') ) > 0 then 1::smallint else 0::smallint end "Магазин обоев",
    case when (count(p.*) filter(where p.category_new ilike '%Фотообои и фрески%') ) > 0 then 1::smallint else 0::smallint end "Фотообои и фрески",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин обуви%') ) > 0 then 1::smallint else 0::smallint end "Магазин обуви",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин одежды%') ) > 0 then 1::smallint else 0::smallint end "Магазин одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Стрит-арт%') ) > 0 then 1::smallint else 0::smallint end "Стрит-арт",
    case when (count(p.*) filter(where p.category_new ilike '%Военная форма%') ) > 0 then 1::smallint else 0::smallint end "Военная форма",
    case when (count(p.*) filter(where p.category_new ilike '%Войлочные и фетровые изделия%') ) > 0 then 1::smallint else 0::smallint end "Войлочные и фетровые изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Одежда больших размеров%') ) > 0 then 1::smallint else 0::smallint end "Одежда больших размеров",
    case when (count(p.*) filter(where p.category_new ilike '%Салон вечерней одежды%') ) > 0 then 1::smallint else 0::smallint end "Салон вечерней одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Секонд-хенд%') ) > 0 then 1::smallint else 0::smallint end "Секонд-хенд",
    case when (count(p.*) filter(where p.category_new ilike '%Спецодежда%') ) > 0 then 1::smallint else 0::smallint end "Спецодежда",
    case when (count(p.*) filter(where p.category_new ilike '%Свадебный салон%') ) > 0 then 1::smallint else 0::smallint end "Свадебный салон",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин парфюмерии и косметики%') ) > 0 then 1::smallint else 0::smallint end "Магазин парфюмерии и косметики",
    case when (count(p.*) filter(where p.category_new ilike '%Ароматовары%') ) > 0 then 1::smallint else 0::smallint end "Ароматовары",
    case when (count(p.*) filter(where p.category_new ilike '%Средства гигиены%') ) > 0 then 1::smallint else 0::smallint end "Средства гигиены",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин пива%') ) > 0 then 1::smallint else 0::smallint end "Магазин пива",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин подарков и сувениров%') ) > 0 then 1::smallint else 0::smallint end "Магазин подарков и сувениров",
    case when (count(p.*) filter(where p.category_new ilike '%Матрасы%') ) > 0 then 1::smallint else 0::smallint end "Матрасы",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин постельных принадлежностей%') ) > 0 then 1::smallint else 0::smallint end "Магазин постельных принадлежностей",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин кухонных ножей%') ) > 0 then 1::smallint else 0::smallint end "Магазин кухонных ножей",
    case when (count(p.*) filter(where p.category_new ilike '%Одноразовая посуда%') ) > 0 then 1::smallint else 0::smallint end "Одноразовая посуда",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин посуды%') ) > 0 then 1::smallint else 0::smallint end "Магазин посуды",
    case when (count(p.*) filter(where p.category_new ilike '%Диетические и диабетические продукты%') ) > 0 then 1::smallint else 0::smallint end "Диетические и диабетические продукты",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин продуктов%') ) > 0 then 1::smallint else 0::smallint end "Магазин продуктов",
    case when (count(p.*) filter(where p.category_new ilike '%Мороженое%') ) > 0 then 1::smallint else 0::smallint end "Мороженое",
    case when (count(p.*) filter(where p.category_new ilike '%Продукты глубокой заморозки%') ) > 0 then 1::smallint else 0::smallint end "Продукты глубокой заморозки",
    case when (count(p.*) filter(where p.category_new ilike '%Пищевые ингредиенты и специи%') ) > 0 then 1::smallint else 0::smallint end "Пищевые ингредиенты и специи",
    case when (count(p.*) filter(where p.category_new ilike '%Орехи, снеки, сухофрукты%') ) > 0 then 1::smallint else 0::smallint end "Орехи, снеки, сухофрукты",
    case when (count(p.*) filter(where p.category_new ilike '%Мёд и продукты пчеловодства%') ) > 0 then 1::smallint else 0::smallint end "Мёд и продукты пчеловодства",
    case when (count(p.*) filter(where p.category_new ilike '%Расходные материалы для оргтехники%') ) > 0 then 1::smallint else 0::smallint end "Расходные материалы для оргтехники",
    case when (count(p.*) filter(where p.category_new ilike '%Выставочный зал%') ) > 0 then 1::smallint else 0::smallint end "Выставочный зал",
    case when (count(p.*) filter(where p.category_new ilike '%Wi-Fi хот-спот%') ) > 0 then 1::smallint else 0::smallint end "Wi-Fi хот-спот",
    case when (count(p.*) filter(where p.category_new ilike '%Авиационное и аэродромное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Авиационное и аэродромное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Автобусные билеты%') ) > 0 then 1::smallint else 0::smallint end "Автобусные билеты",
    case when (count(p.*) filter(where p.category_new ilike '%Автобусный парк%') ) > 0 then 1::smallint else 0::smallint end "Автобусный парк",
    case when (count(p.*) filter(where p.category_new ilike '%Автодром%') ) > 0 then 1::smallint else 0::smallint end "Автодром",
    case when (count(p.*) filter(where p.category_new ilike '%Автоклуб%') ) > 0 then 1::smallint else 0::smallint end "Автоклуб",
    case when (count(p.*) filter(where p.category_new ilike '%Автоматизация документооборота%') ) > 0 then 1::smallint else 0::smallint end "Автоматизация документооборота",
    case when (count(p.*) filter(where p.category_new ilike '%Автоматизация производств%') ) > 0 then 1::smallint else 0::smallint end "Автоматизация производств",
    case when (count(p.*) filter(where p.category_new ilike '%Автоматизация ресторанов%') ) > 0 then 1::smallint else 0::smallint end "Автоматизация ресторанов",
    case when (count(p.*) filter(where p.category_new ilike '%Автоматические двери и ворота%') ) > 0 then 1::smallint else 0::smallint end "Автоматические двери и ворота",
    case when (count(p.*) filter(where p.category_new ilike '%Фармацевтическая компания%') ) > 0 then 1::smallint else 0::smallint end "Фармацевтическая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Фасовка товаров%') ) > 0 then 1::smallint else 0::smallint end "Фасовка товаров",
    case when (count(p.*) filter(where p.category_new ilike '%Фасовочно-упаковочное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Фасовочно-упаковочное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Фейерверки и пиротехника%') ) > 0 then 1::smallint else 0::smallint end "Фейерверки и пиротехника",
    case when (count(p.*) filter(where p.category_new ilike '%Фрезерная резка%') ) > 0 then 1::smallint else 0::smallint end "Фрезерная резка",
    case when (count(p.*) filter(where p.category_new ilike '%Химические реактивы%') ) > 0 then 1::smallint else 0::smallint end "Химические реактивы",
    case when (count(p.*) filter(where p.category_new ilike '%Химическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Химическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Хладокомбинат%') ) > 0 then 1::smallint else 0::smallint end "Хладокомбинат",
    case when (count(p.*) filter(where p.category_new ilike '%Хлебозавод%') ) > 0 then 1::smallint else 0::smallint end "Хлебозавод",
    case when (count(p.*) filter(where p.category_new ilike '%Хор, хоровая студия%') ) > 0 then 1::smallint else 0::smallint end "Хор, хоровая студия",
    case when (count(p.*) filter(where p.category_new ilike '%Хостинг%') ) > 0 then 1::smallint else 0::smallint end "Хостинг",
    case when (count(p.*) filter(where p.category_new ilike '%Художественная мастерская%') ) > 0 then 1::smallint else 0::smallint end "Художественная мастерская",
    case when (count(p.*) filter(where p.category_new ilike '%Художественный салон%') ) > 0 then 1::smallint else 0::smallint end "Художественный салон",
    case when (count(p.*) filter(where p.category_new ilike '%Цветные металлы%') ) > 0 then 1::smallint else 0::smallint end "Цветные металлы",
    case when (count(p.*) filter(where p.category_new ilike '%Чёрная металлургия%') ) > 0 then 1::smallint else 0::smallint end "Чёрная металлургия",
    case when (count(p.*) filter(where p.category_new ilike '%Швейная фабрика%') ) > 0 then 1::smallint else 0::smallint end "Швейная фабрика",
    case when (count(p.*) filter(where p.category_new ilike '%Широкоформатная печать%') ) > 0 then 1::smallint else 0::smallint end "Широкоформатная печать",
    case when (count(p.*) filter(where p.category_new ilike '%Шлюз%') ) > 0 then 1::smallint else 0::smallint end "Шлюз",
    case when (count(p.*) filter(where p.category_new ilike '%Шоу-рум%') ) > 0 then 1::smallint else 0::smallint end "Шоу-рум",
    case when (count(p.*) filter(where p.category_new ilike '%Штрафстоянка%') ) > 0 then 1::smallint else 0::smallint end "Штрафстоянка",
    case when (count(p.*) filter(where p.category_new ilike '%Экспедирование грузов%') ) > 0 then 1::smallint else 0::smallint end "Экспедирование грузов",
    case when (count(p.*) filter(where p.category_new ilike '%Экспресс-пункт замены масла%') ) > 0 then 1::smallint else 0::smallint end "Экспресс-пункт замены масла",
    case when (count(p.*) filter(where p.category_new ilike '%Элеватор%') ) > 0 then 1::smallint else 0::smallint end "Элеватор",
    case when (count(p.*) filter(where p.category_new ilike '%Электро- и бензоинструмент%') ) > 0 then 1::smallint else 0::smallint end "Электро- и бензоинструмент",
    case when (count(p.*) filter(where p.category_new ilike '%Электромонтажные работы%') ) > 0 then 1::smallint else 0::smallint end "Электромонтажные работы",
    case when (count(p.*) filter(where p.category_new ilike '%Электронная коммерция%') ) > 0 then 1::smallint else 0::smallint end "Электронная коммерция",
    case when (count(p.*) filter(where p.category_new ilike '%Электронная платёжная система%') ) > 0 then 1::smallint else 0::smallint end "Электронная платёжная система",
    case when (count(p.*) filter(where p.category_new ilike '%Элитная недвижимость%') ) > 0 then 1::smallint else 0::smallint end "Элитная недвижимость",
    case when (count(p.*) filter(where p.category_new ilike '%Энергетическая организация%') ) > 0 then 1::smallint else 0::smallint end "Энергетическая организация",
    case when (count(p.*) filter(where p.category_new ilike '%Энергетическое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Энергетическое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Энергосбережение и энергоаудит%') ) > 0 then 1::smallint else 0::smallint end "Энергосбережение и энергоаудит",
    case when (count(p.*) filter(where p.category_new ilike '%Энергоснабжение%') ) > 0 then 1::smallint else 0::smallint end "Энергоснабжение",
    case when (count(p.*) filter(where p.category_new ilike '%Ювелирное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Ювелирное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Аккумуляторы и зарядные устройства%') ) > 0 then 1::smallint else 0::smallint end "Аккумуляторы и зарядные устройства",
    case when (count(p.*) filter(where p.category_new ilike '%Звуковое и световое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Звуковое и световое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Электротехническая продукция%') ) > 0 then 1::smallint else 0::smallint end "Электротехническая продукция",
    case when (count(p.*) filter(where p.category_new ilike '%Клуб для детей и подростков%') ) > 0 then 1::smallint else 0::smallint end "Клуб для детей и подростков",
    case when (count(p.*) filter(where p.category_new ilike '%Учебный комбинат%') ) > 0 then 1::smallint else 0::smallint end "Учебный комбинат",
    case when (count(p.*) filter(where p.category_new ilike '%Учебный центр%') ) > 0 then 1::smallint else 0::smallint end "Учебный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Центр развития ребёнка%') ) > 0 then 1::smallint else 0::smallint end "Центр развития ребёнка",
    case when (count(p.*) filter(where p.category_new ilike '%Киношкола%') ) > 0 then 1::smallint else 0::smallint end "Киношкола",
    case when (count(p.*) filter(where p.category_new ilike '%Обучение%') ) > 0 then 1::smallint else 0::smallint end "Обучение",
    case when (count(p.*) filter(where p.category_new ilike '%Тиражирование дисков%') ) > 0 then 1::smallint else 0::smallint end "Тиражирование дисков",
    case when (count(p.*) filter(where p.category_new ilike '%Фотомагазин%') ) > 0 then 1::smallint else 0::smallint end "Фотомагазин",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин дисков BD, CD, DVD%') ) > 0 then 1::smallint else 0::smallint end "Магазин дисков BD, CD, DVD",
    case when (count(p.*) filter(where p.category_new ilike '%Музыкальный магазин%') ) > 0 then 1::smallint else 0::smallint end "Музыкальный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Электронные приборы и компоненты%') ) > 0 then 1::smallint else 0::smallint end "Электронные приборы и компоненты",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин радиодеталей%') ) > 0 then 1::smallint else 0::smallint end "Магазин радиодеталей",
    case when (count(p.*) filter(where p.category_new ilike '%Радиотехника%') ) > 0 then 1::smallint else 0::smallint end "Радиотехника",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин сантехники%') ) > 0 then 1::smallint else 0::smallint end "Магазин сантехники",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин семян%') ) > 0 then 1::smallint else 0::smallint end "Магазин семян",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин сумок и чемоданов%') ) > 0 then 1::smallint else 0::smallint end "Магазин сумок и чемоданов",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин суши и азиатских продуктов%') ) > 0 then 1::smallint else 0::smallint end "Магазин суши и азиатских продуктов",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин табака и курительных принадлежностей%') ) > 0 then 1::smallint else 0::smallint end "Магазин табака и курительных принадлежностей",
    case when (count(p.*) filter(where p.category_new ilike '%Трикотаж, трикотажные изделия%') ) > 0 then 1::smallint else 0::smallint end "Трикотаж, трикотажные изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин ткани%') ) > 0 then 1::smallint else 0::smallint end "Магазин ткани",
    case when (count(p.*) filter(where p.category_new ilike '%Нитки, пряжа%') ) > 0 then 1::smallint else 0::smallint end "Нитки, пряжа",
    case when (count(p.*) filter(where p.category_new ilike '%Производство и продажа тканей%') ) > 0 then 1::smallint else 0::smallint end "Производство и продажа тканей",
    case when (count(p.*) filter(where p.category_new ilike '%Технические ткани%') ) > 0 then 1::smallint else 0::smallint end "Технические ткани",
    case when (count(p.*) filter(where p.category_new ilike '%Прощальный зал%') ) > 0 then 1::smallint else 0::smallint end "Прощальный зал",
    case when (count(p.*) filter(where p.category_new ilike '%Шторы, карнизы%') ) > 0 then 1::smallint else 0::smallint end "Шторы, карнизы",
    case when (count(p.*) filter(where p.category_new ilike '%Очистители, увлажнители и ароматизаторы воздуха%') ) > 0 then 1::smallint else 0::smallint end "Очистители, увлажнители и ароматизаторы воздуха",
    case when (count(p.*) filter(where p.category_new ilike '%Москитные сетки%') ) > 0 then 1::smallint else 0::smallint end "Москитные сетки",
    case when (count(p.*) filter(where p.category_new ilike '%Искусственные растения и цветы%') ) > 0 then 1::smallint else 0::smallint end "Искусственные растения и цветы",
    case when (count(p.*) filter(where p.category_new ilike '%Цветочный рынок%') ) > 0 then 1::smallint else 0::smallint end "Цветочный рынок",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин цветов%') ) > 0 then 1::smallint else 0::smallint end "Магазин цветов",
    case when (count(p.*) filter(where p.category_new ilike '%Доставка цветов и букетов%') ) > 0 then 1::smallint else 0::smallint end "Доставка цветов и букетов",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин часов%') ) > 0 then 1::smallint else 0::smallint end "Магазин часов",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин чая и кофе%') ) > 0 then 1::smallint else 0::smallint end "Магазин чая и кофе",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин чулок и колготок%') ) > 0 then 1::smallint else 0::smallint end "Магазин чулок и колготок",
    case when (count(p.*) filter(where p.category_new ilike '%Ноутбуки и планшеты%') ) > 0 then 1::smallint else 0::smallint end "Ноутбуки и планшеты",
    case when (count(p.*) filter(where p.category_new ilike '%Игровые приставки%') ) > 0 then 1::smallint else 0::smallint end "Игровые приставки",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин электроники%') ) > 0 then 1::smallint else 0::smallint end "Магазин электроники",
    case when (count(p.*) filter(where p.category_new ilike '%GPS-навигаторы%') ) > 0 then 1::smallint else 0::smallint end "GPS-навигаторы",
    case when (count(p.*) filter(where p.category_new ilike '%Компьютерные аксессуары%') ) > 0 then 1::smallint else 0::smallint end "Компьютерные аксессуары",
    case when (count(p.*) filter(where p.category_new ilike '%Компьютерный магазин%') ) > 0 then 1::smallint else 0::smallint end "Компьютерный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для мобильных телефонов%') ) > 0 then 1::smallint else 0::smallint end "Товары для мобильных телефонов",
    case when (count(p.*) filter(where p.category_new ilike '%Электродвигатели%') ) > 0 then 1::smallint else 0::smallint end "Электродвигатели",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин электротранспорта%') ) > 0 then 1::smallint else 0::smallint end "Магазин электротранспорта",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин электротоваров%') ) > 0 then 1::smallint else 0::smallint end "Магазин электротоваров",
    case when (count(p.*) filter(where p.category_new ilike '%Светильники%') ) > 0 then 1::smallint else 0::smallint end "Светильники",
    case when (count(p.*) filter(where p.category_new ilike '%Электромонтажные и электроустановочные изделия%') ) > 0 then 1::smallint else 0::smallint end "Электромонтажные и электроустановочные изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Магия и эзотерика%') ) > 0 then 1::smallint else 0::smallint end "Магия и эзотерика",
    case when (count(p.*) filter(where p.category_new ilike '%Массажный салон%') ) > 0 then 1::smallint else 0::smallint end "Массажный салон",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинская лаборатория%') ) > 0 then 1::smallint else 0::smallint end "Медицинская лаборатория",
    case when (count(p.*) filter(where p.category_new ilike '%Перинатальный центр%') ) > 0 then 1::smallint else 0::smallint end "Перинатальный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Оздоровительный центр%') ) > 0 then 1::smallint else 0::smallint end "Оздоровительный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Урологический центр%') ) > 0 then 1::smallint else 0::smallint end "Урологический центр",
    case when (count(p.*) filter(where p.category_new ilike '%Мемориальная доска, закладной камень%') ) > 0 then 1::smallint else 0::smallint end "Мемориальная доска, закладной камень",
    case when (count(p.*) filter(where p.category_new ilike '%Металлоремонт%') ) > 0 then 1::smallint else 0::smallint end "Металлоремонт",
    case when (count(p.*) filter(where p.category_new ilike '%Меховое ателье%') ) > 0 then 1::smallint else 0::smallint end "Меховое ателье",
    case when (count(p.*) filter(where p.category_new ilike '%Мечеть%') ) > 0 then 1::smallint else 0::smallint end "Мечеть",
    case when (count(p.*) filter(where p.category_new ilike '%Отделение милиции%') ) > 0 then 1::smallint else 0::smallint end "Отделение милиции",
    case when (count(p.*) filter(where p.category_new ilike '%Страйкбол%') ) > 0 then 1::smallint else 0::smallint end "Страйкбол",
    case when (count(p.*) filter(where p.category_new ilike '%Центр дневного пребывания для пожилых%') ) > 0 then 1::smallint else 0::smallint end "Центр дневного пребывания для пожилых",
    case when (count(p.*) filter(where p.category_new ilike '%Фотоуслуги%') ) > 0 then 1::smallint else 0::smallint end "Фотоуслуги",
    case when (count(p.*) filter(where p.category_new ilike '%Дом культуры%') ) > 0 then 1::smallint else 0::smallint end "Дом культуры",
    case when (count(p.*) filter(where p.category_new ilike '%Дом отдыха%') ) > 0 then 1::smallint else 0::smallint end "Дом отдыха",
    case when (count(p.*) filter(where p.category_new ilike '%Дополнительное образование%') ) > 0 then 1::smallint else 0::smallint end "Дополнительное образование",
    case when (count(p.*) filter(where p.category_new ilike '%Духовное учебное заведение%') ) > 0 then 1::smallint else 0::smallint end "Духовное учебное заведение",
    case when (count(p.*) filter(where p.category_new ilike '%Железнодорожная станция%') ) > 0 then 1::smallint else 0::smallint end "Железнодорожная станция",
    case when (count(p.*) filter(where p.category_new ilike '%Железнодорожный вокзал%') ) > 0 then 1::smallint else 0::smallint end "Железнодорожный вокзал",
    case when (count(p.*) filter(where p.category_new ilike '%Женская консультация%') ) > 0 then 1::smallint else 0::smallint end "Женская консультация",
    case when (count(p.*) filter(where p.category_new ilike '%ЗАГС%') ) > 0 then 1::smallint else 0::smallint end "ЗАГС",
    case when (count(p.*) filter(where p.category_new ilike '%Зоомагазин%') ) > 0 then 1::smallint else 0::smallint end "Зоомагазин",
    case when (count(p.*) filter(where p.category_new ilike '%Ветеринарная аптека%') ) > 0 then 1::smallint else 0::smallint end "Ветеринарная аптека",
    case when (count(p.*) filter(where p.category_new ilike '%Звероферма%') ) > 0 then 1::smallint else 0::smallint end "Звероферма",
    case when (count(p.*) filter(where p.category_new ilike '%Зоопарк%') ) > 0 then 1::smallint else 0::smallint end "Зоопарк",
    case when (count(p.*) filter(where p.category_new ilike '%Интернет-кафе%') ) > 0 then 1::smallint else 0::smallint end "Интернет-кафе",
    case when (count(p.*) filter(where p.category_new ilike '%Игровой клуб%') ) > 0 then 1::smallint else 0::smallint end "Игровой клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление вывесок%') ) > 0 then 1::smallint else 0::smallint end "Изготовление вывесок",
    case when (count(p.*) filter(where p.category_new ilike '%БТИ%') ) > 0 then 1::smallint else 0::smallint end "БТИ",
    case when (count(p.*) filter(where p.category_new ilike '%Инспекция%') ) > 0 then 1::smallint else 0::smallint end "Инспекция",
    case when (count(p.*) filter(where p.category_new ilike '%Ипподром%') ) > 0 then 1::smallint else 0::smallint end "Ипподром",
    case when (count(p.*) filter(where p.category_new ilike '%Исправительное учреждение%') ) > 0 then 1::smallint else 0::smallint end "Исправительное учреждение",
    case when (count(p.*) filter(where p.category_new ilike '%Казначейство%') ) > 0 then 1::smallint else 0::smallint end "Казначейство",
    case when (count(p.*) filter(where p.category_new ilike '%Кальян-бар%') ) > 0 then 1::smallint else 0::smallint end "Кальян-бар",
    case when (count(p.*) filter(where p.category_new ilike '%Караоке-клуб%') ) > 0 then 1::smallint else 0::smallint end "Караоке-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%МРЭО%') ) > 0 then 1::smallint else 0::smallint end "МРЭО",
    case when (count(p.*) filter(where p.category_new ilike '%Сауна%') ) > 0 then 1::smallint else 0::smallint end "Сауна",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин сыров%') ) > 0 then 1::smallint else 0::smallint end "Магазин сыров",
    case when (count(p.*) filter(where p.category_new ilike '%Молочный магазин%') ) > 0 then 1::smallint else 0::smallint end "Молочный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Госавтоинспекция%') ) > 0 then 1::smallint else 0::smallint end "Госавтоинспекция",
    case when (count(p.*) filter(where p.category_new ilike '%Фонтан%') ) > 0 then 1::smallint else 0::smallint end "Фонтан",
    case when (count(p.*) filter(where p.category_new ilike '%Выставочный центр%') ) > 0 then 1::smallint else 0::smallint end "Выставочный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Музыкальное образование%') ) > 0 then 1::smallint else 0::smallint end "Музыкальное образование",
    case when (count(p.*) filter(where p.category_new ilike '%Музыкальный клуб%') ) > 0 then 1::smallint else 0::smallint end "Музыкальный клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Караоке-кабинка%') ) > 0 then 1::smallint else 0::smallint end "Караоке-кабинка",
    case when (count(p.*) filter(where p.category_new ilike '%Мука и крупы%') ) > 0 then 1::smallint else 0::smallint end "Мука и крупы",
    case when (count(p.*) filter(where p.category_new ilike '%Миграционные услуги%') ) > 0 then 1::smallint else 0::smallint end "Миграционные услуги",
    case when (count(p.*) filter(where p.category_new ilike '%МФЦ%') ) > 0 then 1::smallint else 0::smallint end "МФЦ",
    case when (count(p.*) filter(where p.category_new ilike '%Яйцо и мясо птицы%') ) > 0 then 1::smallint else 0::smallint end "Яйцо и мясо птицы",
    case when (count(p.*) filter(where p.category_new ilike '%Налоговая инспекция%') ) > 0 then 1::smallint else 0::smallint end "Налоговая инспекция",
    case when (count(p.*) filter(where p.category_new ilike '%Наркологическая клиника%') ) > 0 then 1::smallint else 0::smallint end "Наркологическая клиника",
    case when (count(p.*) filter(where p.category_new ilike '%Наружная реклама%') ) > 0 then 1::smallint else 0::smallint end "Наружная реклама",
    case when (count(p.*) filter(where p.category_new ilike '%Соляная пещера%') ) > 0 then 1::smallint else 0::smallint end "Соляная пещера",
    case when (count(p.*) filter(where p.category_new ilike '%Остеопатия%') ) > 0 then 1::smallint else 0::smallint end "Остеопатия",
    case when (count(p.*) filter(where p.category_new ilike '%Нетрадиционная медицина%') ) > 0 then 1::smallint else 0::smallint end "Нетрадиционная медицина",
    case when (count(p.*) filter(where p.category_new ilike '%НИИ%') ) > 0 then 1::smallint else 0::smallint end "НИИ",
    case when (count(p.*) filter(where p.category_new ilike '%Ногтевая студия%') ) > 0 then 1::smallint else 0::smallint end "Ногтевая студия",
    case when (count(p.*) filter(where p.category_new ilike '%Нотариусы%') ) > 0 then 1::smallint else 0::smallint end "Нотариусы",
    case when (count(p.*) filter(where p.category_new ilike '%Смотровая площадка%') ) > 0 then 1::smallint else 0::smallint end "Смотровая площадка",
    case when (count(p.*) filter(where p.category_new ilike '%Обучение мастеров для салонов красоты%') ) > 0 then 1::smallint else 0::smallint end "Обучение мастеров для салонов красоты",
    case when (count(p.*) filter(where p.category_new ilike '%Начальная школа%') ) > 0 then 1::smallint else 0::smallint end "Начальная школа",
    case when (count(p.*) filter(where p.category_new ilike '%Общеобразовательная школа%') ) > 0 then 1::smallint else 0::smallint end "Общеобразовательная школа",
    case when (count(p.*) filter(where p.category_new ilike '%Школа санаторного типа%') ) > 0 then 1::smallint else 0::smallint end "Школа санаторного типа",
    case when (count(p.*) filter(where p.category_new ilike '%Общественная организация%') ) > 0 then 1::smallint else 0::smallint end "Общественная организация",
    case when (count(p.*) filter(where p.category_new ilike '%Общественный фонд%') ) > 0 then 1::smallint else 0::smallint end "Общественный фонд",
    case when (count(p.*) filter(where p.category_new ilike '%Общественный пункт охраны порядка%') ) > 0 then 1::smallint else 0::smallint end "Общественный пункт охраны порядка",
    case when (count(p.*) filter(where p.category_new ilike '%Общественная группа%') ) > 0 then 1::smallint else 0::smallint end "Общественная группа",
    case when (count(p.*) filter(where p.category_new ilike '%Благотворительный фонд%') ) > 0 then 1::smallint else 0::smallint end "Благотворительный фонд",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин овощей и фруктов%') ) > 0 then 1::smallint else 0::smallint end "Магазин овощей и фруктов",
    case when (count(p.*) filter(where p.category_new ilike '%Управление исполнения наказаний%') ) > 0 then 1::smallint else 0::smallint end "Управ. исполнения наказаний",
    case when (count(p.*) filter(where p.category_new ilike '%Управляющая компания%') ) > 0 then 1::smallint else 0::smallint end "Управляющая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Управление образованием%') ) > 0 then 1::smallint else 0::smallint end "Управ. образованием",
    case when (count(p.*) filter(where p.category_new ilike '%Управление воздушным транспортом и его обслуживание%') ) > 0 then 1::smallint else 0::smallint end "Управ. воздушным транспортом и его обслуживание",
    case when (count(p.*) filter(where p.category_new ilike '%Управление недвижимостью%') ) > 0 then 1::smallint else 0::smallint end "Управ. недвижимостью",
    case when (count(p.*) filter(where p.category_new ilike '%Органы государственного надзора%') ) > 0 then 1::smallint else 0::smallint end "Органы государственного надзора",
    case when (count(p.*) filter(where p.category_new ilike '%Оргтехника%') ) > 0 then 1::smallint else 0::smallint end "Оргтехника",
    case when (count(p.*) filter(where p.category_new ilike '%Троллейбусная станция%') ) > 0 then 1::smallint else 0::smallint end "Троллейбусная станция",
    case when (count(p.*) filter(where p.category_new ilike '%Остановка общественного транспорта%') ) > 0 then 1::smallint else 0::smallint end "Остановка общественного транспорта",
    case when (count(p.*) filter(where p.category_new ilike '%Трамвайная станция%') ) > 0 then 1::smallint else 0::smallint end "Трамвайная станция",
    case when (count(p.*) filter(where p.category_new ilike '%Отделение полиции%') ) > 0 then 1::smallint else 0::smallint end "Отделение полиции",
    case when (count(p.*) filter(where p.category_new ilike '%Памятник, мемориал%') ) > 0 then 1::smallint else 0::smallint end "Памятник, мемориал",
    case when (count(p.*) filter(where p.category_new ilike '%Памятник технике%') ) > 0 then 1::smallint else 0::smallint end "Памятник технике",
    case when (count(p.*) filter(where p.category_new ilike '%Барбершоп%') ) > 0 then 1::smallint else 0::smallint end "Барбершоп",
    case when (count(p.*) filter(where p.category_new ilike '%Парикмахерская%') ) > 0 then 1::smallint else 0::smallint end "Парикмахерская",
    case when (count(p.*) filter(where p.category_new ilike '%Парк аттракционов%') ) > 0 then 1::smallint else 0::smallint end "Парк аттракционов",
    case when (count(p.*) filter(where p.category_new ilike '%Аттракцион%') ) > 0 then 1::smallint else 0::smallint end "Аттракцион",
    case when (count(p.*) filter(where p.category_new ilike '%Паспортные и миграционные службы%') ) > 0 then 1::smallint else 0::smallint end "Паспортные и миграционные службы",
    case when (count(p.*) filter(where p.category_new ilike '%Пейнтбол%') ) > 0 then 1::smallint else 0::smallint end "Пейнтбол",
    case when (count(p.*) filter(where p.category_new ilike '%Пенсионный фонд%') ) > 0 then 1::smallint else 0::smallint end "Пенсионный фонд",
    case when (count(p.*) filter(where p.category_new ilike '%Питомник животных%') ) > 0 then 1::smallint else 0::smallint end "Питомник животных",
    case when (count(p.*) filter(where p.category_new ilike '%Пиццерия%') ) > 0 then 1::smallint else 0::smallint end "Пиццерия",
    case when (count(p.*) filter(where p.category_new ilike '%Планетарий%') ) > 0 then 1::smallint else 0::smallint end "Планетарий",
    case when (count(p.*) filter(where p.category_new ilike '%Пластическая хирургия%') ) > 0 then 1::smallint else 0::smallint end "Пластическая хирургия",
    case when (count(p.*) filter(where p.category_new ilike '%Платёжный терминал%') ) > 0 then 1::smallint else 0::smallint end "Платёжный терминал",
    case when (count(p.*) filter(where p.category_new ilike '%Пляж%') ) > 0 then 1::smallint else 0::smallint end "Пляж",
    case when (count(p.*) filter(where p.category_new ilike '%Полиграфические услуги%') ) > 0 then 1::smallint else 0::smallint end "Полиграфические услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Поликлиника для взрослых%') ) > 0 then 1::smallint else 0::smallint end "Поликлиника для взрослых",
    case when (count(p.*) filter(where p.category_new ilike '%Пароходство, порт%') ) > 0 then 1::smallint else 0::smallint end "Пароходство, порт",
    case when (count(p.*) filter(where p.category_new ilike '%Морские и речные вокзалы%') ) > 0 then 1::smallint else 0::smallint end "Морские и речные вокзалы",
    case when (count(p.*) filter(where p.category_new ilike '%Морское агентство%') ) > 0 then 1::smallint else 0::smallint end "Морское агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Почтовое отделение%') ) > 0 then 1::smallint else 0::smallint end "Почтовое отделение",
    case when (count(p.*) filter(where p.category_new ilike '%Почтовый терминал%') ) > 0 then 1::smallint else 0::smallint end "Почтовый терминал",
    case when (count(p.*) filter(where p.category_new ilike '%Почтовые услуги%') ) > 0 then 1::smallint else 0::smallint end "Почтовые услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Монастырь%') ) > 0 then 1::smallint else 0::smallint end "Монастырь",
    case when (count(p.*) filter(where p.category_new ilike '%Ведущие праздников и мероприятий%') ) > 0 then 1::smallint else 0::smallint end "Ведущие праздников и мероприятий",
    case when (count(p.*) filter(where p.category_new ilike '%Аренда площадок для культурно-массовых мероприятий%') ) > 0 then 1::smallint else 0::smallint end "Аренда площадок для культурно-массовых мероприятий",
    case when (count(p.*) filter(where p.category_new ilike '%Праздничное агентство%') ) > 0 then 1::smallint else 0::smallint end "Праздничное агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Прачечная%') ) > 0 then 1::smallint else 0::smallint end "Прачечная",
    case when (count(p.*) filter(where p.category_new ilike '%Приют для животных%') ) > 0 then 1::smallint else 0::smallint end "Приют для животных",
    case when (count(p.*) filter(where p.category_new ilike '%Продукты питания оптом%') ) > 0 then 1::smallint else 0::smallint end "Продукты питания оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Продуктовый рынок%') ) > 0 then 1::smallint else 0::smallint end "Продуктовый рынок",
    case when (count(p.*) filter(where p.category_new ilike '%Мясная продукция оптом%') ) > 0 then 1::smallint else 0::smallint end "Мясная продукция оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Молочная продукция оптом%') ) > 0 then 1::smallint else 0::smallint end "Молочная продукция оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Кондитерские изделия оптом%') ) > 0 then 1::smallint else 0::smallint end "Кондитерские изделия оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Детское питание оптом%') ) > 0 then 1::smallint else 0::smallint end "Детское питание оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Хостел%') ) > 0 then 1::smallint else 0::smallint end "Хостел",
    case when (count(p.*) filter(where p.category_new ilike '%Овощи и фрукты оптом%') ) > 0 then 1::smallint else 0::smallint end "Овощи и фрукты оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Рыба и морепродукты оптом%') ) > 0 then 1::smallint else 0::smallint end "Рыба и морепродукты оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Прокуратура%') ) > 0 then 1::smallint else 0::smallint end "Прокуратура",
    case when (count(p.*) filter(where p.category_new ilike '%Промышленное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Промышленное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Психотерапевтическая помощь%') ) > 0 then 1::smallint else 0::smallint end "Психотерапевтическая помощь",
    case when (count(p.*) filter(where p.category_new ilike '%Социальная реабилитация%') ) > 0 then 1::smallint else 0::smallint end "Социальная реабилитация",
    case when (count(p.*) filter(where p.category_new ilike '%Экстренная социальная психологическая помощь%') ) > 0 then 1::smallint else 0::smallint end "Экстренная социальная психологическая помощь",
    case when (count(p.*) filter(where p.category_new ilike '%Психологическая служба%') ) > 0 then 1::smallint else 0::smallint end "Психологическая служба",
    case when (count(p.*) filter(where p.category_new ilike '%Психоневрологический интернат%') ) > 0 then 1::smallint else 0::smallint end "Психоневрологический интернат",
    case when (count(p.*) filter(where p.category_new ilike '%Пункт проката%') ) > 0 then 1::smallint else 0::smallint end "Пункт проката",
    case when (count(p.*) filter(where p.category_new ilike '%Прокат автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Прокат автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Прокат велосипедов%') ) > 0 then 1::smallint else 0::smallint end "Прокат велосипедов",
    case when (count(p.*) filter(where p.category_new ilike '%Клуб виртуальной реальности%') ) > 0 then 1::smallint else 0::smallint end "Клуб виртуальной реальности",
    case when (count(p.*) filter(where p.category_new ilike '%Роллердром%') ) > 0 then 1::smallint else 0::smallint end "Роллердром",
    case when (count(p.*) filter(where p.category_new ilike '%Скейт-парк%') ) > 0 then 1::smallint else 0::smallint end "Скейт-парк",
    case when (count(p.*) filter(where p.category_new ilike '%Казино, игорный дом%') ) > 0 then 1::smallint else 0::smallint end "Казино, игорный дом",
    case when (count(p.*) filter(where p.category_new ilike '%Аквапарк%') ) > 0 then 1::smallint else 0::smallint end "Аквапарк",
    case when (count(p.*) filter(where p.category_new ilike '%Развлекательный центр%') ) > 0 then 1::smallint else 0::smallint end "Развлекательный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Аэротруба%') ) > 0 then 1::smallint else 0::smallint end "Аэротруба",
    case when (count(p.*) filter(where p.category_new ilike '%Батутный центр%') ) > 0 then 1::smallint else 0::smallint end "Батутный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Верёвочный парк%') ) > 0 then 1::smallint else 0::smallint end "Верёвочный парк",
    case when (count(p.*) filter(where p.category_new ilike '%Детские игровые залы и площадки%') ) > 0 then 1::smallint else 0::smallint end "Детские игровые залы и площадки",
    case when (count(p.*) filter(where p.category_new ilike '%Анимация%') ) > 0 then 1::smallint else 0::smallint end "Анимация",
    case when (count(p.*) filter(where p.category_new ilike '%Канатная дорога, фуникулёр%') ) > 0 then 1::smallint else 0::smallint end "Канатная дорога, фуникулёр",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинская реабилитация%') ) > 0 then 1::smallint else 0::smallint end "Медицинская реабилитация",
    case when (count(p.*) filter(where p.category_new ilike '%Регистрационная палата%') ) > 0 then 1::smallint else 0::smallint end "Регистрационная палата",
    case when (count(p.*) filter(where p.category_new ilike '%Модельное агентство%') ) > 0 then 1::smallint else 0::smallint end "Модельное агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Рекламное агентство%') ) > 0 then 1::smallint else 0::smallint end "Рекламное агентство",
    case when (count(p.*) filter(where p.category_new ilike '%PR-агентство%') ) > 0 then 1::smallint else 0::smallint end "PR-агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Интернет-маркетинг%') ) > 0 then 1::smallint else 0::smallint end "Интернет-маркетинг",
    case when (count(p.*) filter(where p.category_new ilike '%Кастинг агентство%') ) > 0 then 1::smallint else 0::smallint end "Кастинг агентство",
    case when (count(p.*) filter(where p.category_new ilike '%Религиозное объединение%') ) > 0 then 1::smallint else 0::smallint end "Религиозное объединение",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт аудиотехники и видеотехники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт аудиотехники и видеотехники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт бытовой техники%') ) > 0 then 1::smallint else 0::smallint end "Ремонт бытовой техники",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт кожи%') ) > 0 then 1::smallint else 0::smallint end "Ремонт кожи",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт обуви%') ) > 0 then 1::smallint else 0::smallint end "Ремонт обуви",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт одежды%') ) > 0 then 1::smallint else 0::smallint end "Ремонт одежды",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин приданого%') ) > 0 then 1::smallint else 0::smallint end "Магазин приданого",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт телефонов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт телефонов",
    case when (count(p.*) filter(where p.category_new ilike '%Ремонт сумок и чемоданов%') ) > 0 then 1::smallint else 0::smallint end "Ремонт сумок и чемоданов",
    case when (count(p.*) filter(where p.category_new ilike '%Ресторан%') ) > 0 then 1::smallint else 0::smallint end "Ресторан",
    case when (count(p.*) filter(where p.category_new ilike '%Ритуальные принадлежности%') ) > 0 then 1::smallint else 0::smallint end "Ритуальные принадлежности",
    case when (count(p.*) filter(where p.category_new ilike '%Ритуальные услуги%') ) > 0 then 1::smallint else 0::smallint end "Ритуальные услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление памятников и надгробий%') ) > 0 then 1::smallint else 0::smallint end "Изготовление памятников и надгробий",
    case when (count(p.*) filter(where p.category_new ilike '%Крематорий%') ) > 0 then 1::smallint else 0::smallint end "Крематорий",
    case when (count(p.*) filter(where p.category_new ilike '%Кремация животных%') ) > 0 then 1::smallint else 0::smallint end "Кремация животных",
    case when (count(p.*) filter(where p.category_new ilike '%Родильный дом%') ) > 0 then 1::smallint else 0::smallint end "Родильный дом",
    case when (count(p.*) filter(where p.category_new ilike '%Магазин рыбы и морепродуктов%') ) > 0 then 1::smallint else 0::smallint end "Магазин рыбы и морепродуктов",
    case when (count(p.*) filter(where p.category_new ilike '%Вещевой рынок%') ) > 0 then 1::smallint else 0::smallint end "Вещевой рынок",
    case when (count(p.*) filter(where p.category_new ilike '%Рынок%') ) > 0 then 1::smallint else 0::smallint end "Рынок",
    case when (count(p.*) filter(where p.category_new ilike '%Садовый инвентарь и техника%') ) > 0 then 1::smallint else 0::smallint end "Садовый инвентарь и техника",
    case when (count(p.*) filter(where p.category_new ilike '%Салон красоты%') ) > 0 then 1::smallint else 0::smallint end "Салон красоты",
    case when (count(p.*) filter(where p.category_new ilike '%Солярий%') ) > 0 then 1::smallint else 0::smallint end "Солярий",
    case when (count(p.*) filter(where p.category_new ilike '%Контактные линзы%') ) > 0 then 1::smallint else 0::smallint end "Контактные линзы",
    case when (count(p.*) filter(where p.category_new ilike '%Салон оптики%') ) > 0 then 1::smallint else 0::smallint end "Салон оптики",
    case when (count(p.*) filter(where p.category_new ilike '%Салон связи%') ) > 0 then 1::smallint else 0::smallint end "Салон связи",
    case when (count(p.*) filter(where p.category_new ilike '%Медицинский туризм%') ) > 0 then 1::smallint else 0::smallint end "Медицинский туризм",
    case when (count(p.*) filter(where p.category_new ilike '%Санаторий%') ) > 0 then 1::smallint else 0::smallint end "Санаторий",
    case when (count(p.*) filter(where p.category_new ilike '%Сантехника оптом%') ) > 0 then 1::smallint else 0::smallint end "Сантехника оптом",
    case when (count(p.*) filter(where p.category_new ilike '%Светотехника%') ) > 0 then 1::smallint else 0::smallint end "Светотехника",
    case when (count(p.*) filter(where p.category_new ilike '%Секс-шоп%') ) > 0 then 1::smallint else 0::smallint end "Секс-шоп",
    case when (count(p.*) filter(where p.category_new ilike '%Семейное консультирование%') ) > 0 then 1::smallint else 0::smallint end "Семейное консультирование",
    case when (count(p.*) filter(where p.category_new ilike '%Синагога%') ) > 0 then 1::smallint else 0::smallint end "Синагога",
    case when (count(p.*) filter(where p.category_new ilike '%Скорая медицинская помощь%') ) > 0 then 1::smallint else 0::smallint end "Скорая медицинская помощь",
    case when (count(p.*) filter(where p.category_new ilike '%Детская скорая помощь%') ) > 0 then 1::smallint else 0::smallint end "Детская скорая помощь",
    case when (count(p.*) filter(where p.category_new ilike '%Перевозка больных%') ) > 0 then 1::smallint else 0::smallint end "Перевозка больных",
    case when (count(p.*) filter(where p.category_new ilike '%Жанровая скульптура%') ) > 0 then 1::smallint else 0::smallint end "Жанровая скульптура",
    case when (count(p.*) filter(where p.category_new ilike '%Следственный комитет%') ) > 0 then 1::smallint else 0::smallint end "Следственный комитет",
    case when (count(p.*) filter(where p.category_new ilike '%Служба знакомств%') ) > 0 then 1::smallint else 0::smallint end "Служба знакомств",
    case when (count(p.*) filter(where p.category_new ilike '%Православный храм%') ) > 0 then 1::smallint else 0::smallint end "Православный храм",
    case when (count(p.*) filter(where p.category_new ilike '%Совет депутатов%') ) > 0 then 1::smallint else 0::smallint end "Совет депутатов",
    case when (count(p.*) filter(where p.category_new ilike '%Патронажная служба%') ) > 0 then 1::smallint else 0::smallint end "Патронажная служба",
    case when (count(p.*) filter(where p.category_new ilike '%Социальная служба%') ) > 0 then 1::smallint else 0::smallint end "Социальная служба",
    case when (count(p.*) filter(where p.category_new ilike '%Центр занятости%') ) > 0 then 1::smallint else 0::smallint end "Центр занятости",
    case when (count(p.*) filter(where p.category_new ilike '%Флоатинг%') ) > 0 then 1::smallint else 0::smallint end "Флоатинг",
    case when (count(p.*) filter(where p.category_new ilike '%Специализированная больница%') ) > 0 then 1::smallint else 0::smallint end "Специализированная больница",
    case when (count(p.*) filter(where p.category_new ilike '%Спортбар%') ) > 0 then 1::smallint else 0::smallint end "Спортбар",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивная школа%') ) > 0 then 1::smallint else 0::smallint end "Спортивная школа",
    case when (count(p.*) filter(where p.category_new ilike '%Мотошкола%') ) > 0 then 1::smallint else 0::smallint end "Мотошкола",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивная база%') ) > 0 then 1::smallint else 0::smallint end "Спортивная база",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивно-развлекательный центр%') ) > 0 then 1::smallint else 0::smallint end "Спортивно-развлекательный центр",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивный клуб, секция%') ) > 0 then 1::smallint else 0::smallint end "Спортивный клуб, секция",
    case when (count(p.*) filter(where p.category_new ilike '%Киберспорт%') ) > 0 then 1::smallint else 0::smallint end "Киберспорт",
    case when (count(p.*) filter(where p.category_new ilike '%Кайтсёрфинг%') ) > 0 then 1::smallint else 0::smallint end "Кайтсёрфинг",
    case when (count(p.*) filter(where p.category_new ilike '%Виндсёрфинг%') ) > 0 then 1::smallint else 0::smallint end "Виндсёрфинг",
    case when (count(p.*) filter(where p.category_new ilike '%Вейк-клуб%') ) > 0 then 1::smallint else 0::smallint end "Вейк-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Сквош-клуб%') ) > 0 then 1::smallint else 0::smallint end "Сквош-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Кёрлинг-клуб%') ) > 0 then 1::smallint else 0::smallint end "Кёрлинг-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Скалодром%') ) > 0 then 1::smallint else 0::smallint end "Скалодром",
    case when (count(p.*) filter(where p.category_new ilike '%Сапсёрфинг%') ) > 0 then 1::smallint else 0::smallint end "Сапсёрфинг",
    case when (count(p.*) filter(where p.category_new ilike '%Мотодром%') ) > 0 then 1::smallint else 0::smallint end "Мотодром",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивный комплекс%') ) > 0 then 1::smallint else 0::smallint end "Спортивный комплекс",
    case when (count(p.*) filter(where p.category_new ilike '%Спортплощадка, воркаут%') ) > 0 then 1::smallint else 0::smallint end "Спортплощадка, воркаут",
    case when (count(p.*) filter(where p.category_new ilike '%Станция переливания крови%') ) > 0 then 1::smallint else 0::smallint end "Станция переливания крови",
    case when (count(p.*) filter(where p.category_new ilike '%Комбинат питания%') ) > 0 then 1::smallint else 0::smallint end "Комбинат питания",
    case when (count(p.*) filter(where p.category_new ilike '%Столовая%') ) > 0 then 1::smallint else 0::smallint end "Столовая",
    case when (count(p.*) filter(where p.category_new ilike '%Стоматологическая клиника%') ) > 0 then 1::smallint else 0::smallint end "Стоматологическая клиника",
    case when (count(p.*) filter(where p.category_new ilike '%Зуботехническая лаборатория%') ) > 0 then 1::smallint else 0::smallint end "Зуботехническая лаборатория",
    case when (count(p.*) filter(where p.category_new ilike '%Стоматологическая поликлиника%') ) > 0 then 1::smallint else 0::smallint end "Стоматологическая поликлиника",
    case when (count(p.*) filter(where p.category_new ilike '%Страховая компания%') ) > 0 then 1::smallint else 0::smallint end "Страховая компания",
    case when (count(p.*) filter(where p.category_new ilike '%Страхование автомобилей%') ) > 0 then 1::smallint else 0::smallint end "Страхование автомобилей",
    case when (count(p.*) filter(where p.category_new ilike '%Страховой брокер%') ) > 0 then 1::smallint else 0::smallint end "Страховой брокер",
    case when (count(p.*) filter(where p.category_new ilike '%Алюминий, алюминиевые конструкции%') ) > 0 then 1::smallint else 0::smallint end "Алюминий, алюминиевые конструкции",
    case when (count(p.*) filter(where p.category_new ilike '%Строительный магазин%') ) > 0 then 1::smallint else 0::smallint end "Строительный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Бетон, бетонные изделия%') ) > 0 then 1::smallint else 0::smallint end "Бетон, бетонные изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Водопроводное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Водопроводное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Водостоки и водосточные системы%') ) > 0 then 1::smallint else 0::smallint end "Водостоки и водосточные системы",
    case when (count(p.*) filter(where p.category_new ilike '%Водосчётчики, газосчётчики, теплосчётчики%') ) > 0 then 1::smallint else 0::smallint end "Водосчётчики, газосчётчики, теплосчётчики",
    case when (count(p.*) filter(where p.category_new ilike '%Газовое оборудование%') ) > 0 then 1::smallint else 0::smallint end "Газовое оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Графит, технические углероды%') ) > 0 then 1::smallint else 0::smallint end "Графит, технические углероды",
    case when (count(p.*) filter(where p.category_new ilike '%Грязезащитные покрытия%') ) > 0 then 1::smallint else 0::smallint end "Грязезащитные покрытия",
    case when (count(p.*) filter(where p.category_new ilike '%Декоративные покрытия%') ) > 0 then 1::smallint else 0::smallint end "Декоративные покрытия",
    case when (count(p.*) filter(where p.category_new ilike '%ЖБИ%') ) > 0 then 1::smallint else 0::smallint end "ЖБИ",
    case when (count(p.*) filter(where p.category_new ilike '%Изделия из камня%') ) > 0 then 1::smallint else 0::smallint end "Изделия из камня",
    case when (count(p.*) filter(where p.category_new ilike '%Изоляционные материалы%') ) > 0 then 1::smallint else 0::smallint end "Изоляционные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Керамическая плитка%') ) > 0 then 1::smallint else 0::smallint end "Керамическая плитка",
    case when (count(p.*) filter(where p.category_new ilike '%Кирпич%') ) > 0 then 1::smallint else 0::smallint end "Кирпич",
    case when (count(p.*) filter(where p.category_new ilike '%Клеящие вещества и материалы%') ) > 0 then 1::smallint else 0::smallint end "Клеящие вещества и материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Кованые изделия%') ) > 0 then 1::smallint else 0::smallint end "Кованые изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Ковровые покрытия%') ) > 0 then 1::smallint else 0::smallint end "Ковровые покрытия",
    case when (count(p.*) filter(where p.category_new ilike '%Комплектующие для окон%') ) > 0 then 1::smallint else 0::smallint end "Комплектующие для окон",
    case when (count(p.*) filter(where p.category_new ilike '%Компрессоры и компрессорное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Компрессоры и компрессорное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Крепёжные изделия%') ) > 0 then 1::smallint else 0::smallint end "Крепёжные изделия",
    case when (count(p.*) filter(where p.category_new ilike '%Кровля и кровельные материалы%') ) > 0 then 1::smallint else 0::smallint end "Кровля и кровельные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Лакокрасочные материалы%') ) > 0 then 1::smallint else 0::smallint end "Лакокрасочные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Ламинат%') ) > 0 then 1::smallint else 0::smallint end "Ламинат",
    case when (count(p.*) filter(where p.category_new ilike '%Лестницы и лестничные ограждения%') ) > 0 then 1::smallint else 0::smallint end "Лестницы и лестничные ограждения",
    case when (count(p.*) filter(where p.category_new ilike '%Линолеум%') ) > 0 then 1::smallint else 0::smallint end "Линолеум",
    case when (count(p.*) filter(where p.category_new ilike '%Металлоизделия%') ) > 0 then 1::smallint else 0::smallint end "Металлоизделия",
    case when (count(p.*) filter(where p.category_new ilike '%Металлоконструкции%') ) > 0 then 1::smallint else 0::smallint end "Металлоконструкции",
    case when (count(p.*) filter(where p.category_new ilike '%Металлообрабатывающее оборудование%') ) > 0 then 1::smallint else 0::smallint end "Металлообрабатывающее оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Металлообработка%') ) > 0 then 1::smallint else 0::smallint end "Металлообработка",
    case when (count(p.*) filter(where p.category_new ilike '%Металлопрокат%') ) > 0 then 1::smallint else 0::smallint end "Металлопрокат",
    case when (count(p.*) filter(where p.category_new ilike '%Напольные покрытия%') ) > 0 then 1::smallint else 0::smallint end "Напольные покрытия",
    case when (count(p.*) filter(where p.category_new ilike '%Насосы, насосное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Насосы, насосное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Натяжные и подвесные потолки%') ) > 0 then 1::smallint else 0::smallint end "Натяжные и подвесные потолки",
    case when (count(p.*) filter(where p.category_new ilike '%Облицовочные материалы%') ) > 0 then 1::smallint else 0::smallint end "Облицовочные материалы",
    case when (count(p.*) filter(where p.category_new ilike '%Окна%') ) > 0 then 1::smallint else 0::smallint end "Окна",
    case when (count(p.*) filter(where p.category_new ilike '%Опалубка%') ) > 0 then 1::smallint else 0::smallint end "Опалубка",
    case when (count(p.*) filter(where p.category_new ilike '%Оргстекло, поликарбонат%') ) > 0 then 1::smallint else 0::smallint end "Оргстекло, поликарбонат",
    case when (count(p.*) filter(where p.category_new ilike '%Стекло, стекольная продукция%') ) > 0 then 1::smallint else 0::smallint end "Стекло, стекольная продукция",
    case when (count(p.*) filter(where p.category_new ilike '%Стеклопластик%') ) > 0 then 1::smallint else 0::smallint end "Стеклопластик",
    case when (count(p.*) filter(where p.category_new ilike '%Стеклянные двери%') ) > 0 then 1::smallint else 0::smallint end "Стеклянные двери",
    case when (count(p.*) filter(where p.category_new ilike '%Строительная арматура%') ) > 0 then 1::smallint else 0::smallint end "Строительная арматура",
    case when (count(p.*) filter(where p.category_new ilike '%Строительная компания%') ) > 0 then 1::smallint else 0::smallint end "Строительная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Строительное оборудование и техника%') ) > 0 then 1::smallint else 0::smallint end "Строительное оборудование и техника",
    case when (count(p.*) filter(where p.category_new ilike '%Строительные конструкции%') ) > 0 then 1::smallint else 0::smallint end "Строительные конструкции",
    case when (count(p.*) filter(where p.category_new ilike '%Строительные леса%') ) > 0 then 1::smallint else 0::smallint end "Строительные леса",
    case when (count(p.*) filter(where p.category_new ilike '%Строительный инструмент%') ) > 0 then 1::smallint else 0::smallint end "Строительный инструмент",
    case when (count(p.*) filter(where p.category_new ilike '%Строительный рынок%') ) > 0 then 1::smallint else 0::smallint end "Строительный рынок",
    case when (count(p.*) filter(where p.category_new ilike '%Сухие строительные смеси%') ) > 0 then 1::smallint else 0::smallint end "Сухие строительные смеси",
    case when (count(p.*) filter(where p.category_new ilike '%Фанера%') ) > 0 then 1::smallint else 0::smallint end "Фанера",
    case when (count(p.*) filter(where p.category_new ilike '%Фасады и фасадные системы%') ) > 0 then 1::smallint else 0::smallint end "Фасады и фасадные системы",
    case when (count(p.*) filter(where p.category_new ilike '%Фурнитура для стеклянных конструкций%') ) > 0 then 1::smallint else 0::smallint end "Фурнитура для стеклянных конструкций",
    case when (count(p.*) filter(where p.category_new ilike '%Цемент%') ) > 0 then 1::smallint else 0::smallint end "Цемент",
    case when (count(p.*) filter(where p.category_new ilike '%Студия звукозаписи%') ) > 0 then 1::smallint else 0::smallint end "Студия звукозаписи",
    case when (count(p.*) filter(where p.category_new ilike '%Суд%') ) > 0 then 1::smallint else 0::smallint end "Суд",
    case when (count(p.*) filter(where p.category_new ilike '%Арбитражный суд%') ) > 0 then 1::smallint else 0::smallint end "Арбитражный суд",
    case when (count(p.*) filter(where p.category_new ilike '%Мировой судья%') ) > 0 then 1::smallint else 0::smallint end "Мировой судья",
    case when (count(p.*) filter(where p.category_new ilike '%Судебно-медицинская экспертиза%') ) > 0 then 1::smallint else 0::smallint end "Судебно-медицинская экспертиза",
    case when (count(p.*) filter(where p.category_new ilike '%Судебные приставы%') ) > 0 then 1::smallint else 0::smallint end "Судебные приставы",
    case when (count(p.*) filter(where p.category_new ilike '%Универмаг%') ) > 0 then 1::smallint else 0::smallint end "Универмаг",
    case when (count(p.*) filter(where p.category_new ilike '%Супермаркет%') ) > 0 then 1::smallint else 0::smallint end "Супермаркет",
    case when (count(p.*) filter(where p.category_new ilike '%Суши-бар%') ) > 0 then 1::smallint else 0::smallint end "Суши-бар",
    case when (count(p.*) filter(where p.category_new ilike '%Таможня%') ) > 0 then 1::smallint else 0::smallint end "Таможня",
    case when (count(p.*) filter(where p.category_new ilike '%Тату-салон%') ) > 0 then 1::smallint else 0::smallint end "Тату-салон",
    case when (count(p.*) filter(where p.category_new ilike '%Театр%') ) > 0 then 1::smallint else 0::smallint end "Театр",
    case when (count(p.*) filter(where p.category_new ilike '%Театральное и цирковое образование%') ) > 0 then 1::smallint else 0::smallint end "Театральное и цирковое образование",
    case when (count(p.*) filter(where p.category_new ilike '%Теннисный клуб%') ) > 0 then 1::smallint else 0::smallint end "Теннисный клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Теннисный корт%') ) > 0 then 1::smallint else 0::smallint end "Теннисный корт",
    case when (count(p.*) filter(where p.category_new ilike '%Типография%') ) > 0 then 1::smallint else 0::smallint end "Типография",
    case when (count(p.*) filter(where p.category_new ilike '%Стрелковый клуб, тир%') ) > 0 then 1::smallint else 0::smallint end "Стрелковый клуб, тир",
    case when (count(p.*) filter(where p.category_new ilike '%Слуховые аппараты%') ) > 0 then 1::smallint else 0::smallint end "Слуховые аппараты",
    case when (count(p.*) filter(where p.category_new ilike '%Изготовление протезно-ортопедических изделий%') ) > 0 then 1::smallint else 0::smallint end "Изготовление протезно-ортопедических изделий",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для инвалидов, средства реабилитации%') ) > 0 then 1::smallint else 0::smallint end "Товары для инвалидов, средства реабилитации",
    case when (count(p.*) filter(where p.category_new ilike '%Швейное оборудование%') ) > 0 then 1::smallint else 0::smallint end "Швейное оборудование",
    case when (count(p.*) filter(where p.category_new ilike '%Товары для творчества и рукоделия%') ) > 0 then 1::smallint else 0::smallint end "Товары для творчества и рукоделия",
    case when (count(p.*) filter(where p.category_new ilike '%Швейная фурнитура%') ) > 0 then 1::smallint else 0::smallint end "Швейная фурнитура",
    case when (count(p.*) filter(where p.category_new ilike '%Швейные и вязальные машины%') ) > 0 then 1::smallint else 0::smallint end "Швейные и вязальные машины",
    case when (count(p.*) filter(where p.category_new ilike '%Торговый центр%') ) > 0 then 1::smallint else 0::smallint end "Торговый центр",
    case when (count(p.*) filter(where p.category_new ilike '%Травмпункт%') ) > 0 then 1::smallint else 0::smallint end "Травмпункт",
    case when (count(p.*) filter(where p.category_new ilike '%Спортивный, тренажёрный зал%') ) > 0 then 1::smallint else 0::smallint end "Спортивный, тренажёрный зал",
    case when (count(p.*) filter(where p.category_new ilike '%Тренинги%') ) > 0 then 1::smallint else 0::smallint end "Тренинги",
    case when (count(p.*) filter(where p.category_new ilike '%Кемпинг%') ) > 0 then 1::smallint else 0::smallint end "Кемпинг",
    case when (count(p.*) filter(where p.category_new ilike '%Турбаза%') ) > 0 then 1::smallint else 0::smallint end "Турбаза",
    case when (count(p.*) filter(where p.category_new ilike '%Отдых на ферме%') ) > 0 then 1::smallint else 0::smallint end "Отдых на ферме",
    case when (count(p.*) filter(where p.category_new ilike '%Турагентство%') ) > 0 then 1::smallint else 0::smallint end "Турагентство",
    case when (count(p.*) filter(where p.category_new ilike '%Экскурсии%') ) > 0 then 1::smallint else 0::smallint end "Экскурсии",
    case when (count(p.*) filter(where p.category_new ilike '%Туристический инфоцентр%') ) > 0 then 1::smallint else 0::smallint end "Туристический инфоцентр",
    case when (count(p.*) filter(where p.category_new ilike '%Гостиничный оператор%') ) > 0 then 1::smallint else 0::smallint end "Гостиничный оператор",
    case when (count(p.*) filter(where p.category_new ilike '%Бронирование гостиниц%') ) > 0 then 1::smallint else 0::smallint end "Бронирование гостиниц",
    case when (count(p.*) filter(where p.category_new ilike '%Туроператор%') ) > 0 then 1::smallint else 0::smallint end "Туроператор",
    case when (count(p.*) filter(where p.category_new ilike '%Училище%') ) > 0 then 1::smallint else 0::smallint end "Училище",
    case when (count(p.*) filter(where p.category_new ilike '%Филармония%') ) > 0 then 1::smallint else 0::smallint end "Филармония",
    case when (count(p.*) filter(where p.category_new ilike '%Оркестр%') ) > 0 then 1::smallint else 0::smallint end "Оркестр",
    case when (count(p.*) filter(where p.category_new ilike '%Оценочная компания%') ) > 0 then 1::smallint else 0::smallint end "Оценочная компания",
    case when (count(p.*) filter(where p.category_new ilike '%Бизнес-консалтинг%') ) > 0 then 1::smallint else 0::smallint end "Бизнес-консалтинг",
    case when (count(p.*) filter(where p.category_new ilike '%Финансовый консалтинг%') ) > 0 then 1::smallint else 0::smallint end "Финансовый консалтинг",
    case when (count(p.*) filter(where p.category_new ilike '%Фитнес-клуб%') ) > 0 then 1::smallint else 0::smallint end "Фитнес-клуб",
    case when (count(p.*) filter(where p.category_new ilike '%Фонд социального страхования%') ) > 0 then 1::smallint else 0::smallint end "Фонд социального страхования",
    case when (count(p.*) filter(where p.category_new ilike '%Аренда фотостудий%') ) > 0 then 1::smallint else 0::smallint end "Аренда фотостудий",
    case when (count(p.*) filter(where p.category_new ilike '%Фотостудия%') ) > 0 then 1::smallint else 0::smallint end "Фотостудия",
    case when (count(p.*) filter(where p.category_new ilike '%Фотошкола%') ) > 0 then 1::smallint else 0::smallint end "Фотошкола",
    case when (count(p.*) filter(where p.category_new ilike '%Химчистка%') ) > 0 then 1::smallint else 0::smallint end "Химчистка",
    case when (count(p.*) filter(where p.category_new ilike '%Чистка ковров%') ) > 0 then 1::smallint else 0::smallint end "Чистка ковров",
    case when (count(p.*) filter(where p.category_new ilike '%Центр йоги%') ) > 0 then 1::smallint else 0::smallint end "Центр йоги",
    case when (count(p.*) filter(where p.category_new ilike '%Центр повышения квалификации%') ) > 0 then 1::smallint else 0::smallint end "Центр повышения квалификации",
    case when (count(p.*) filter(where p.category_new ilike '%Центр профилактики СПИДа%') ) > 0 then 1::smallint else 0::smallint end "Центр профилактики СПИДа",
    case when (count(p.*) filter(where p.category_new ilike '%Армянская апостольская церковь%') ) > 0 then 1::smallint else 0::smallint end "Армянская апостольская церковь",
    case when (count(p.*) filter(where p.category_new ilike '%Иконописная мастерская%') ) > 0 then 1::smallint else 0::smallint end "Иконописная мастерская",
    case when (count(p.*) filter(where p.category_new ilike '%Часовня, памятный крест%') ) > 0 then 1::smallint else 0::smallint end "Часовня, памятный крест",
    case when (count(p.*) filter(where p.category_new ilike '%Протестантская церковь%') ) > 0 then 1::smallint else 0::smallint end "Протестантская церковь",
    case when (count(p.*) filter(where p.category_new ilike '%Цирк%') ) > 0 then 1::smallint else 0::smallint end "Цирк",
    case when (count(p.*) filter(where p.category_new ilike '%Частная школа%') ) > 0 then 1::smallint else 0::smallint end "Частная школа",
    case when (count(p.*) filter(where p.category_new ilike '%Шиномонтаж%') ) > 0 then 1::smallint else 0::smallint end "Шиномонтаж",
    case when (count(p.*) filter(where p.category_new ilike '%Школа для будущих мам%') ) > 0 then 1::smallint else 0::smallint end "Школа для будущих мам",
    case when (count(p.*) filter(where p.category_new ilike '%Школа-интернат%') ) > 0 then 1::smallint else 0::smallint end "Школа-интернат",
    case when (count(p.*) filter(where p.category_new ilike '%Школа искусств%') ) > 0 then 1::smallint else 0::smallint end "Школа искусств",
    case when (count(p.*) filter(where p.category_new ilike '%Школа танцев%') ) > 0 then 1::smallint else 0::smallint end "Школа танцев",
    case when (count(p.*) filter(where p.category_new ilike '%Экологическая организация%') ) > 0 then 1::smallint else 0::smallint end "Экологическая организация",
    case when (count(p.*) filter(where p.category_new ilike '%Экспертиза промышленной безопасности%') ) > 0 then 1::smallint else 0::smallint end "Экспертиза промышленной безопасности",
    case when (count(p.*) filter(where p.category_new ilike '%Патентные услуги%') ) > 0 then 1::smallint else 0::smallint end "Патентные услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Экспертиза%') ) > 0 then 1::smallint else 0::smallint end "Экспертиза",
    case when (count(p.*) filter(where p.category_new ilike '%Строительная экспертиза и технадзор%') ) > 0 then 1::smallint else 0::smallint end "Строительная экспертиза и технадзор",
    case when (count(p.*) filter(where p.category_new ilike '%Ювелирные камни%') ) > 0 then 1::smallint else 0::smallint end "Ювелирные камни",
    case when (count(p.*) filter(where p.category_new ilike '%Ювелирный магазин%') ) > 0 then 1::smallint else 0::smallint end "Ювелирный магазин",
    case when (count(p.*) filter(where p.category_new ilike '%Ювелирная мастерская%') ) > 0 then 1::smallint else 0::smallint end "Ювелирная мастерская",
    case when (count(p.*) filter(where p.category_new ilike '%Апостиль и легализация документов%') ) > 0 then 1::smallint else 0::smallint end "Апостиль и легализация документов",
    case when (count(p.*) filter(where p.category_new ilike '%Защита прав потребителя%') ) > 0 then 1::smallint else 0::smallint end "Защита прав потребителя",
    case when (count(p.*) filter(where p.category_new ilike '%Лицензирование%') ) > 0 then 1::smallint else 0::smallint end "Лицензирование",
    case when (count(p.*) filter(where p.category_new ilike '%Юридические услуги%') ) > 0 then 1::smallint else 0::smallint end "Юридические услуги",
    case when (count(p.*) filter(where p.category_new ilike '%Яхт-клуб%') ) > 0 then 1::smallint else 0::smallint end "Яхт-клуб"
from index2020.data_boundary b 
left join index2020.data_poi p using(id_gis)
group by b.id_gis, b.city, b.region
order by b.id_gis;
comment on table trash.city_all_rubrics_stat is 'Статистика по всем рубрикам Яндекса для городов РФ для Кати Пестряковой 04.03.2021';






























	