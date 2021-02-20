set startTimeRoad=%time%
:: Загрузка дорог
:: Время выполнения ~ мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - потестить и замерить новое время
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select highway type, name, lanes lane, max_speed, surface, access, other_tags, geometry from lines where highway is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.road_osm ^
 -nlt MULTILINESTRING ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение колонок lanes и maxspeed (почему-то работает только отдельным запросом)
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql "alter table russia.building_osm alter column lane type smallint using(case when lane ~ E'^\\d+$' then lane::smallint else null end);" 
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql "alter table russia.building_osm alter column maxspeed type smallint using(case when maxspeed = 'RU:urban' then 60 when maxspeed = 'RU:motorway' then 110 when maxspeed = 'RU:rural' then 90 when maxspeed = 'RU:living_street' then 20 when maxspeed ~ E'^\\d+$' then maxspeed::smallint else null end);"

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.road_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 2); ^
delete from russia.road_osm where st_isempty(geom) is true; ^
alter table russia.road_osm add column id_gis smallint, add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.road_osm using gist(geom);^
update russia.road_osm b set id_gis=bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.road_osm(type); ^
create index on russia.road_osm(id_gis); ^
create index on russia.road_osm(lane); ^
create index on russia.road_osm(max_speed); ^
create index on russia.road_osm(surface); ^
create index on russia.road_osm using gin(other_tags); ^
create index road_osm_geog_idx on russia.road_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.road_osm is 'Дороги (OpenStreetMap). Актуальность - %date%';^
comment on column russia.road_osm.id is 'Первичный ключ';^
comment on column russia.road_osm.type is 'Класс дороги по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:highway';^
comment on column russia.road_osm.lane is 'Общее число полос в обе стороны';^
comment on column russia.road_osm.name is 'Название дороги или улицы которая по ней проходит';^
comment on column russia.road_osm.max_speed is 'Максимальная разрешённая скорость для легковых автомобилей';^
comment on column russia.road_osm.surface is 'Материал покрытия дороги';^
comment on column russia.road_osm.other_tags is 'Прочие теги';^
comment on column russia.road_osm.geom is 'Геометрия';^
comment on column russia.road_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTimeRoad%
echo Загрузка Дорог Завершение: %time%
