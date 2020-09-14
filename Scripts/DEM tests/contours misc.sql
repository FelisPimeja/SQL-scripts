-- Новая таблица - горизонтали, обрезанные по границам городов + 1000 м. буфер
-- (после загрузки всех горизонталей в базу)
-- время выполнения ~ 1.5 часа !!!
drop table if exists boundary;
create temp table boundary as
select id_gis, st_buffer(geom::geography, 1000)::geometry geom
from russia.city_boundary
where st_y(st_centroid(geom)) < 60;
create index on boundary using gist(geom);

drop table if exists russia.city_contour_2m;
create table russia.city_contour_2m as
select 
	(row_number() over())::int id,
	b.id_gis::smallint,
	c.elevation::smallint,
	st_multi(case
		when st_within(c.geom, b.geom)
			then c.geom 
		else st_collectionextract(st_intersection(c.geom, b.geom), 2)
	end)::geometry(multilinestring, 4326) geom
from boundary b
join russia.contour_2m c
	on st_intersects(b.geom, c.geom);