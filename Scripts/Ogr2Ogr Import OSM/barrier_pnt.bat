set startTime=%time%
:: Загрузка точечных преград
<<<<<<< HEAD
:: Время выполнения ~ 4 мин.
=======
:: Время выполнения ~  мин.
>>>>>>> branch 'master' of https://github.com/FelisPimeja/SQL-scripts.git
:: todo - прогнать и замерить время проверить ссылки на wiki
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select barrier type, access, null id_gis, other_tags, geometry from points where barrier is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.barrier_pnt_osm ^
 -nlt POINT ^
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
update russia.barrier_pnt_osm set geom = st_snaptogrid(geom, 0.0000001); ^
delete from russia.barrier_pnt_osm where st_isempty(geom) is true; ^
alter table russia.barrier_pnt_osm add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.barrier_pnt_osm using gist(geom);^
update russia.barrier_pnt_osm b set id_gis = bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.barrier_pnt_osm(type); ^
create index on russia.barrier_pnt_osm(id_gis); ^
create index on russia.barrier_pnt_osm using gin(other_tags); ^
create index barrier_pnt_osm_geog_idx on russia.barrier_pnt_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.barrier_pnt_osm is 'Точечные преграды (OpenStreetMap). Актуальность - %date%'; ^
comment on column russia.barrier_pnt_osm.id is 'Первичный ключ'; ^
comment on column russia.barrier_pnt_osm.type is 'Тип преграды по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/barrier'; ^
comment on column russia.barrier_pnt_osm.other_tags is 'Прочие теги'; ^
comment on column russia.barrier_pnt_osm.geom is 'Геометрия'; ^
comment on column russia.barrier_pnt_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTime%
echo Загрузка Дорог Завершение: %time%
