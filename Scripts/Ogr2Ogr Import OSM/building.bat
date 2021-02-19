set startTimeRoad=%time%
:: Загрузка зданий
:: Время выполнения ~  мин.
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\kaliningrad-latest.osm.pbf" ^
 -sql "select (case when building = 'yes' then null else building end) type, name, building_levels level, addr_postcode postcode, null id_gis, addr_street street, addr_housenumber housenumber, other_tags, geometry from multipolygons where building is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.building_osm ^
 -nlt MULTIPOLYGON ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,id_gis=smallint,street=text,housenumber=text,postcode=text ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение колонки с этажностью (почему-то работает только отдельных запросом)
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql "alter table russia.building_osm alter column level type smallint  using(case when level ~ E'^\\d+$' then level::smallint else null end);"

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.building_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.building_osm where st_isempty(geom) is true; ^
alter table russia.building_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.building_osm using gist(geom);^
update russia.building_osm b set id_gis=bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.building_osm(type); ^
create index on russia.building_osm(id_gis); ^
create index on russia.building_osm(level); ^
create index on russia.building_osm(postcode); ^
create index on russia.building_osm(street); ^
create index on russia.building_osm(housenumber); ^
create index on russia.building_osm using gin(other_tags); ^
create index building_osm_geog_idx on russia.building_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.building_osm is 'Здания (OpenStreetMap). Актуальность - %date%';^
comment on column russia.building_osm.id is 'Первичный ключ';^
comment on column russia.building_osm.type is 'Тип здания по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:building';^
comment on column russia.building_osm.name is 'Название здания';^
comment on column russia.building_osm.level is 'Максимальная этажность';^
comment on column russia.building_osm.postcode is 'Почтовый код';^
comment on column russia.building_osm.street is 'Улица';^
comment on column russia.building_osm.housenumber is 'Номер дома';^
comment on column russia.building_osm.other_tags is 'Прочие теги';^
comment on column russia.building_osm.geom is 'Геометрия';^
comment on column russia.building_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTimeRoad%
echo Загрузка Дорог Завершение: %time%

