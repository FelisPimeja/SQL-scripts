
/* Приключение на 25 секунд - туда и обратно! */
/* Создаём чистую таблицу если ещё не создана */
create table if not exists index2019.data_street (
    id_street serial primary key,
    id_gis integer,
    name character varying COLLATE pg_catalog."default",
    geom geometry(MultiLineString,4326)
);

/* Сброс индексов, если они уже есть */
drop index if exists index2019.data_street_geom_idx;
drop index if exists index2019.data_street_id_gis_idx;

/* Зачистка таблицы, если она уже есть и нужно обновить данные не дропая все зависимости */
truncate index2019.data_street;

/* Фильтрация улиц */
with streets_filtered as (
	select 
		st_clusterdbscan(st_transform(geom, 3857), eps := 5000, minpoints := 0) over (partition by id_gis, name) cid, -- сразу кластеризация по расстоянию
		id_gis,
		name,
		geom
	from routing.roads_main_clipped
	where name <> ''
		and type not in ('motorway', 'motorway_link') -- доп. отбрасываются скоростные магистрали
		and tunnel != 1 -- ... мосты
		and bridge != 1 -- ... тоннели
		and access not in (
			'private',
			'agricultural',
			'no',
			'delivery',
			'restricted'
		) -- ... улицы с ограниченным доступом
		and (char_length(name) between 5 and 30
		or (char_length(name) > 30 
				and name ilike '%улиц%'
				or name ilike 'улица%'
				or name like '%роспек%'
				or name like '%абережна%'
				or name like '%ереуло%'
				or name like '%лощад%'
				or name like '%роез%'
				or name like '%ульва%'
				or name ilike '%линия%'
			)
		)  -- ... всякие глупости в названиях (можно фильтровать бесконечно)
		and name not ilike '%ыже%трасс%' -- "пешелыжные трассы"
		and name not ilike '%ыже%дор%'
-- 		and id_gis = 777 -- для дебага
)

/* Сборка улиц из отрезков и запись вставкой */
insert into index2019.data_street (id_street, id_gis, name, geom)
select
	row_number() over() id_street,
	id_gis,
	name,
	st_multi(st_linemerge(st_union(geom)))::geometry(multilinestring, 4326) geom 
from streets_filtered
group by cid, id_gis, name;

/* Индексы */
create index on index2019.data_street using gist(geom);
create index on index2019.data_street (id_gis);

/* Комментарии */
comment on table index2019.data_street is 
'Граф именованных улиц в границах городов РФ.
Источник - OpenStreetMap.
Актуальность - январь 2020 г.';
comment on column index2019.data_street.id_street is 'Уникальный id улицы в пределах РФ (без дублирования)';
comment on column index2019.data_street.id_gis is 'id_gis города';
comment on column index2019.data_street.name is 'Название улицы';


/* Минимальная статистика по слою улиц */
/* Время расчёт ~ 5 сек. */
drop materialized view if exists index2019.stat_street;
create materialized view index2019.stat_street as 
select 
	b.id_gis,
	b.city,
	b.region,
	count(s.*) total_streets
from index2019.data_boundary b
left join index2019.data_street s using(id_gis)
group by b.id_gis, b.city, b.region
order by b.id_gis;

/* Индексы */
create unique index on index2019.stat_street(id_gis);

/* Комментарии */
comment on materialized view index2019.stat_street is 'Уровень озеленения. 14-й индикатор.';
comment on column index2019.stat_street.id_gis is 'Уникальный идентификатор города';
comment on column index2019.stat_street.city is 'Город';
comment on column index2019.stat_street.region is 'Субъект РФ';
comment on column index2019.stat_street.total_streets is 'Общее число именованных улиц в городе, шт.';
