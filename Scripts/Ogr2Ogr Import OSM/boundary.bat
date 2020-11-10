set startTimeAdmin=%time%
:: Загрузка административных границ всех уровней
:: Время выполнения ~ 13 мин.
:: Загрузка всех границ для последующего разбора
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select boundary, admin_level, name, replace(wikipedia, ':', '.wikipedia.org/wiki/') wikipedia_link, wikidata wikidata_id, other_tags, geometry from multipolygons where type = 'boundary'" ^
 --config OSM_CONFIG_FILE "C:\Users\apetrov\git\SQL-scripts\Scripts\Ogr2Ogr Import OSM\osmconf.ini ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.osm_boundary_all ^
 -nlt MULTIPOLYGON ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,admin_level=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -wrapdateline ^
 -datelineoffset 15 ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка и обработка геометрии */ ^
update russia.osm_boundary_all set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 3); ^
delete from russia.osm_boundary_all where st_isempty(geom) is true; ^
/* Индексы */ ^
create index on russia.osm_boundary_all(boundary); ^
create index on russia.osm_boundary_all(admin_level); ^
create index on russia.osm_boundary_all(name); ^
create index on russia.osm_boundary_all(wikidata_id); ^
create index on russia.osm_boundary_all(wikipedia_link); ^
create index on russia.osm_boundary_all using gin(other_tags); ^
create index on russia.osm_boundary_all using gist(geom); ^
create index osm_admin_boundary_all_geog_idx on russia.osm_boundary_all using gist((geom::geography));" ^

:: Федеральные округа:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_admin_boundary_federal_district; ^
create table russia.osm_admin_boundary_federal_district as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where admin_level = 3; ^
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
create table russia.osm_admin_boundary_region as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where admin_level = 4; ^
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
"drop table if exists russia.osm_boundary_economic_region; ^
create table russia.osm_boundary_economic_region as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where boundary = 'economic'; ^
alter table russia.osm_boundary_economic_region add primary key(id); ^
/* Индексы */ ^
create index on russia.osm_boundary_economic_region(name); ^
create index on russia.osm_boundary_economic_region(wikidata_id); ^
create index on russia.osm_boundary_economic_region(wikipedia_link); ^
create index on russia.osm_boundary_economic_region using gin(other_tags); ^
create index on russia.osm_boundary_economic_region using gist(geom); ^
create index osm_boundary_economic_region_geog_idx on russia.osm_boundary_economic_region using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_boundary_economic_region is 'Административные границы Экономических районов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_boundary_economic_region.id is 'Первичный ключ'; ^
comment on column russia.osm_boundary_economic_region.name is 'Название Экономического района'; ^
comment on column russia.osm_boundary_economic_region.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_boundary_economic_region.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_boundary_economic_region.other_tags is 'Прочие теги'; ^
comment on column russia.osm_boundary_economic_region.geom is 'Геометрия';"

:: Военные округа:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_boundary_military_district; ^
create table russia.osm_boundary_military_district as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where boundary = 'military_district'; ^
alter table russia.osm_boundary_military_district add primary key(id); ^
/* Индексы */ ^
create index on russia.osm_boundary_military_district(name); ^
create index on russia.osm_boundary_military_district(wikidata_id); ^
create index on russia.osm_boundary_military_district(wikipedia_link); ^
create index on russia.osm_boundary_military_district using gin(other_tags); ^
create index on russia.osm_boundary_military_district using gist(geom); ^
create index osm_boundary_military_district_geog_idx on russia.osm_boundary_military_district using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_boundary_military_district is 'Административные границы Военных округов России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_boundary_military_district.id is 'Первичный ключ'; ^
comment on column russia.osm_boundary_military_district.name is 'Название Военного округа'; ^
comment on column russia.osm_boundary_military_district.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_boundary_military_district.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_boundary_military_district.other_tags is 'Прочие теги'; ^
comment on column russia.osm_boundary_military_district.geom is 'Геометрия';"

