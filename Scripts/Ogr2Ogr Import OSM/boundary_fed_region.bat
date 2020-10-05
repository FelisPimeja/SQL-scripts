set startTimeAdmin=%time%
:: Загрузка административных границ
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select name, replace(wikipedia, ':', '.wikipedia.org/wiki/') wikipedia_link, wikidata wikidata_id, other_tags, geometry from multipolygons where type = 'boundary' and admin_level = '3'" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.osm_boundary_fed_region ^
 -nlt MULTIPOLYGON ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,admin_level=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка и обработка геометрии */ ^
update russia.osm_boundary_fed_region set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.osm_boundary_fed_region where st_isempty(geom) is true; ^
/* Индексы */ ^
create index on russia.osm_boundary_fed_region(name); ^
create index on russia.osm_boundary_fed_region(wikidata_id); ^
create index on russia.osm_boundary_fed_region(wikipedia_link); ^
create index on russia.osm_boundary_fed_region using gin(other_tags); ^
create index on russia.osm_boundary_fed_region using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_boundary_fed_region using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_boundary_fed_region is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_boundary_fed_region.id is 'Первичный ключ'; ^
comment on column russia.osm_boundary_fed_region.name is 'Название административно-территориального образования'; ^
comment on column russia.osm_boundary_fed_region.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_boundary_fed_region.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_boundary_fed_region.other_tags is 'Прочие теги'; ^
comment on column russia.osm_boundary_fed_region.geom is 'Геометрия';"

echo Загрузка Административных границ Начало: %startTimeAdmin%
echo Загрузка Административных границ Завершение: %time%

