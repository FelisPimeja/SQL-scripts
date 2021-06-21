/* Создание слоя с основной улично-дорожной сетью в границах городов */
/* Время расчёта ~ 50 мин. */
drop table if exists roads_main_clipped;
create temp table roads_main_clipped as
select
    row_number() over() street_id,
	r.id,
	b.id_gis,
	r.name,
	st_transform(st_multi(
		case
			when st_within(r.geom, b.geom)
				then r.geom
			else
				case
					when st_isvalid(r.geom)
						and st_isvalid(b.geom) 
						then st_union(st_collectionextract(st_intersection(r.geom, b.geom), 2))
					else st_union(st_collectionextract(st_intersection(st_collectionextract(st_makevalid(r.geom), 2), st_collectionextract(st_makevalid(b.geom), 3)), 2))
				end
		end
	), 3857)::geometry(multilinestring, 3857) geom -- 3857 нужна на следующем шаге для ClusterDBSCAN
from index2020.data_boundary b 
join russia.roads_osm r
	on (
		r.type in (
	--		'motorway',
	--		'motorway_link', -- отбрасываем скоростные автомагистрали
			'pedestrian',
			'primary',
			'primary_link',
			'secondary',
			'secondary_link',
			'tertiary',
			'tertiary_link',
			'trunk',
			'trunk_link',
			'unclassified',
			'road',
			'residential'
		)
		or r.type in ('living_street', 'service') and r.name <> ''
	)
		and name <> '' -- отбрасываем улицы без названий ...
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
		and (char_length(name) between 5 and 30
			or (char_length(name) > 30 
					and (
						name ilike '%улиц%'
							or name ilike 'улица%'
							or name like '%роспек%'
							or name like '%абережна%'
							or name like '%ереуло%'
							or name like '%лощад%'
							or name like '%роез%'
							or name like '%ульва%'
							or name ilike '%линия%'
					)
				)
		)  -- ... всякие глупости в названиях (можно фильтровать бесконечно)
		and name not ilike '%ыже%трасс%' -- "пешелыжные трассы"
		and name not ilike '%ыже%дор%'
		and st_intersects(b.geom, r.geom)
--where b.id_gis <= 800 -- дебаг
group by 
	r.id,
	b.id_gis,
	r.name,
	b.geom,
	r.geom
order by b.id_gis, r.id
;
/* Создание PK и индексов, кластеризация */
alter table roads_main_clipped add primary key(street_id);
create index on roads_main_clipped (id_gis);
create index on roads_main_clipped using gist(geom);
--cluster roads_main_clipped using roads_main_clipped_geom_idx
;
/* Собираем улицы из частей */
drop table if exists streets_filtered;
create temp table streets_filtered as
/* Фильтрация улиц */
	select 
		st_clusterdbscan(geom, eps := 5000, minpoints := 0) over (partition by id_gis, name) cid, -- сразу кластеризация по расстоянию
		id_gis,
		name,
		geom
	from roads_main_clipped
;
/* Сборка улиц из отрезков и запись вставкой */
drop table if exists index2020.data_street;
create table index2020.data_street as
select
	row_number() over() id_street,
	id_gis,
	"name",
	st_transform(st_multi(st_linemerge(st_union(geom))), 4326)::geometry(multilinestring, 4326) geom 
from streets_filtered
group by cid, id_gis, "name"
;
/* Индексы */
alter table index2020.data_street add primary key(id_street);
create index on index2020.data_street (id_gis);
create index on index2020.data_street ("name");
create index on index2020.data_street using gist(geom)
;
/* Комментарии */
comment on table index2020.data_street is 
'Граф именованных улиц в границах городов РФ.
Источник - OpenStreetMap.
Актуальность - январь 2020 г.';
comment on column index2020.data_street.id_street is 'Уникальный id улицы в пределах РФ (без дублирования)';
comment on column index2020.data_street.id_gis is 'id_gis города';
comment on column index2020.data_street.name is 'Название улицы'
;
/* Минимальная статистика по слою улиц */
/* Время расчёт ~ 5 сек. */
drop table if exists index2020.stat_street;
create table index2020.stat_street as 
select 
	b.id_gis,
	b.city,
	b.region,
	count(s.*) total_streets
from index2020.data_boundary b
left join index2020.data_street s using(id_gis)
group by b.id_gis, b.city, b.region
order by b.id_gis
;
/* Индексы */
alter table index2020.stat_street add primary key(id_gis)
;
/* Комментарии */
comment on table index2020.stat_street is 'Уровень озеленения. 14-й индикатор.';
comment on column index2020.stat_street.id_gis is 'Уникальный идентификатор города';
comment on column index2020.stat_street.city is 'Город';
comment on column index2020.stat_street.region is 'Субъект РФ';
comment on column index2020.stat_street.total_streets is 'Общее число именованных улиц в городе, шт.';



/* Если потребуется вставка улиц из прошлогоднего датасета */
-- На последнем расчёте это были:
--   Ак-Довурак, Десногорск, Катав-Ивановск, Мглин, Нестеров, Правдинск,
--   Туран, Удачный, Шагонар, Урус-Мартан, Павловский Посад 

/*
-- Зачищаем из рабочей талицы улицы в городах по списку id_gis
delete from index2020.data_street
where id_gis in (8,680,737,689,400,170,806,443,269,852,540)

-- Достаём максимальное значение первичного ключа, чтобы не нарваться на ограничение при вставке
select max(id_street) from index2019.data_street

-- Вставляем прошлогодние улицы по списку id_gis
insert into index2020.data_street 
select 
	id_street + 250000, -- + макс значение из предыдущего запроса
	id_gis,
	"name",
	geom
from index2019.data_street
where id_gis in (8,680,737,689,400,170,806,443,269,852,540) 
*/






/* Дороги для 25-го */
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
from index2020.data_boundary b
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
where b.id_gis = 1122
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






