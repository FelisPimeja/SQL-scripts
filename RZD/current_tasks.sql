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


-- поиск nearest neighbour среди станций для дальнейшей фильтрации
update russia.rzd_railway_station_building rsbo
	set dist = rsb.dist
	from (
		select 
			r1.id,
			r1.name,
			round(st_distance(r1.geom::geography, r2.geom::geography)::numeric) dist,
			r1.geom
		from russia.rzd_railway_station_building r1
		left join lateral (
			select id, geom
			from russia.rzd_railway_station_building r2
			where st_dwithin(r1.geom::geography, r2.geom::geography, 10000)
				and r1.id <> r2.id
				and r1.id_gis = r2.id_gis
			order by r1.geom::geography <-> r2.geom::geography
			) r2 on true
		) rsb
		where rsbo.id = rsb.id
	