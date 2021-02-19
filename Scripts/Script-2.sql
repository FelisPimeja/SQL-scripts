--create table tmp.iso_graph as
with
reproj_pnt as (select dist, st_transform(geom, 4326) geom from tmp.iso_from),

epsg_code as (
	select
		(case
			when z.utm_zone < 10
				then '3260' || z.utm_zone
			else '326' || z.utm_zone
		end)::int epsg
	from (select * from reproj_pnt limit 1) i
	join world.utm_zones z
	on st_intersects(i.geom, z.geom)
),

buffer as (select st_buffer(st_collect(geom)::geography, dist) geom from reproj_pnt group by dist),

road as (
	select 
		(row_number() over())::int id,
		h.geom
	from index2019.data_road h
	join buffer p
		on st_intersects(h.geom, p.geom)
),

road_point as (
	select (st_dumppoints(r.geom)).geom geom
	from reproj_pnt p
	left join road r
		on st_intersects(st_buffer(p.geom::geography, 250)::geometry, r.geom)
), 

road_point2 as (
	select r.geom
	from reproj_pnt p
	left join road_point r
		on st_intersects(st_buffer(p.geom::geography, 250)::geometry, r.geom)
), 

road2 as (
	select 
		(row_number() over())::int id,
		h.geom
	from index2019.data_road h
	join buffer p
		on st_intersects(h.geom, p.geom)
	union all 
	select 
		100500 + (row_number() over())::int id,
		st_makeline(p.geom, r.geom) geom
	from reproj_pnt p
	left join road_point2 r
		on 1 = 1
),

roads_re as (
	select id, st_transform(r.geom, e.epsg) geom
	from road2 r
	cross join epsg_code e
),

segments as (
	select
		(row_number() over())::int id,
		st_makeline(lag((pt).geom, 1, null) over (partition by id order by id, (pt).path), (pt).geom)::geometry geom
	from (select id, st_dumppoints(geom) as pt from roads_re) as a
)

select * from segments where geom is not null