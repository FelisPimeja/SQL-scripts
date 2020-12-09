drop table if exists cadastr2016.boundary_np;
create table cadastr2016.boundary_np as 
select
	(row_number() over())::int id,
	"BS_NAME" "name",
--	st_isvalid(st_geomfromtext("OBJ_WKT")) val
	"OBJ_WKT"--,
--	case 
--		when st_isvalid(st_geomfromtext("OBJ_WKT"))
--			then st_multi(st_setsrid(st_geomfromtext("OBJ_WKT"), 4326))
--		else null 
--	end geom
from cadastr2016.border
where st_isvalid(st_geomfromtext("OBJ_WKT"))
limit 70
;
alter table cadastr2016.boundary_np
	add primary key(id);
create index on cadastr2016.boundary_np(name);
create index on cadastr2016.boundary_np using gist(geom);
create index on cadastr2016.boundary_np using gist((st_centroid(geom)::geography));


select count(*) from russia.quater_stat_verify qsv 


drop table if exists cadastr2016.ter_zone;
create table cadastr2016.ter_zone as 
select
	(row_number() over())::int id,
	"TZ_ID" tz_id,
	"NAME" "name",
	"TZ_TYPE" tz_type,
	"TZ_DESC" tz_desc,
--	"CAD_N" block_ref,
	st_multi(st_setsrid(st_geomfromtext("OBJ_WKT"),4326))::geometry(multipolygon, 4326) geom
from cadastr2016.ter_zone_; --  where id between 20250 and 20300;
alter table cadastr2016.ter_zone add primary key(id);
create index on cadastr2016.ter_zone using gist(geom);
create index on cadastr2016.ter_zone ("name");
create index on cadastr2016.ter_zone (tz_id);
create index on cadastr2016.ter_zone (tz_type);
create index on cadastr2016.ter_zone (tz_desc);


delete from cadastr2016.border where id > 20000 and "OBJ_WKT" not like '%)'

select
	(row_number() over())::int id,
--	id,
	"TZ_ID" tz_id,
	"NAME" "name",
	"TZ_TYPE" tz_type,
	"TZ_DESC" tz_desc,
--	"OBJ_WKT"
--	"CAD_N" block_ref,
	st_multi(st_setsrid(st_geomfromtext("OBJ_WKT"),4326))::geometry(multipolygon, 4326) geom
from cadastr2016.ter_zone_   where id > 15000
	and "OBJ_WKT" not like '%)';


delete from cadastr2016.ter_zone_  where "OBJ_WKT" = ' ';