:: Часовые пояса:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_boundary_time_zone; ^
create table russia.osm_boundary_time_zone as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where boundary = 'timezone'; ^
alter table russia.osm_boundary_time_zone add primary key(id); ^
/* Индексы */ ^
--create index on russia.osm_boundary_time_zone(ref); ^
create index on russia.osm_boundary_time_zone(name); ^
create index on russia.osm_boundary_time_zone(wikidata_id); ^
create index on russia.osm_boundary_time_zone(wikipedia_link); ^
create index on russia.osm_boundary_time_zone using gin(other_tags); ^
create index on russia.osm_boundary_time_zone using gist(geom); ^
create index osm_boundary_time_zone_geog_idx on russia.osm_boundary_time_zone using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_boundary_time_zone is 'Часовые пояса на территории России  (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_boundary_time_zone.id is 'Первичный ключ'; ^
--comment on column russia.osm_boundary_time_zone.ref is 'Код часового пояса'; ^
comment on column russia.osm_boundary_time_zone.name is 'Название часового кояса'; ^
comment on column russia.osm_boundary_time_zone.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_boundary_time_zone.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_boundary_time_zone.other_tags is 'Прочие теги'; ^
comment on column russia.osm_boundary_time_zone.geom is 'Геометрия';"

:: Муниципальные образования первого уровня (Районы, городские и муниципальные округа и ЗАТО):
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_admin_boundary_municipal_level1; ^
create table russia.osm_admin_boundary_municipal_level1 as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where admin_level in (5, 6); ^
alter table russia.osm_admin_boundary_municipal_level1 add primary key(id); ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_municipal_level1(name); ^
create index on russia.osm_admin_boundary_municipal_level1(wikidata_id); ^
create index on russia.osm_admin_boundary_municipal_level1(wikipedia_link); ^
create index on russia.osm_admin_boundary_municipal_level1 using gin(other_tags); ^
create index on russia.osm_admin_boundary_municipal_level1 using gist(geom); ^
create index osm_admin_boundary_municipal_level1_geog_idx on russia.osm_admin_boundary_municipal_level1 using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_municipal_level1 is 'Административные границы муниципальных образований первого уровня (Районы, городские и муниципальные округа и ЗАТО): (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_municipal_level1.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_municipal_level1.name is 'Название образования'; ^
comment on column russia.osm_admin_boundary_municipal_level1.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_municipal_level1.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_municipal_level1.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_municipal_level1.geom is 'Геометрия';"

:: Муниципальные образования второго уровня (Городские и сельские поселения, внутригородские районы):
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"drop table if exists russia.osm_admin_boundary_municipal_level2; ^
create table russia.osm_admin_boundary_municipal_level2 as select (row_number() over())::int id, name, wikidata_id, wikipedia_link, other_tags, geom from russia.osm_boundary_all where admin_level = 8; ^
alter table russia.osm_admin_boundary_municipal_level2 add primary key(id); ^
/* Индексы */ ^
create index on russia.osm_admin_boundary_municipal_level2(name); ^
create index on russia.osm_admin_boundary_municipal_level2(wikidata_id); ^
create index on russia.osm_admin_boundary_municipal_level2(wikipedia_link); ^
create index on russia.osm_admin_boundary_municipal_level2 using gin(other_tags); ^
create index on russia.osm_admin_boundary_municipal_level2 using gist(geom); ^
create index osm_admin_boundary_municipal_level2_geog_idx on russia.osm_admin_boundary_municipal_level2 using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.osm_admin_boundary_municipal_level2 is 'Административные границы муниципальных образований второго уровня (Городские и сельские поселения, внутригородские районы): (OpenStreetMap). Актуальность - 15.08.2020'; ^
comment on column russia.osm_admin_boundary_municipal_level2.id is 'Первичный ключ'; ^
comment on column russia.osm_admin_boundary_municipal_level2.name is 'Название образования'; ^
comment on column russia.osm_admin_boundary_municipal_level2.wikipedia_link is 'Ссылка на статью в Википедии'; ^
comment on column russia.osm_admin_boundary_municipal_level2.wikidata_id is 'Ссылка на id элемента в Wikidata'; ^
comment on column russia.osm_admin_boundary_municipal_level2.other_tags is 'Прочие теги'; ^
comment on column russia.osm_admin_boundary_municipal_level2.geom is 'Геометрия';"

:: Удаляем russia.osm_boundary:
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql "drop table if exists russia.osm_boundary"

echo Загрузка Административных границ Начало: %startTimeAdmin%
echo Загрузка Административных границ Завершение: %time%

