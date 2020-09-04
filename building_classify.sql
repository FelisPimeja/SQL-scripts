/* типология зданий на основе OpenStreetMap, Альтермага и dom.mingkh.ru */
/* время расчёта ~ 3.5 часа. на всю Россию  - фильтрация ОСМ от наложений сильно замедлила процесс */
/* to do: */
-- 1. Зачистка дубликатов ОСМ прошла с некоторыми потерями среди мирного населения. Вроде, не критично. Но надо попробовать что-то с этим сделать.

/* !!! дебаг - задаём город !!! */
drop table if exists city;
create temp table city as
select id_gis::smallint, geom from index2019.data_boundary
--where id_gis = 1082 -- дебаг
;
create index on city(id_gis);
create index on city using gist(geom);

/* предварительная подготовка данных МинЖКХ */
drop table if exists mingkh;
create temp table mingkh as
select
	m.id,
	m.id_gis,
	case 
		when m.square in ('Не заполнено', 'Незаполнено', '')
			or m.square::real = 0
			then null
		else round(m.square::numeric)::int
	end square,
	case 
		when m.year in ('Не заполнено', 'Незаполнено', '')
			then null
		else m.year::smallint
	end built_year,
	case 
		when m.floors in ('Не заполнено', 'Незаполнено', '')
			or m.floors::int = 0
			then null
		else m.floors::smallint
	end floor,
	m.geom
from city c
join russia.building_mingkh m using(id_gis);

create index on mingkh(id_gis);
create index on mingkh(built_year);
create index on mingkh(floor);
create index on mingkh using gist(geom);
create index on mingkh using gist((geom::geography));


/* зачищаем здания OpenStreetMap от накладывающихся частей */
/* выбираем все здания на искомый город */
drop table if exists osm;
create temp table osm as
select b.* from city c
join index2019.data_building b using(id_gis);

create index on osm(id_gis);
create index on osm(area_m);
create index on osm(id);
create index on osm using gist(geom);

/* пересекаем таблицу саму с собой, сравниваем накладывающуюся геометрию */
drop table if exists compare;
create temp table compare as
select
	s1.*,
--	s2.id s2_id --дебаг
	case 
		when st_area(st_intersection(s1.geom, s2.geom)::geography) > 0.9 * s2.area_m -- наложение > 90% от площади второй фигуры - помечаем первую как большую
			then true
		when s2.id is null -- нет пересечений с другими объектами - помечаем отсутствием значения
			then null 
		else false -- помечаем первую как меньшую
	end biggest
from osm s1
left join osm s2 
	on s1.id_gis = s2.id_gis
		and st_intersects(s1.geom, s2.geom)
		and st_area(st_intersection(s1.geom, s2.geom)::geography) > 0.1 * s2.area_m  -- наложение < 10% от площади второй фигуры - не рассматриваем
		and s1.area_m >= s2.area_m -- первая всегда больше или равна по площади второй
		and s1.id <> s2.id;

create index on compare(biggest);

/* отфильтровываем здания которые покрывают собой другие здания */
drop table if exists building_filtered;
create temp table building_filtered as 
select * from compare where biggest is false or biggest is null;

create index on building_filtered(id_gis);
create index on building_filtered(type);
create index on building_filtered(levels);

/* классификация начинается здесь */
/* первая итерация - классификация по OpenStreetMap */
drop table if exists building1;
create temp table building1 as 
select 
	b.id,
	b.id_gis,
	b.type osm_type,
	case
		when
			(b.type in ('apartments', 'dormitory') and st_area(b.geom::geography) > 550)
				or (b.type in ('house', 'residential') and b.levels > 2)
			then 'mkd'::varchar
		else case
			when b.type in ('house', 'detached', 'residential') and b.levels < 3
				then 'igs'::varchar
			else 'other'::varchar
		end
	end building_type,
	'OpenStreetMap'::varchar building_type_source,
	case
		when b.levels is not null
			then b.levels::smallint
		when b.levels is null
			and b.type in ('garage', 'garages', 'fuel', 'greenhouse', 'hangar', 'hut', 'kiosk', 'roof', 'service', 'shed', 'stable', 'tank')
			then 1::smallint
		else null::smallint
	end levels,
	case 
		when b.levels is not null 
			then 'OpenStreetMap'::varchar
		else null 
	end levels_source,
	b.geom
