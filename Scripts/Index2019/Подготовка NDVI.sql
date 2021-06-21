/*
Переименование
Get-ChildItem -Filter "*.tif" -Recurse | Rename-Item -NewName {$_.name -replace 'tif','tiff' }
Get-ChildItem -Filter "*.tiff" -Recurse | Rename-Item -NewName {$_.name -replace '(\d+)( .*) (\d+-\d+-\d+.tiff)','$1_$3' }
*/

/*
Загрузка
Занимает ~ 4 часа:
raster2pgsql -s 3857 -I -C -M -Y -e "D:\tmp\imagery\*.tiff" -F -t 128x128 index2019.data_imagery | psql -d kbpvdb -U editor -h gisdb.strelkakb.ru -p 5433
*/

/* Создаём таблицу с метаинформацией по снимкам + контроль площади пересечения с границами (8 часов на всё про всё без кластеризации ndvi)*/
create materialized view index2019.data_imagery_info as 
	select
		b.id_gis,
		(to_date((substring(r.filename, '\d+_(\d+-\d+-\d+).tif+')), 'YYYY-MM-DD'))::date img_date,
		round(ST_Area((ST_Intersection(ST_Transform(ST_Envelope(ST_Collect(ST_Envelope(r.rast))), 4326), b.geom))::geography, true)::numeric, 2) area_intersection,
		round(ST_Area(b.geom::geography, true)::numeric, 2) area_boundary, 
		round((ST_Area((ST_Intersection(ST_Transform(ST_Envelope(ST_Collect(ST_Envelope(r.rast))), 4326), b.geom))::geography, true) / ST_Area(b.geom::geography, true))::numeric, 2) intersection_ratio,
		(ST_Transform(ST_Envelope(ST_Collect(ST_Envelope(r.rast))), 4326))::geometry(polygon, 4326) geom
	from index2019.data_imagery r
	join index2019.data_boundary b
		on b.id_gis = (substring(r.filename, '(\d*)_'))::smallint
	group by b.id_gis, img_date
	order by id_gis;

/* Индексы */
create unique index on index2019.data_imagery_info (id_gis);
create index on index2019.data_imagery_info using gist(geom);

/* Комментарии */
comment on materialized view index2019.stat_imagery_info is 'Служебная таблица сравнения экстентов границ городов и снимков NDVI';
comment on column index2019.data_imagery_info.img_date is 'Дата съёмки';
comment on column index2019.data_imagery_info.id_gis is 'Уникальный идентификатор города';
comment on column index2019.data_imagery_info.area_intersection is 'Площадь пересечения экстента снимка и границы города';
comment on column index2019.data_imagery_info.area_boundary is 'Площадь экстента города';
comment on column index2019.data_imagery_info.intersection_ratio is 'Соотношениие площадей пересечения экстента снимка и границы города (проверять если оличается от 1!!!)';
comment on column index2019.data_imagery_info.geom is 'Экстент снимка';


/* Считаем и векторизуем NDVI */
/* Обрезка, реклассификация, id_gis */
drop table if exists ndvi;
create temp table ndvi as 
select 
	r.rid,
	(substring(r.filename, '(\d+)_'))::smallint id_gis,
	st_reclass(
		st_clip(r.rast, st_transform(b.geom, 3857), 0, true),
		1,
		/* Каноническую реклассификацию пришлось временно закомментировать, чтобы компенсировать странности расчёта Sentinel Hub */
		/*'0-0.40):0, [0.4-0.45):40, [0.45-0.5):45, [0.5-0.55):50, [0.55-0.60):55, [0.60-0.65):60, [0.65-0.70):65, [0.70-0.75):70, [0.75-0.80):75, [0.80-0.85):80, [0.85-0.90):85, [0.90-0.95):90, [0.95-1):95, 1:100',*/
		'0-0.45]:0,	0.50:40, [0.55-0.60]:45, 0.65:50, 0.70:55, 0.75:55, 0.80:60, 0.85:65, 0.90:75, 0.95:80, 1:85',
		'8BUI',
		0
	) rast
from index2019.data_imagery r
join index2019.data_boundary b
	on b.id_gis = (substring(r.filename, '(\d+)_'))::smallint
		and st_intersects(r.rast, st_transform(b.geom, 3857))
--				and b.id_gis < 50 -- для дебага
--				and r.rid = 334 -- для дебага
;

/* Векторизация растра */
drop table if exists index2019.data_ndvi;
create table index2019.data_ndvi as 
select
	row_number() over() id,
	id_gis,
	val ndvi,
	ST_Area((St_Collect(ST_Transform(geom, 4326)))::geography, true)/10000 area_ha,
	(ST_Multi(ST_Buffer(St_Collect(ST_Transform(geom, 4326)), 0)))::geometry(MultiPolygon, 4326) geom
from (
	select
		rid,
		id_gis,
		(ST_DumpASPolygons(rast)).*
	from ndvi
) r
group by rid, id_gis, ndvi;

/* PK, индексы, кластеризация */
alter table index2019.data_ndvi add primary key (id);
create index on index2019.data_ndvi (id_gis);
create index on index2019.data_ndvi (ndvi);
create index on index2019.data_ndvi (area_ha);
create index on index2019.data_ndvi using gist(geom);
--cluster index2019.data_ndvi using data_ndvi_geom_idx;

/* Комментарии */
comment on table index2019.data_ndvi is 'Полигоны NDVI полученные векторизацией снимков';
comment on column index2019.data_ndvi.id_gis is 'Уникальный идентификатор города';
comment on column index2019.data_ndvi.ndvi is 'Минимальное значение NDVI для полигона';
comment on column index2019.data_ndvi.area_ha is 'Площадь полигона га.';
