/* Статистика по наличие остановочных пунктов/станций/вокзалов в границах городов и приоритетных территорий развития (см. проект по Набережным в границах городов РФ) */
/* Время расчёта ~2 сек. */

/* Временная таблица с приоритетными территориями, обрезанными по границам городов */
drop table if exists priority_clipped;
create temp table priority_clipped as
select p.id, p.id_gis, st_intersection(b.geom, p.geom) geom
from index2019.data_boundary b
join embankment.priority_territory p
	on b.id_gis = p.id_gis
		and st_intersects(b.geom, p.geom);

create index on priority_clipped using gist(geom);
create index on priority_clipped(id_gis);

drop table if exists russia.rzd_city_stat; 
create table russia.rzd_city_stat as

/* Статистика по станциям в границах приоритетных территорий */
with priority as (
	select 
		p.id_gis,
		count(rs.id) filter(where rs.type = 'Остановочный пункт') count_platform, -- число остановочных пунктов в границах приоритетной территории
		count(rs.id) filter(where rs.type = 'Станция' and rsb.official_status is null) count_station, -- число станций без здания вокзала в границах границах приоритетной территории
		count(rs.id) filter(where rs.type = 'Станция' and rsb.official_status = 'вокзал') count_station_building_official, -- число станций со зданием вокзала (из списка РЖД) в границах границах приоритетной территории
		count(rs.id) filter(where rs.type = 'Станция' and rsb.official_status = 'станция со зданием') count_station_building_unofficial -- число станций со зданием вокзала (не из списка РЖД) в границах границах приоритетной территории
	from priority_clipped p
	join russia.rzd_railway_station rs
		on st_intersects(p.geom, rs.geom)
	left join russia.rzd_railway_station_building rsb -- присоединяем таблицу с вокзалами, т.к. информация о наличие ОКН вынесена в неё
		on rsb.station_id = rs.id
	group by p.id_gis
)

/* Статистика по станциям в границах городов + приоритетных территорий */
select 
	b.id_gis,
	b.city,
	b.region,
	count(rs.id) filter(where rs.type = 'Остановочный пункт') count_platform_city, -- число остановочных пунктов в границах города
	count(rs.id) filter(where rs.type = 'Станция' and rsb.official_status is null) count_station_city, -- число станций без здания вокзала в границах города
	count(rs.id) filter(where rs.type = 'Станция' and rsb.official_status = 'вокзал') count_station_building_official_city, -- число станций со зданием вокзала (из списка РЖД) в границах города
	count(rs.id) filter(where rs.type = 'Станция' and rsb.official_status = 'станция со зданием') count_station_building_unofficial_city, -- число станций со зданием вокзала (не из списка РЖД) в границах города
	count(rs.id) filter(where rsb.okn_native_id is not null and rsb.official_status = 'вокзал') count_okn_station_building_official_city, -- число станций со зданием вокзала (из списка РЖД) в качестве объекта культурного наследия в границах города
	count(rs.id) filter(where rsb.okn_native_id is not null and rsb.official_status = 'станция со зданием') count_okn_station_building_unofficial_city, -- число станций со зданием вокзала (не из списка РЖД) в качестве объекта культурного наследия в границах города
	coalesce(p.count_platform, 0) count_platform_priority, -- число остановочных пунктов в границах приоритетной территории
	coalesce(p.count_station, 0) count_station_priority, -- число станций без здания вокзала в границах приоритетной территории
	coalesce(p.count_station_building_official, 0) count_station_building_official_priority, -- число станций со зданием вокзала (из списка РЖД) в границах приоритетной территории	
	coalesce(p.count_station_building_unofficial, 0) count_station_building_unofficial_priority -- число станций со зданием вокзала (не из списка РЖД) в границах приоритетной территории	
from index2019.data_boundary b
left join russia.rzd_railway_station rs
	on b.id_gis = rs.id_gis 
left join russia.rzd_railway_station_building rsb -- присоединяем таблицу с вокзалами, т.к. информация о наличие ОКН вынесена в неё
	on rsb.station_id = rs.id 
left join priority p
	on p.id_gis = b.id_gis 
group by b.id_gis, b.city, b.region, p.count_platform, p.count_station, p.count_station_building_official, p.count_station_building_unofficial
order by b.id_gis;

/* Первичный ключ */
alter table russia.rzd_city_stat add primary key(id_gis);

/* Комментарии */
comment on table russia.rzd_city_stat is 'Статистика по наличие остановочных пунктов/станций/вокзалов в границах городов и приоритетных территорий развития (см. проект по Набережным в границах городов РФ)';
comment on column russia.rzd_city_stat.id_gis is 'id_gis города';
comment on column russia.rzd_city_stat.city is 'Город';
comment on column russia.rzd_city_stat.region is 'Субъект РФ';
comment on column russia.rzd_city_stat.count_platform_city is 'Число остановочных пунктов в границах города';
comment on column russia.rzd_city_stat.count_station_city is 'Число станций без здания вокзала в границах города';
comment on column russia.rzd_city_stat.count_station_building_official_city is 'Число станций со зданием вокзала (из списка РЖД) в границах города';
comment on column russia.rzd_city_stat.count_station_building_unofficial_city is 'Число станций со зданием вокзала (не из списка РЖД) в границах города';
comment on column russia.rzd_city_stat.count_okn_station_building_official_city is 'Число станций со зданием вокзала (из списка РЖД) в качестве объекта культурного наследия в границах города';
comment on column russia.rzd_city_stat.count_okn_station_building_unofficial_city is 'Число станций со зданием вокзала (не из списка РЖД) в качестве объекта культурного наследия в границах города';
comment on column russia.rzd_city_stat.count_platform_priority is 'Число остановочных пунктов в границах приоритетной территории';
comment on column russia.rzd_city_stat.count_station_priority is 'Число станций без здания вокзала в границах границах приоритетной территории';
comment on column russia.rzd_city_stat.count_station_building_official_priority is 'Число станций со зданием вокзала (из списка РЖД) в границах границах приоритетной территории';
comment on column russia.rzd_city_stat.count_station_building_unofficial_priority is 'Число станций со зданием вокзала (не из списка РЖД) в границах границах приоритетной территории';
