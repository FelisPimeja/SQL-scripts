/* Подготовка пешеходных переходов от DC */
/* Время выполнения ~ 35 сек. на 390 тыс. точек */
drop table if exists index2020.data_crossing; 
create table index2020.data_crossing as 
	select 
		(row_number() over())::int id,
		b.id_gis,
		c.id_gis id_gis_orig,
		(case when c.src_id = 2 then 'yandex' when c.src_id = 3 then 'google' end)::varchar(6) src,
		c.x tile_x,
		c.y tile_y,
		c.zoom,
		c.url,
		c.bbox,
		c.score,
		st_setsrid(st_makepolygon(st_makeline(array[st_makepoint(c.cx0, c.cy0), st_makepoint(c.cx0, c.cy1), st_makepoint(c.cx1, c.cy1), st_makepoint(c.cx1, c.cy0), st_makepoint(c.cx0, c.cy0)])), 4326)::geometry(polygon, 4326) bbox_geom,		
		st_centroid(st_setsrid(st_makepolygon(st_makeline(array[st_makepoint(c.cx0, c.cy0), st_makepoint(c.cx0, c.cy1), st_makepoint(c.cx1, c.cy1), st_makepoint(c.cx1, c.cy0), st_makepoint(c.cx0, c.cy0)])), 4326))::geometry(point, 4326) geom		
		from tmp.tile_crosswalk_2_raw c
	left join index2020.data_boundary b 
		on st_intersects(b.geom, st_centroid(st_setsrid(st_makepolygon(st_makeline(array[st_makepoint(c.cx0, c.cy0), st_makepoint(c.cx0, c.cy1), st_makepoint(c.cx1, c.cy1), st_makepoint(c.cx1, c.cy0), st_makepoint(c.cx0, c.cy0)])), 4326)))
--	limit 100 -- дебаг
;

/* Индексы */
alter table index2020.data_crossing add primary key(id);
create index on index2020.data_crossing(id_gis);
create index on index2020.data_crossing(id_gis_orig);
create index on index2020.data_crossing(src);
create index on index2020.data_crossing(score);
create index on index2020.data_crossing using gist(geom);
create index on index2020.data_crossing using gist(bbox_geom);
create index on index2020.data_crossing using gist((geom::geography));


/* Комментарии */
comment on table index2020.data_crossing is 'Пешеходные переходы от команды DC';


/* Проверка на удалённость от графа улично-дорожной сети */
/* Время выполнения ~ 3 мин. */
drop table if exists index2020.data_crossing_2;
create table index2020.data_crossing_2 as 
	select 
		c.*,
		case 
			when r.id is not null then true::bool
			else false::bool
		end is_valid,
		case 
			when r.id is not null then null
			else 'Далее 10 м от ближайшей дороги'
		end invalidity_comment
	from index2020.data_crossing c
	left join index2020.data_road r
		on r.id_gis = c.id_gis 
			and st_dwithin(r.geom::geography, c.geom::geography, 10)
--	where c.id_gis = 777 -- дебаг
;
create index on index2020.data_crossing_2(id);
create index on index2020.data_crossing_2(id_gis);
create index on index2020.data_crossing_2(src);
create index on index2020.data_crossing_2(is_valid);
create index on index2020.data_crossing_2 using gist((geom::geography));


/* Проверка на дублирование точек Яндекс <-> Google (расстояние между точками менее 6 м.) */
/* Время выполнения ~ 1 мин. */
drop table if exists index2020.data_crossing_3;
create table index2020.data_crossing_3 as 
	select 
		c.id,
		c.id_gis,
		c.id_gis_orig,
		c.src,
		c.tile_x,
		c.tile_y,
		c.zoom,
		c.url,
		c.bbox,
		c.score,
		c.bbox_geom,
		c.geom,
		case 
			when c2.id is null then c.is_valid
			else false::bool
		end is_valid,
		case 
			when c2.id is null then c.invalidity_comment
			else 'Дубликат точки с другого снимка'
		end invalidity_comment
	from index2020.data_crossing_2 c
	left join index2020.data_crossing_2 c2
		on c.id_gis = c2.id_gis 
			and st_dwithin(c.geom::geography, c2.geom::geography, 6)
			and c.src <> c2.src
			and c.id > c2.id
			and c.is_valid is true 
			and c2.is_valid is true
--	where c.id_gis = 777 -- дебаг
;

/* Дальше было ручное переименование таблиц... и в итоге index2020.data_crossing_3 -> index2020.data_crossing */


