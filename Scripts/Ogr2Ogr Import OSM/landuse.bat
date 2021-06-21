set startTime=%time%
:: Загрузка землепользования
:: Время выполнения ~  35 мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - прогнать и замерить время проверить ссылки на wiki
:: todo - добавить military
:: todo - разобраться почему не подгружаются некоторые мосты и лэндюзы
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=10.168.22.29 port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select (case when landuse is not null then landuse when amenity is not null then amenity when leisure is not null then leisure when tourism is not null then tourism when place is not null then place when highway is not null then highway when area_highway is not null then area_highway when man_made is not null then man_made end) type, name, access, null id_gis, null area_ha, all_tags, geometry from multipolygons where ((landuse is not null and landuse not in ('forest', 'grass', 'village_green', 'orchard', 'meadow', 'greenfield', 'recreation_ground', 'reservoir') or (amenity is not null and building is null and (parking is null or parking != 'underground')) or (leisure in ('park','garden','nature_reserve','stadium','golf_course') and building is null)  or (tourism = 'zoo' and building is null) or (place = 'square') or (highway is not null) or (area_highway is not null) or (man_made = 'bridge')) and indoor is null and (layer is null or layer >= 0))" ^
 --config OSM_CONFIG_FILE "D:\apetrov\git\SQL-scripts\Scripts\Ogr2Ogr Import OSM\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.landuse_osm ^
 -nlt MULTIPOLYGON ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=all_tags=hstore,id_gis=smallint,access=text,area_ha=numeric ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=10.168.22.29 port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.landuse_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.landuse_osm where st_isempty(geom) is true; ^
create index on russia.landuse_osm using gist(geom); ^
update russia.landuse_osm b set id_gis = bn.id_gis from russia.city bn where st_intersects(b.geom, bn.geom); ^
update russia.landuse_osm set area_ha = round((st_area(geom::geography) / 10000)::numeric, 2); ^
/* Индексы */ ^
create index on russia.landuse_osm(type); ^
create index on russia.landuse_osm(id_gis); ^
create index on russia.landuse_osm(name); ^
create index on russia.landuse_osm(access); ^
create index on russia.landuse_osm(area_ha); ^
create index on russia.landuse_osm using gin(all_tags); ^
create index landuse_osm_geog_idx on russia.landuse_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.landuse_osm is 'Землепользования (OpenStreetMap). Актуальность - %date%'; ^
comment on column russia.landuse_osm.id is 'Первичный ключ'; ^
comment on column russia.landuse_osm.type is 'Тип землепользования по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:landuse'; ^
comment on column russia.landuse_osm.name is 'Название'; ^
comment on column russia.landuse_osm.access is 'Возможность доступа на территорию'; ^
comment on column russia.landuse_osm.area_ha is 'Площадь, га'; ^
comment on column russia.landuse_osm.all_tags is 'Прочие теги'; ^
comment on column russia.landuse_osm.geom is 'Геометрия'; ^
comment on column russia.landuse_osm.id_gis is 'id_gis города. Внешний ключ'; "


echo Загрузка Дорог Начало: %startTime%
echo Загрузка Дорог Завершение: %time%

