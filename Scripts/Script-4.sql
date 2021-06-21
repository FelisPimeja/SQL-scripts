/* Обрезка улиц по границам городов, присваивание id_gis */
/* Время выполнения ~ 48 мин. */
drop table if exists index2020.data_road;
create table index2020.data_road as 
Select
    row_number() over() id,
	r.type,
	b.id_gis,
	r.name,
	st_multi(
		case
			when st_within(r.geom, b.geom)
				then r.geom
			else st_intersection(r.geom, b.geom)
		end
	)::geometry(multilinestring, 4326) geom
from index2019.data_boundary b
join russia.roads_osm r
	on st_intersects(b.geom, r.geom)
		and r.type not in ('footway', 'steps', 'path', 'motorway', 'motorway_link', 'pedestrian', 'track')
		and (r.other_tags is null
			or ( -- Проверяем hstore на наличие пар ключ-значение
				not r.other_tags @> '"tunnel"=>"yes"' -- ... тоннели ...
				and not r.other_tags @> '"tunnel"=>"building_passage"'
				and not r.other_tags @> '"bridge"=>"yes"' -- ... мосты ...
				and not r.other_tags @> '"access"=>"no"'
				and not r.other_tags @> '"access"=>"private"'
				and not r.other_tags @> '"access"=>"agricultural"'
				and not r.other_tags @> '"access"=>"delivery"'
				and not r.other_tags @> '"access"=>"restricted"' -- ... улицы с ограниченным доступом		
			)
		) 
--limit 100 --дебаг
;

/* Создание PK и индексов, кластеризация */
alter table index2020.data_road add primary key(id);
create index  on index2020.data_road using gist(geom);
create index  on index2020.data_road using gist((geom::geography));
create index on index2020.data_road (type);
create index on index2020.data_road (id_gis);
create index on index2020.data_road (name);

/* Комментарии */
comment on table index2020.data_road is 'Граф дорог для рассчёта 25-го индикатора и привязывания "зебр"';
comment on column index2020.data_road.id is 'Первичный ключ';
comment on column index2020.data_road.type is 'Класс дороги по OpenStreetMap. См. https://wiki.openstreetmap.org/wiki/Key:highway';
comment on column index2020.data_road.id_gis is 'id_gis города';
comment on column index2020.data_road.name is 'Название дороги или улицы которая по ней проходит';
comment on column index2020.data_road.geom is 'Геометрия';

