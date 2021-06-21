set startTime=%time%
:: Загрузка "открытых пространств"
:: Время выполнения ~ 1.5 ч.
 ogr2ogr ^
 -f "GPKG" "D:\tmp\56\open_space.gpkg" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select * from points where place = 'square'" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config OGR_SQLITE_SYNCHRONOUS OFF ^
 -nln place_square_pnt ^
 -nlt POINT ^
 -progress ^
 -lco GEOMETRY_NAME=geom ^
 -lco FID=id ^
 -dialect SQLite ^
 -append

 ogr2ogr ^
 -f "GPKG" "D:\tmp\56\open_space.gpkg" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select * from multipolygons where place = 'square'" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config OGR_SQLITE_SYNCHRONOUS OFF ^
 -nln place_square_pol ^
 -nlt POLYGON ^
 -progress ^
 -lco GEOMETRY_NAME=geom ^
 -lco FID=id ^
 -dialect SQLite ^
 -append

 ogr2ogr ^
 -f "GPKG" "D:\tmp\56\open_space.gpkg" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select * from multipolygons where leisure in ('beach_resort', 'ice_rink', 'park', 'stadium', 'pitch', 'swimming_area', 'track')" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config OGR_SQLITE_SYNCHRONOUS OFF ^
 -nln leisure_pol ^
 -nlt POLYGON ^
 -progress ^
 -lco GEOMETRY_NAME=geom ^
 -lco FID=id ^
 -dialect SQLite ^
 -append

 ogr2ogr ^
 -f "GPKG" "D:\tmp\56\open_space.gpkg" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select * from lines where natural = 'tree row'" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config OGR_SQLITE_SYNCHRONOUS OFF ^
 -nln tree_row_lin ^
 -nlt POLYGON ^
 -progress ^
 -lco GEOMETRY_NAME=geom ^
 -lco FID=id ^
 -dialect SQLite ^
 -append

 ogr2ogr ^
 -f "GPKG" "D:\tmp\56\open_space.gpkg" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select * from lines where highway = 'pedestrian'" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config OGR_SQLITE_SYNCHRONOUS OFF ^
 -nln pedestrian_lin ^
 -nlt POLYGON ^
 -progress ^
 -lco GEOMETRY_NAME=geom ^
 -lco FID=id ^
 -dialect SQLite ^
 -append

 ogr2ogr ^
 -f "GPKG" "D:\tmp\56\open_space.gpkg" ^
 "D:\apetrov\Projects\Postgres\OSM\PBF\russia-latest.osm.pbf" ^
 -sql "select * from multipolygons where name like '%парк%' or name like '%сквер%' or name like '%аллея%' or name like '%площадь%'" ^
 --config OSM_CONFIG_FILE "D:\apetrov\Projects\Postgres\OSM\Osmconf\osmconf.ini" ^
 --config OGR_SQLITE_SYNCHRONOUS OFF ^
 -nln name_like_pol ^
 -nlt POLYGON ^
 -progress ^
 -lco GEOMETRY_NAME=geom ^
 -lco FID=id ^
 -dialect SQLite ^
 -append

echo Загрузка Открытых пространств Начало: %startTime%
echo Загрузка Открытых пространств Завершение: %time%

