set startTime=%time%
:: Загрузка POI
<<<<<<< HEAD
:: Время выполнения ~ 4 мин.
=======
:: Время выполнения ~  мин.
>>>>>>> branch 'master' of https://github.com/FelisPimeja/SQL-scripts.git
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select amenity type, name, null id_gis, other_tags, geometry from points where amenity is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.poi_osm ^
 -nlt POINT ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,id_gis=smallint,name=text ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.poi_osm set geom = st_snaptogrid(geom, 0.0000001); ^
delete from russia.poi_osm where st_isempty(geom) is true; ^
alter table russia.poi_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.poi_osm using gist(geom);^
update russia.poi_osm b set id_gis = bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.poi_osm(type); ^
create index on russia.poi_osm(id_gis); ^
create index on russia.poi_osm(name); ^
create index on russia.poi_osm using gin(other_tags); ^
create index poi_osm_geog_idx on russia.poi_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.poi_osm is 'Точечные объекты POI (OpenStreetMap). Актуальность - %date%'; ^
comment on column russia.poi_osm.id is 'Первичный ключ'; ^
comment on column russia.poi_osm.type is 'Тип объекта POI по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:amenity'; ^
comment on column russia.poi_osm.name is 'Название объекта'; ^
comment on column russia.poi_osm.other_tags is 'Прочие теги'; ^
comment on column russia.poi_osm.geom is 'Геометрия'; ^
comment on column russia.poi_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTime%
echo Загрузка Дорог Завершение: %time%
