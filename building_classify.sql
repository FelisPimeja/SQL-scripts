/* типология зданий на основе OpenStreetMap, Альтермага и dom.mingkh.ru */
/* версия 2 */
--/* время расчёта ~ 1.5 часа. на всю Россию */ ???
/* to do: */
-- 1. Убрать задублированную геометрию из OpenStreetMap (см. Челябинск - угловые дома в частном секторе)
-- 2. Проверять классы из OSM - там и лажа попадается - какая неожиданность!
-- 3. Переработать классы на основе МинЖКХ - отсутствие этажности хреновый признак для распознания ИЖС
-- 4. Нижний Новгород - сараи в МКД кварталах зачем-то распознаются как ИЖС!

/* !!! дебаг - задаём город !!! */
drop table if exists city;
create temp table city as
select id_gis::smallint, geom from index2019.data_boundary
--where id_gis = 1084 -- дебаг
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

--explain
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
	case
		when b.levels is not null
			then b.levels::smallint
		when b.levels is null
			and b.type in ('garage', 'garages', 'fuel', 'greenhouse', 'hangar', 'hut', 'kiosk', 'roof', 'service', 'shed', 'stable', 'tank')
			then 1::smallint
		else null::smallint
	end levels,
	b.geom
from city c
join index2019.data_building b using(id_gis);

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
		when mb.built_year is not null
			then mb.built_year
		else null
	end built_year,
	case 
		when mb.floor is not null
			then mb.floor
		else b.levels
	end levels,
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
	b.built_year,
	a.population,
	case
		when (b.levels is null and a.floor is not null)
			or a.floor > b.levels
			then a.floor::smallint
		else b.levels
	end levels,
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
select l.id, l.id_gis, l.type, l.geom, avg(area_m2) avg_build_area
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
					and st_area(b.geom::geography, true) <= 550
					then 'igs'
				else b.building_type
			end
		else b.building_type
	end building_type,
	b.built_year,
	b.population,
	b.levels,
	b.area_m2,
	b.geom
from landuse2 l
join building3 b
	on b.id_gis = l.id_gis
		and st_intersects(b.geom, l.geom)
where l.type in ('residential', 'allotments');


select * from building4;
create index on building4(id_gis);
create index on building4 using gist(geom);


drop table if exists russia.building_classify2;
create table russia.building_classify2 as 

with
/* фильтрация памятников  */
okn_filtered as (
	select
		id,
		id_gis,
		nativename,
		geom
	from index2019.data_okn
	where (
		nativename !~* 'могил|ограда| стел+а|обелиск|мемориал|бюст|надгроб|склеп|знак|улица|статуя|урна|памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок'
		or (nativename ~* 'жилой|дом|домик|флигель|башня|ансамбль|часовн|палаты|терем|павильон|школ|церковь'
			and nativename !~* 'памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок')
	) 
		and id_gis = 1080 -- дебаг
),

/* сопоставление зданий с ОКН из реестра минкульта */
building5 as (
	select distinct on(b.id)
		b.*,
--		st_collect(o.geom, b.geom), -- для дебага
		o.id okn_id
	from building4 b
	left join lateral (
		select o.id
		from okn_filtered o
		where o.id_gis = b.id_gis
			and st_dwithin(o.geom::geography, b.geom::geography, 10)
		order by o.geom::geography <-> (st_centroid(b.geom))::geography
		limit 1
	) o on true
)

select * from building5;

/* первичный ключ и индексы */
alter table russia.building_classify2 drop column id;
alter table russia.building_classify2 add column id serial primary key;
create index on russia.building_classify2 using gist(geom);
create index on russia.building_classify2 (levels);
create index on russia.building_classify2 (built_year);
create index on russia.building_classify2 (building_type);

/* комментарии */
comment on table russia.building_classify2 is 'Типология зданий (жилые/нежилые) + этажность и год постройки. Источники: OpenStreetMap, Альтермаг, dom.gosuslugi.ru и dom.mingkh.ru';
comment on column russia.building_classify2.id is 'Первичный ключ';
comment on column russia.building_classify2.id_gis is 'id_gis города';
comment on column russia.building_classify2.osm_type is 'Тип здания по OpenStreetMap';
comment on column russia.building_classify2.building_type is 'Тип здания (МКД/ИЖС/Прочее)';
comment on column russia.building_classify2.built_year is 'Год постройки';
comment on column russia.building_classify2.levels is 'Количество этажей';
comment on column russia.building_classify2.geom is 'Геометрия';
