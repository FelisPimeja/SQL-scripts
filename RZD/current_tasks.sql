select distinct official_status from russia.rzd_railway_station_building;

update russia.rzd_railway_station_building 
	set head_office = 'ДЖВ'
	where official_status = 'вокзал';

-- !!! вокзалов ДЖВ 347 - 1 где-то потерялся. Надо найти.

update tmp.rzd_building_station_extended_list
	set head_office = 'ЦДПО';

-- сливаю таблицы вместе. Потом будет зачистка первой.
insert into russia.rzd_railway_station_building (
	name,
	address,
	opening_hours,
	head_office,
	geom
)
	select
		name,
		address,
		"opening hours",
		head_office,
		geom
	from tmp.rzd_building_station_extended_list;


-- проставляем id_gis новым вокзалам
update russia.rzd_railway_station_building rsb
	set id_gis = cb.id_gis
	from russia.city_boundary cb
	where st_intersects(rsb.geom, cb.geom)
		and rsb.id_gis is null;


-- переносим атрбуты со старых вокзальных зданий на новые поиском в радиусе 500 м.
update russia.rzd_railway_station_building rsbo
	set
		station_id = rsb.station_id,
		okn_native_id = rsb.okn_native_id,
		name_en  = rsb.name_en
	from (
		select 
			r1.id,
			r2.station_id,
			r2.okn_native_id,
			r2.name_en,
			r1.name,
			round(st_distance(r1.geom::geography, r2.geom::geography)::numeric) dist,
			r1.geom
		from russia.rzd_railway_station_building r1
		left join lateral (
			select id, station_id, okn_native_id, name_en, geom
			from russia.rzd_railway_station_building r2
			where st_dwithin(r1.geom::geography, r2.geom::geography, 500)
				and r1.id <> r2.id
				and r1.id_gis = r2.id_gis
				and r2.head_office is null
			order by r1.geom::geography <-> r2.geom::geography
			limit 1
			) r2 on true
		where r1.head_office = 'ЦДПО'
		) rsb
		where rsbo.id = rsb.id
			and rsbo.station_id is null;
	
	
-- переносим атрбуты со станций на новые вокзальные здания поиском в радиусе 500 м.
update russia.rzd_railway_station_building rsbo
	set
		station_id = rsb.station_id
	from (
		select 
			r1.id,
			r2.id station_id
		from russia.rzd_railway_station_building r1
		left join lateral (
			select id, geom
			from russia.rzd_railway_station r2
			where st_dwithin(r1.geom::geography, r2.geom::geography, 500)
				and r1.id <> r2.id
				and r1.id_gis = r2.id_gis
			order by r1.geom::geography <-> r2.geom::geography
			limit 1
			) r2 on true
		where r1.head_office = 'ЦДПО'
		and r1.station_id is null
		) rsb
		where rsbo.id = rsb.id
			and rsbo.station_id is null;
		

-- Удаляем старые дубликаты
delete from russia.rzd_railway_station_building
	where head_office is null 
		and station_id in (select station_id from russia.rzd_railway_station_building where head_office = 'ЦДПО');
		

	
-- Проставляем station_id для новых ЦДПО вокзалов:
update russia.rzd_railway_station_building rsbo
	set
		station_id = rsb.station_id
	from (
		select 
			r1.id,
			r2.id station_id
		from russia.rzd_railway_station_building r1
		left join lateral (
			select id, geom
			from russia.rzd_railway_station r2
			where st_dwithin(r1.geom::geography, r2.geom::geography, 500)
			order by r1.geom::geography <-> r2.geom::geography
			limit 1
			) r2 on true
		where r1.head_office = 'ЦДПО'
		and r1.station_id is null
		) rsb
		where rsbo.id = rsb.id
			and rsbo.station_id is null;

select * from russia.rzd_railway_station_building where head_office = 'ЦДПО' and station_id is null