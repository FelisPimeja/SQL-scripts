set startTimeAdmin=%time%
:: Загрузка административных границ всех уровней
:: Время выполнения ~ 13 мин.
:: Загрузка всех границ для последующего разбора
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select admin_level, name, replace(wikipedia, ':', '.wikipedia.org/wiki/') wikipedia_link, wikidata wikidata_id, other_tags, geometry from multipolygons where type = 'boundary' and admin_level is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.osm_admin_boundary_all ^
 -nlt MULTIPOLYGON ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,admin_level=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка и обработка геометрии */ ^
update russia.osm_admin_boundary_all set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.osm_admin_boundary_all where st_isempty(geom) is true; ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all(name); ^
create index on russia.osm_admin_boundary_all(wikidata_id); ^
create index on russia.osm_admin_boundary_all(wikipedia_link); ^
create index on russia.osm_admin_boundary_all using gin(other_tags); ^
create index on russia.osm_admin_boundary_all using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography));" ^

:: Федеральные округа:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_admin_boundary_federal_district; ^
create table russia.osm_admin_boundary_federal_district as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3; ^
alter table russia.osm_admin_boundary_federal_district add primary key(id); ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_federal_district(name); ^
create index on russia.osm_admin_boundary_federal_district(wikidata_id); ^
create index on russia.osm_admin_boundary_federal_district(wikipedia_link); ^
create index on russia.osm_admin_boundary_federal_district using gin(other_tags); ^
create index on russia.osm_admin_boundary_federal_district using gist(geom); ^
create index osm_admin_boundary_federal_district_geog_idx on russia.osm_admin_boundary_federal_district using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_federal_district is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_federal_district.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_federal_district.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_federal_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_federal_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_federal_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_federal_district.geom is 'Геометрия';" ^

:: Субъекты РФ:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_admin_boundary_region; ^
create table russia.osm_admin_boundary_region as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 4; ^
alter table russia.osm_admin_boundary_region add primary key(id); ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_region(name); ^
create index on russia.osm_admin_boundary_region(wikidata_id); ^
create index on russia.osm_admin_boundary_region(wikipedia_link); ^
create index on russia.osm_admin_boundary_region using gin(other_tags); ^
create index on russia.osm_admin_boundary_region using gist(geom); ^
create index osm_admin_boundary_region_geog_idx on russia.osm_admin_boundary_region using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_region is 'Административные границы Субъектов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_region.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_region.name is 'Название Субъекта РФ'; ^
comment on column russia.osm_admin_boundary_region.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_region.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_region.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_region.geom is 'Геометрия';"

:: Экономические районы:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"create table russia.osm_admin_boundary_all_economic_region as select name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3; ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all_economic_region(name); ^
create index on russia.osm_admin_boundary_all_economic_region(wikidata_id); ^
create index on russia.osm_admin_boundary_all_economic_region(wikipedia_link); ^
create index on russia.osm_admin_boundary_all_economic_region using gin(other_tags); ^
create index on russia.osm_admin_boundary_all_economic_region using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_all_economic_region is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_all_economic_region.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_all_economic_region.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_all_economic_region.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_all_economic_region.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_all_economic_region.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_all_economic_region.geom is 'Геометрия';"

:: Военные округа:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"create table russia.osm_admin_boundary_all_federal_district as select name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3 ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all_federal_district(name); ^
create index on russia.osm_admin_boundary_all_federal_district(wikidata_id); ^
create index on russia.osm_admin_boundary_all_federal_district(wikipedia_link); ^
create index on russia.osm_admin_boundary_all_federal_district using gin(other_tags); ^
create index on russia.osm_admin_boundary_all_federal_district using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_all_federal_district is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_all_federal_district.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_all_federal_district.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_all_federal_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_all_federal_district.geom is 'Геометрия';"

:: Экономические районы:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"create table russia.osm_admin_boundary_all_federal_district as select name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3 ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all_federal_district(name); ^
create index on russia.osm_admin_boundary_all_federal_district(wikidata_id); ^
create index on russia.osm_admin_boundary_all_federal_district(wikipedia_link); ^
create index on russia.osm_admin_boundary_all_federal_district using gin(other_tags); ^
create index on russia.osm_admin_boundary_all_federal_district using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_all_federal_district is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_all_federal_district.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_all_federal_district.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_all_federal_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_all_federal_district.geom is 'Геометрия';"

:: Часовые зоны:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"create table russia.osm_admin_boundary_all_federal_district as select name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3 ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all_federal_district(name); ^
create index on russia.osm_admin_boundary_all_federal_district(wikidata_id); ^
create index on russia.osm_admin_boundary_all_federal_district(wikipedia_link); ^
create index on russia.osm_admin_boundary_all_federal_district using gin(other_tags); ^
create index on russia.osm_admin_boundary_all_federal_district using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_all_federal_district is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_all_federal_district.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_all_federal_district.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_all_federal_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_all_federal_district.geom is 'Геометрия';"

:: Районы, городские и муниципальные округа и ЗАТО:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"create table russia.osm_admin_boundary_all_federal_district as select name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3 ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all_federal_district(name); ^
create index on russia.osm_admin_boundary_all_federal_district(wikidata_id); ^
create index on russia.osm_admin_boundary_all_federal_district(wikipedia_link); ^
create index on russia.osm_admin_boundary_all_federal_district using gin(other_tags); ^
create index on russia.osm_admin_boundary_all_federal_district using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_all_federal_district is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_all_federal_district.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_all_federal_district.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_all_federal_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_all_federal_district.geom is 'Геометрия';"


:: Городские и сельские поселения, внутригородские районы:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"create table russia.osm_admin_boundary_all_federal_district as select name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_admin_boundary_all where admin_level = 3 ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_all_federal_district(name); ^
create index on russia.osm_admin_boundary_all_federal_district(wikidata_id); ^
create index on russia.osm_admin_boundary_all_federal_district(wikipedia_link); ^
create index on russia.osm_admin_boundary_all_federal_district using gin(other_tags); ^
create index on russia.osm_admin_boundary_all_federal_district using gist(geom); ^
create index admin_boundary_geog_idx on russia.osm_admin_boundary_all using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_all_federal_district is 'Административные границы Федеральных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_all_federal_district.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_all_federal_district.name is 'Название Федерального округа'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_all_federal_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_all_federal_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_all_federal_district.geom is 'Геометрия';"

:: Удаляем russia.osm_admin_boundary_all:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql "drop table if exists russia.osm_admin_boundary_all"

echo Загрузка Административных границ Начало: %startTimeAdmin%
echo Загрузка Административных границ Завершение: %time%

