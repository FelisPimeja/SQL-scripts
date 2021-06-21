drop table if exists trash.a_zoning;
create table trash.a_zoning as 
select z.*, h.geom
from index2019.stat_zoning z
left join index2019.data_hexgrid h using(id)
where z.id_gis in (
	875,905,964,787,286,157,603,46,103,377
);
alter table trash.a_zoning add primary key(id);
create index on trash.a_zoning(id_gis);
create index on trash.a_zoning(pop);
create index on trash.a_zoning(z1_pop);
create index on trash.a_zoning(z2_sdz);
create index on trash.a_zoning(z3_odz);
create index on trash.a_zoning(mu_odz);
create index on trash.a_zoning(sbrbr_count);
create index on trash.a_zoning(area_ha);
create index on trash.a_zoning using gist(geom);



--create index on russia.roads_osm using hash(other_tags);
--create index on russia.roads_osm using gist(geom);
--create index on russia.roads_osm using gist((geom::geography));
