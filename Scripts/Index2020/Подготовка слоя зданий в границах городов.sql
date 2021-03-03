/* Выбираем здания для индекса из предварительно подготовленной выгрузки OpenStreetMap */
/* Время выполнения ~ 15 мин. */
drop table if exists index2020.data_building;
create table index2020.data_building as 
select
    (row_number() over())::int id,
    b."name"::text,
    b."type"::varchar(20),
    b."level" levels,
    round(st_area(b.geom::geography, true)::numeric) area_m,
    c.id_gis::smallint,
    b.geom
from index2020.data_boundary c 
join russia.building_osm b
	on st_intersects(b.geom, c.geom)
--where c.id_gis <= 100
;
alter table index2020.data_building add primary key(id);
create index on index2020.data_building(id_gis);
create index on index2020.data_building("name");
create index on index2020.data_building(levels);
create index on index2020.data_building(area_m);
create index on index2020.data_building using gist(geom);
create index on index2020.data_building using gist((geom::geography));

