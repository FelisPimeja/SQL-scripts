-- Slope
drop table if exists tmp.a1_slope;
create table tmp.a1_slope as 
select (row_number() over())::int rid, b.id_gis, b.city, st_slope(st_clip(st_union(r.rast), b.geom, -999), 1, '32BF', 'DEGRESS', 111120, FALSE::boolean) rast from russia.nasadem r
join (
	select cb.id_gis, cb.geom, cb.city
	from russia.city_boundary cb 
	join veb_rf.city c using(id_gis)
	where cb.id_gis = 991
	limit 1
) b 
	on st_intersects(r.rast, b.geom)
group by b.id_gis, b.city, b.geom;

alter table tmp.a1_slope add primary key(rid);



-- Hillshade
drop table if exists tmp.a1_hillshade;
create table tmp.a1_hillshade as 
select (row_number() over())::int rid, b.id_gis, b.city, st_hillshade(st_clip(st_union(r.rast), b.geom, -999), 1, '32BF', 3115, 45, 255, 111120, FALSE::boolean) rast from russia.nasadem r
join (
	select cb.id_gis, cb.geom, cb.city
	from russia.city_boundary cb 
	join veb_rf.city c using(id_gis)
	where cb.id_gis = 991
	limit 1
) b 
	on st_intersects(r.rast, b.geom)
group by b.id_gis, b.city, b.geom;

alter table tmp.a1_hillshade add primary key(rid);


