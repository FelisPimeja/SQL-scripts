set startTimeRoad=%time%
:: Загрузка площадных водных объектов
:: Время выполнения ~ 20 мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=%PGDB% user=%PGUSER% password=%PGPASSWORD host=%PGHOST% port=%PGPORT%" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select (case when natural = 'wetland' then natural when landuse = 'reservoir' then landuse else water end) type, name, null id_gis, other_tags, geometry from multipolygons where natural in ('water', 'wetland') or landuse = 'reservoir' " ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.water_osm ^
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
update russia.water_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.water_osm where st_isempty(geom) is true; ^
alter table russia.water_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis), add column area_ha numeric; ^
create index on russia.water_osm using gist(geom);^
update russia.water_osm b set id_gis=bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
update russia.water_osm set area_ha = round((st_area(geom::geography) / 10000)::numeric, 2); ^
/* Индексы */ ^
create index on russia.water_osm(type); ^
create index on russia.water_osm(id_gis); ^
create index on russia.water_osm(name); ^
create index on russia.water_osm(area_ha); ^
create index on russia.water_osm using gin(other_tags); ^
create index water_osm_geog_idx on russia.water_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.water_osm is 'Площадные водные объекты (OpenStreetMap). Актуальность - %date%';^
comment on column russia.water_osm.id is 'Первичный ключ';^
comment on column russia.water_osm.type is 'Тип водного объекта по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/water';^
comment on column russia.water_osm.name is 'Название';^
comment on column russia.water_osm.area_ha is 'Площадь, га'; ^
comment on column russia.water_osm.other_tags is 'Прочие теги';^
comment on column russia.water_osm.geom is 'Геометрия';^
comment on column russia.water_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка площадных водных объектов Начало: %startTimeRoad%
echo Загрузка площадных водных объектов Завершение: %time%

