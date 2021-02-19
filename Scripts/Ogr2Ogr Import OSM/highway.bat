set startTimeRoad=%time%
:: Загрузка дорог
:: Время выполнения ~ 70 мин.
 ogr2ogr ^
 -f PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select highway type, name, (case when lanes = '1' then 1 when lanes = '2' then 2 when lanes = '3' then 3 when lanes = '4' then 4 when lanes = '5' then 5 when lanes = '6' then 6 when lanes = '7' then 7 when lanes = '8' then 8 when lanes = '9' then 9 when lanes = '10' then 10 when lanes = '11' then 11 when lanes = '12' then 12 else null end) lane, (case when maxspeed = 'RU:urban' then 60 when maxspeed = 'RU:motorway' then 110 when maxspeed = 'RU:rural' then 90 when maxspeed = 'RU:living_street' then 20 when maxspeed = '5' then 5 when maxspeed = '10' then 10 when maxspeed = '15' then 15 when maxspeed = '20' then 20 when maxspeed = '25' then 25 when maxspeed = '30' then 30 when maxspeed = '35' then 35 when maxspeed = '40' then 40 when maxspeed = '45' then 45 when maxspeed = '50' then 50 when maxspeed = '55' then 55 when maxspeed = '60' then 60 when maxspeed = '65' then 65 when maxspeed = '70' then 70 when maxspeed = '75' then 75 when maxspeed = '80' then 80 when maxspeed = '85' then 85 when maxspeed = '90' then 90 when maxspeed = '95' then 95 when maxspeed = '100' then 100 when maxspeed = '105' then 105 when maxspeed = '110' then 110 when maxspeed = '115' then 115 when maxspeed = '120' then 120 when maxspeed = '125' then 125 when maxspeed = '130' then 130 when maxspeed = '135' then 135 when maxspeed = '140' then 140 when maxspeed = '145' then 145 when maxspeed = '150' then 150 else null end) max_speed, surface, other_tags, geometry from lines where highway is not null" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config PG_USE_COPY YES ^
 --config MAX_TMPFILE_SIZE 2048 ^
 -nln russia.roads_osm ^
 -nlt MULTILINESTRING ^
 -lco GEOMETRY_NAME=geom ^
 -lco SPATIAL_INDEX=NONE ^
 -lco COLUMN_TYPES=other_tags=hstore,lane=smallint,max_speed=smallint ^
 -lco FID=id ^
 -dialect SQLite ^
 -overwrite

:: Приведение, обработка, индексы и комментарии
ogr2ogr ^
 PostgreSQL PG:"dbname=kbpvdb user=editor password=pgeditor host=gisdb.strelkakb.ru port=5433" ^
 -sql ^
"/* Проверка геометрии, id_gis и площади */ ^
update russia.roads_osm set geom = st_collectionextract(st_makevalid(st_removerepeatedpoints(st_snaptogrid(geom, 0.0000001))), 2); ^
delete from russia.roads_osm where st_isempty(geom) is true; ^
alter table russia.roads_osm add column id_gis smallint, add constraint fk_id_gis foreign key(id_gis) references russia.city(id_gis); ^
create index on russia.roads_osm using gist(geom);^
update russia.roads_osm b set id_gis=bn.id_gis from russia.city bn where st_within(b.geom, bn.geom); ^
/* Индексы */ ^
create index on russia.roads_osm(type); ^
create index on russia.roads_osm(id_gis); ^
create index on russia.roads_osm(lane); ^
create index on russia.roads_osm(max_speed); ^
create index on russia.roads_osm(surface); ^
create index on russia.roads_osm using gin(other_tags); ^
create index roads_osm_geog_idx on russia.roads_osm using gist((geom::geography)); ^
/* Комментарии */ ^
comment on table russia.roads_osm is 'Дороги (OpenStreetMap). Актуальность - 15.08.2020';^
comment on column russia.roads_osm.id is 'Первичный ключ';^
comment on column russia.roads_osm.type is 'Класс дороги по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:highway';^
comment on column russia.roads_osm.lane is 'Общее число полос в обе стороны';^
comment on column russia.roads_osm.name is 'Название дороги или улицы которая по ней проходит';^
comment on column russia.roads_osm.max_speed is 'Максимальная разрешённая скорость для легковых автомобилей';^
comment on column russia.roads_osm.surface is 'Материал покрытия дороги';^
comment on column russia.roads_osm.other_tags is 'Прочие теги';^
comment on column russia.roads_osm.geom is 'Геометрия';^
comment on column russia.roads_osm.id_gis is 'id_gis города. Внешний ключ';"


echo Загрузка Дорог Начало: %startTimeRoad%
echo Загрузка Дорог Завершение: %time%
