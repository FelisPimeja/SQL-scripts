create table tmp.mobilewalla_2 as 
select * from tmp.mobilewalla
where length(lat::numeric::text) >= 7
	and length(long::numeric::text) >= 7
--limit 1000
;



--create index on tmp.mobilewalla_2(ifa);
--create index on tmp.mobilewalla_2(asn);
create index on tmp.mobilewalla_2(bundle_id);
create index on tmp.mobilewalla_2(carrier);
create index on tmp.mobilewalla_2(datetime);
create index on tmp.mobilewalla_2(device_category);
create index on tmp.mobilewalla_2(device_name);
create index on tmp.mobilewalla_2(ip_address);
create index on tmp.mobilewalla_2(major_os);
create index on tmp.mobilewalla_2(city);
create index on tmp.mobilewalla_2(connection_type);
create index on tmp.mobilewalla_2(platform);
create index on tmp.mobilewalla_2(store_url);
--create index on tmp.mobilewalla_2 using gist(geom);
create index on tmp.mobilewalla_2 using gist((geom::geography));



drop table if exists tmp.mobilewalla_3; 
create table tmp.mobilewalla_3 as 
select
	ifa,
	asn,
--	bundle_id,
	carrier,
--	datetime
--	device_category,
--	device_name,
--	ip_address,
--	major_os,
--	city,
	connection_type,
--	platform,
--	store_url,
	st_removerepeatedpoints(st_makeline(geom order by to_timestamp(datetime, 'YYYY/MM/DD HH24:MI:SS')), 0.0001)::geometry(linestring, 4326) geom
from tmp.mobilewalla_2
group by 
	ifa,
	asn,
	carrier,
	connection_type
--limit 100
;


--create index on tmp.mobilewalla_3


create table tmp.mobilewalla_hex as 
select h.*, count(m.*) total_points
from russia.hexgrid_1ha h 
left join tmp.mobilewalla_2 m 
	on st_intersects(h.geom, m.geom)
group by h.id, h.geom;

alter table tmp.mobilewalla_hex add primary key(id);
create index on tmp.mobilewalla_hex (total_points);
create index on tmp.mobilewalla_hex using gist(geom);
	
	