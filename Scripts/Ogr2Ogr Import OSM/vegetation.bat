set startTime=%time%
:: Загрузка озеленённых территорий
:: Время выполнения ~ 50 мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=%PGDB% user=%PGUSER% password=%PGPASSWORD host=%PGHOST% port=%PGPORT%" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select (case when leisure is not null then leisure when wetland is not null then wetland when natural is not null then natural when surface is not null then surface when landuse is not null then landuse end) type, name, access, null id_gis, other_tags, geometry from multipolygons where landuse in ('forest', 'grass', 'village_green', 'orchard', 'meadow', 'greenfield', 'recreation_ground') or natural in ('wood', 'heath', 'scrub', 'vineyard', 'wetland', 'grassland', 'fell', 'tundra') or leisure in ('garden', 'park') or surface = 'grass' or wetland in ('swamp', 'mangrove', 'bog', 'string_bog', 'fen') " ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.vegetation_osm ^
 -nlt MULTIPOLYGON ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,id_gis=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=%PGDB% user=%PGUSER% password=%PGPASSWORD host=%PGHOST% port=%PGPORT%" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.vegetation_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.vegetation_osm where st_isempty(geom) is true; ^
alter table russia.vegetation_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis), add column area_ha numeric; ^
create index on russia.vegetation_osm using gist(geom);^
update russia.vegetation_osm b set id_gis=bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
update russia.vegetation_osm set area_ha = round((st_area(geom::geography) / 10000)::numeric, 2); ^
/* Индексы */ ^
create index on russia.vegetation_osm(type); ^
create index on russia.vegetation_osm(id_gis); ^
create index on russia.vegetation_osm(name); ^
create index on russia.vegetation_osm(access); ^
create index on russia.vegetation_osm(area_ha); ^
create index on russia.vegetation_osm using gin(other_tags); ^
create index vegetation_osm_geog_idx on russia.vegetation_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.vegetation_osm is 'Озеленённые территории (OpenStreetMap). Актуальность - %date%';^
comment on column russia.vegetation_osm.id is 'Первичный ключ';^
comment on column russia.vegetation_osm.type is 'Тип зелени по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Vegetation';^
comment on column russia.vegetation_osm.name is 'Название';^
comment on column russia.vegetation_osm.access is 'Возможность доступа на территорию';^
comment on column russia.vegetation_osm.area_ha is 'Площадь, га'; ^
comment on column russia.vegetation_osm.other_tags is 'Прочие теги';^
comment on column russia.vegetation_osm.geom is 'Геометрия';^
comment on column russia.vegetation_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка озеленённых территорий Начало: %startTime%
echo Загрузка озеленённых территорий Завершение: %time%

