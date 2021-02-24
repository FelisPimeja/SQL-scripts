set startTime=%time%
:: Загрузка железных дорог
<<<<<<< HEAD
:: Время выполнения ~ 5 мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select railway type, name, service, null id_gis, other_tags, geometry from lines where railway is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.railway_osm ^
 -nlt MULTILINESTRING ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,id_gis=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.railway_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 2); ^
delete from russia.railway_osm where st_isempty(geom) is true; ^
alter table russia.railway_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.railway_osm using gist(geom);^
update russia.railway_osm b set id_gis = bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.railway_osm(type); ^
create index on russia.railway_osm(id_gis); ^
create index on russia.railway_osm(name); ^
create index on russia.railway_osm(service); ^
create index on russia.railway_osm using gin(other_tags); ^
create index railway_osm_geog_idx on russia.railway_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.railway_osm is 'Железные дороги (OpenStreetMap). Актуальность - %date%';^
comment on column russia.railway_osm.id is 'Первичный ключ';^
comment on column russia.railway_osm.type is 'Тип железной дороги по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:railway';^
comment on column russia.railway_osm.name is 'Название дороги или улицы которая по ней проходит';^
comment on column russia.railway_osm.service is 'Тип сервисного жд пути. См. https://wiki.openstreetmap.org/wiki/Key:railway:service';^
comment on column russia.railway_osm.other_tags is 'Прочие теги';^
comment on column russia.railway_osm.geom is 'Геометрия';^
comment on column russia.railway_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка железных дорог Начало: %startTime%
echo Загрузка железных дорог Завершение: %time%
=======
:: Время выполнения ~  мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select railway type, name, service, null id_gis, other_tags, geometry from lines where railway is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.railway_osm ^
 -nlt MULTILINESTRING ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,id_gis=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.railway_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 2); ^
delete from russia.railway_osm where st_isempty(geom) is true; ^
alter table russia.railway_osm add column id_gis smallint, add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.railway_osm using gist(geom);^
update russia.railway_osm b set id_gis = bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.railway_osm(type); ^
create index on russia.railway_osm(id_gis); ^
create index on russia.railway_osm(name); ^
create index on russia.railway_osm(service); ^
create index on russia.railway_osm using gin(other_tags); ^
create index railway_osm_geog_idx on russia.railway_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.railway_osm is 'Железные дороги (OpenStreetMap). Актуальность - %date%';^
comment on column russia.railway_osm.id is 'Первичный ключ';^
comment on column russia.railway_osm.type is 'Тип железной дороги по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:railway';^
comment on column russia.railway_osm.name is 'Название дороги или улицы которая по ней проходит';^
comment on column russia.railway_osm.service is 'Тип сервисного жд пути. См. https://wiki.openstreetmap.org/wiki/Key:railway:service';^
comment on column russia.railway_osm.other_tags is 'Прочие теги';^
comment on column russia.railway_osm.geom is 'Геометрия';^
comment on column russia.railway_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTime%
echo Загрузка Дорог Завершение: %time%
>>>>>>> branch 'master' of https://github.com/FelisPimeja/SQL-scripts.git
