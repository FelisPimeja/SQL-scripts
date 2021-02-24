set startTime=%time%
:: Загрузка линейных водных объектов
:: Время выполнения ~  мин.
:: todo - резать по границам городов, чтобы нормально присваивать id_gis
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select waterway type, name, (case when intermittent = 'yes' then true else false end) intermittent, null id_gis, null length_km, other_tags, geometry from lines where waterway is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.waterway_osm ^
 -nlt MULTILINESTRING ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,intermittent=bool,length_km=numeric,id_gis=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.waterway_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 2); ^
delete from russia.waterway_osm where st_isempty(geom) is true; ^
alter table russia.waterway_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.waterway_osm using gist(geom);^
update russia.waterway_osm b set id_gis = bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
update russia.waterway_osm length_km = round((st_length(geom::geography) / 10000)::numeric, 2); ^
/* Индексы */ ^
create index on russia.waterway_osm(type); ^
create index on russia.waterway_osm(id_gis); ^
create index on russia.waterway_osm(name); ^
create index on russia.waterway_osm(intermittent); ^
create index on russia.waterway_osm using gin(other_tags); ^
create index waterway_osm_geog_idx on russia.waterway_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.waterway_osm is 'Линейные водные объекты (OpenStreetMap). Актуальность - %date%'; ^
comment on column russia.waterway_osm.id is 'Первичный ключ'; ^
comment on column russia.waterway_osm.type is 'Тип водного объекта по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/water'; ^
comment on column russia.waterway_osm.name is 'Название водного объекта'; ^
comment on column russia.waterway_osm.intermittent is 'Пересыхающий водоток (да/нет)'; ^
comment on column russia.waterway_osm.other_tags is 'Прочие теги'; ^
comment on column russia.waterway_osm.geom is 'Геометрия'; ^
comment on column russia.waterway_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTime%
echo Загрузка Дорог Завершение: %time%
