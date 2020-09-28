drop table tmp.q_1051;
create table tmp.q_1051 as
select
	id,
	track_id,
	'2020-12-04'::date + date_time::time dt,
	speed,
	geom
from tmp.quazar_clipped
where id_gis = 1082
--limit 100
;
create index on tmp.q_1051 using gist(geom);
create index on tmp.q_1051(dt);
create index on tmp.q_1051(speed);




select
	cb.id_gis,
	cb.city "Город",
	cb.region_name "Субъект РФ",
	round((st_area(cb.geom::geography) / 10000)::numeric, 2) "Площадь города в границах, га",
	ba.area_ha "Площадь урбан. территории, га",
	p.pop2020 "Нас. по данным Росстата на 2020 г., чел.",
	coalesce((p.pop2020 / ba.area_ha)::int, 0) "Плотн. нас. урбан. части, чел./га",
	st_x(st_centroid(cb.geom)) x,
	st_y(st_centroid(cb.geom)) y,
from russia.city_boundary cb
left join russia.city_built_area_light ba using(id_gis)
left join index2020.data_pop_rosstat p using(id_gis)
where cb.geom is not null
order by p.pop2020 desc



update traffic.graph_match_points mp
	set cell_id  = gm.cell_id
	from traffic.google_matched gm
	where gm.road_segment_id = mp.road_segment_id

create index on traffic.graph_match_points(cell_id)
	
	
select * from traffic.graph_match_points mp where cell_id = 1

select id, geom from traffic.grid_russia_city where google_traffic is true

create table traffic.grid_test1 as select id, geom from traffic.grid_russia_city where id in(355,356)

alter table traffic.collect_data_test1 add primary key(road_segment_id)

select * from russia.city_boundary where city = 'Старая Русса'

truncate osm_test.depot