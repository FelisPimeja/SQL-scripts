/* Обрезка улиц по границам городов, присваивание id_gis */
drop table if exists routing.roads_clipped;
create table routing.roads_clipped as 
Select
    row_number() over() street_id,
	r.id,
	r.type,
	b.id_gis,
	r.name,
	r.tunnel,
	r.bridge,
	r.oneway,
	r.ref,
	r.access,
	r.class,
	r.lanes,
	r.surface,
	st_multi(
		case
			when st_within(r.geom, b.geom)
				then r.geom
			else
				case
					when st_isvalid(r.geom)
						and st_isvalid(b.geom) 
						then st_union(st_collectionextract(st_intersection(r.geom, b.geom), 2))
					else st_union(st_collectionextract(st_intersection(st_collectionextract(st_makevalid(r.geom), 2), st_collectionextract(st_makevalid(b.geom), 3)), 2))
				end
		end
	)::geometry(multilinestring, 4326) geom
from osm.roads_ru r
join index2019.data_boundary b 
	on st_intersects(b.geom, r.geom)
group by 
	r.id,
	r.type,
	b.id_gis,
	r.name,
	r.tunnel,
	r.bridge,
	r.oneway,
	r.ref,
	r.access,
	r.class,
	r.lanes,
	r.surface,
	b.geom,
	r.geom
order by b.id_gis, r.id;

/* Создание PK и индексов, кластеризация */
alter table routing.roads_clipped add primary key(street_id);
create index roads_clipped_geom_idx on routing.roads_clipped using gist(geom);
create index on routing.roads_clipped (type);
create index on routing.roads_clipped (id_gis);
create index on routing.roads_clipped (surface);
cluster routing.roads_clipped using roads_clipped_geom_idx;


/* Создание слоя с основной улично-дорожной сетью в границах городов */
drop materialized view if exists routing.roads_main_clipped cascade;
create materialized view routing.roads_main_clipped as
select * from routing.roads_clipped
where type in (
	'motorway',
	'motorway_link',
	'pedestrian',
	'primary',
	'primary_link',
	'secondary',
	'secondary_link',
	'tertiary',
	'tertiary_link',
	'trunk',
	'trunk_link',
	'unclassified',
	'road',
	'residential'
);

/* Создание PK и индексов, кластеризация */
create unique index on routing.roads_main_clipped (street_id);
create index roads_main_clipped_geom_idx on routing.roads_main_clipped using gist(geom);
create index on routing.roads_main_clipped (type);
create index on routing.roads_main_clipped (id_gis);
cluster routing.roads_main_clipped using roads_main_clipped_geom_idx;


