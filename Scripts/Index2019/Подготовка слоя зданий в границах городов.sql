insert into index2019.data_building (
    name,
    type,
    levels,
    area_m,
    id_gis,
    id,
    geom
)

select
    b.name,
    b.type,
    b.levels,
    st_area(b.geom::geography, true) area_m,
    c.id_gis,
    row_number() over(),
    b.geom
from osm.buildings_ru b
join index2019.data_boundary c 
	on st_intersects(b.geom, c.geom);

cluster index2019.data_building using tmp_buildings_clipped_type_idx;