from building_filtered b;

create index on building1(id_gis);
create index on building1(building_type);
create index on building1 using gist(geom);
create index on building1 using gist((geom::geography));

/* вторая итерация - уточнение по данным dom.mingkh.ru */
drop table if exists building2;
create temp table building2 as
select 
	b.id,
	b.id_gis,
	b.osm_type,
	case
		when b.building_type = 'other'
			and mb.id is not null
			then 'mkd'::varchar
		else b.building_type
	end building_type,
	case
		when b.building_type = 'other'
			and mb.id is not null
			then 'МинЖКХ'::varchar
		else b.building_type_source
	end building_type_source,
	case
		when mb.built_year is not null
			then mb.built_year
		else null
	end built_year,
	case 
		when mb.built_year is not null 
			then 'МинЖКХ'::varchar
		else null 
	end built_year_source,
	case 
		when mb.floor is not null
			then mb.floor
		else b.levels
	end levels,
	case 
		when mb.floor is not null
			then 'МинЖКХ'::varchar
		else b.levels_source
	end levels_source,
	b.geom
from building1 b
left join lateral (
	select *
	from mingkh m
	where b.id_gis = m.id_gis
		and st_dwithin(b.geom::geography, m.geom::geography, 5)
	order by m.geom::geography <-> b.geom::geography
	limit 1
) mb on true;

create index on building2(id_gis);
create index on building2(building_type);
create index on building2(levels);
create index on building2 using gist(geom);
create index on building2 using gist((geom::geography));

/* третья итерация - уточнение по данным Альтермага */
drop table if exists building3;
create temp table building3 as
select 
	b.id,
	b.id_gis,
	b.osm_type,
	case
		when b.building_type = 'other'
			and a.floor is not null
			then 'mkd'
		else b.building_type
	end building_type,
	case
		when b.building_type = 'other'
			and a.floor is not null
			then 'Альтермаг'::varchar
		else b.building_type_source
	end building_type_source,
	b.built_year,
	b.built_year_source,
	a.population,
	case 
		when a.population is not null 
			then 'Альтермаг'::varchar 
		else null 
	end population_source,
	case
		when (b.levels is null and a.floor is not null)
			or a.floor > b.levels
			then a.floor::smallint
		else b.levels
	end levels,
	case
		when (b.levels is null and a.floor is not null)
			or a.floor > b.levels
			then 'Альтермаг'::varchar
		else b.levels_source
	end levels_source,
	st_area(b.geom::geography)::int area_m2,
	b.geom
from building2 b
left join lateral (
	select a.floor, a.population, a.id_gis, a.geom
	from index2019.data_pop_altermag a
	where a.id_gis = b.id_gis
		and a.floor > 1
		and st_dwithin(a.geom::geography, b.geom::geography, 5)
	order by a.geom::geography <-> b.geom::geography
	limit 1
) a on true;

create index on building3(id_gis);
create index on building3(area_m2);
create index on building3 using gist(geom);

drop table if exists landuse;
create temp table landuse as 
select l.*, c.id_gis
from city c
join osm.landusages_ru l
	on st_intersects(c.geom, l.geom)
		and l.type in ('residential', 'allotments');

create index on landuse(id_gis);
create index on landuse using gist(geom);

/* подсчёт средней площади здания на квартал landuse = residential (поиск кварталов ИЖС) */
drop table if exists landuse2;
create temp table landuse2 as 
select
	l.id,
	l.id_gis,
	l.type,
	l.geom,
	avg(b.area_m2) avg_build_area,
	round((count(b.*) filter(where b.building_type = 'mkd')::numeric / count(b.*))::numeric, 1) mkd_proportion
from landuse l
join building3 b
	on b.id_gis = l.id_gis
		and st_intersects(l.geom, b.geom)
group by l.id, l.id_gis, l.type, l.geom;

create index on landuse2(id_gis);
create index on landuse2(type);
create index on landuse2 using gist(geom);

/* четвёртая итерация - уточнение ИЖС по средней площади здания на квартал и площади здания */
drop table if exists building4;
create temp table building4 as
select distinct --on(b.id)
	b.id,
	b.id_gis,
	b.osm_type,
	case
		when b.building_type = 'other'
			then case
				when l.id is not null
					and avg_build_area <= 200
					and mkd_proportion <= 0.2
					and st_area(b.geom::geography, true) <= 550
					then 'igs'
				else b.building_type
			end
		else b.building_type
	end building_type,
--	l.mkd_proportion, --дебаг
	case
		when b.building_type = 'other'
			then case
				when l.id is not null
					and avg_build_area <= 200
					and mkd_proportion <= 0.2
					and st_area(b.geom::geography, true) <= 550
					then 'Средняя площадь здания на квартал'::varchar
				else b.building_type_source
			end
		else b.building_type_source
	end building_type_source,
	b.built_year,
	b.built_year_source,
	b.population,
	b.population_source,
	b.levels,
	b.levels_source,
	b.area_m2,
	b.geom
from building3 b
left join landuse2 l
	on b.id_gis = l.id_gis
		and st_intersects(b.geom, l.geom);

create index on building4(id_gis);
create index on building4 using gist(geom);

/* фильтрация памятников  */
drop table if exists okn_filtered;
create temp table okn_filtered as
select
	o.nativeid,
	o.id_gis,
	o.nativename,
	o.geom
from city c
left join index2019.data_okn o using(id_gis)
where (o.nativename !~* 'могил|ограда| стел+а|обелиск|мемориал|бюст|надгроб|склеп|знак|улица|статуя|урна|памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок'
	or (o.nativename ~* 'жилой|дом|домик|флигель|башня|ансамбль|часовн|палаты|терем|павильон|школ|церковь'
		and o.nativename !~* 'памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок')
);

create index on okn_filtered(id_gis);
create index on okn_filtered using gist(geom);
create index on okn_filtered using gist((geom::geography));


/* сопоставление зданий с ОКН из реестра минкульта */
drop table if exists russia.building_classify;
create table russia.building_classify as 
select distinct on(b.id)
	b.*,
	o.okn_id
from building4 b
left join lateral (
	select o.nativeid okn_id
	from okn_filtered o
	where o.id_gis = b.id_gis
		and st_dwithin(o.geom::geography, b.geom::geography, 10)
	order by o.geom::geography <-> (st_centroid(b.geom))::geography
	limit 1
) o on true;


/* первичный ключ и индексы */
alter table russia.building_classify drop column id;
alter table russia.building_classify add column id serial primary key;
create index on russia.building_classify using gist(geom);
create index on russia.building_classify using gist((geom::geography));
create index on russia.building_classify (levels);
create index on russia.building_classify (built_year);
create index on russia.building_classify (building_type);

/* комментарии */
comment on table russia.building_classify is 'Типология зданий (жилые/нежилые) + этажность и год постройки. Источники: OpenStreetMap, Альтермаг, dom.gosuslugi.ru и dom.mingkh.ru';
comment on column russia.building_classify.id is 'Первичный ключ';
comment on column russia.building_classify.id_gis is 'id_gis города';
comment on column russia.building_classify.osm_type is 'Тип здания по OpenStreetMap';
comment on column russia.building_classify.building_type is 'Тип здания (МКД/ИЖС/Прочее)';
comment on column russia.building_classify.building_type_source is 'Источник типа здания';
comment on column russia.building_classify.built_year is 'Год постройки';
comment on column russia.building_classify.built_year_source is 'Источник года постройки';
comment on column russia.building_classify.levels is 'Количество этажей';
comment on column russia.building_classify.levels_source is 'Источник этажности';
comment on column russia.building_classify.geom is 'Геометрия';
