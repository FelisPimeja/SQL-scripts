/* типология зданий на основе OpenStreetMap, Альтермага и dom.mingkh.ru */
/* версия 2 */
--/* время расчёта ~ 1.5 часа. на всю Россию */ ???
/* to do: */
-- 1. Убрать задублированную геометрию из OpenStreetMap (см. Челябинск - угловые дома в частном секторе)
-- 2. Проверять классы из OSM - там и лажа попадается - какая неожиданность!
-- 3. Переработать классы на основе МинЖКХ - отсутствие этажности хреновый признак для распознания ИЖС
-- 4. Нижний Новгород - сараи в МКД кварталах зачем-то распознаются как ИЖС!

/* буферы от точек dom.mingkh.ru  + id_gis */
drop table if exists building_min_gkh_buffer;
create temp table building_min_gkh_buffer as
select m.*, st_buffer(m.geom::geography, 5)::geometry buffer
from russia.building_mingkh m
join index2019.data_boundary b
	on st_intersects(m.geom, b.geom)
where m.id_gis = 1080 -- дебаг
;
create index on building_min_gkh_buffer (id_gis);
create index on building_min_gkh_buffer using gist(buffer);

--explain
/* классификация начинается здесь */
drop table if exists building3;
create temp table building3 as 

with
/* первая итерация - классификация по OpenStreetMap */
building1 as (
	select distinct on(b.id)
		b.id,
		b.id_gis,
		b.type osm_type,
		case
			when b.type in ('apartments', 'dormitory') or (b.type = 'residential' and b.levels > 1)
				then 'mkd'::varchar
			else case
				when b.type in ('house', 'detached') or (b.type = 'residential' and b.levels < 2)
					then 'igs'::varchar
--					then 'residential'::varchar
				when b.type = 'yes' then 'other'::varchar
				else 'other'::varchar
			end
		end building_type,
		null::smallint build_year,
		case
			when b.levels is not null
				then b.levels::smallint
			when b.levels is null
				and b.type in ('garage', 'garages', 'fuel', 'greenhouse', 'hangar', 'hut', 'kiosk', 'roof', 'service', 'shed', 'stable', 'tank')
				then 1::smallint
			else null::smallint
		end levels,
		b.geom
	from index2019.data_building b
	where id_gis = 1080 -- дебаг
),

/* вторая итерация - уточнение по данным dom.mingkh.ru */
building2 as (
	select 
		b.id,
		b.id_gis,
		b.osm_type,
		case
			when b.building_type = 'other'
				and max(mb.id) is not null
				and case
					when max(mb.floors) != 'Не заполнено'
						and max(mb.floors) not like '% %' -- потому что в МинЖКХ была лажа
						then max(mb.floors)::smallint
				end > 1
				then 'mkd'::varchar
			when b.building_type = 'other'
				and max(mb.id) is not null
				and case
					when max(mb.floors) != 'Не заполнено'
						and max(mb.floors) not like '% %'
						then max(mb.floors)::smallint
					when max(mb.floors)  = 'Не заполнено'
						or max(mb.floors) like '% %'
						then 1::smallint
				end = 1
				then 'igs'::varchar
			else b.building_type
		end building_type,
		case
			when b.build_year is null
				and min(mb.year) not in ('Не заполнено','0','1')
				then min(mb.year)::smallint
			else b.build_year
		end build_year,
		case 
			when max(mb.floors) is not null
				and max(mb.floors) != 'Не заполнено'
				and max(mb.floors) not like '% %'
				then max(mb.floors)::smallint
			else b.levels::smallint
		end levels,
		b.geom
	from building1 b
	left join building_min_gkh_buffer mb
		on b.id_gis = mb.id_gis
			and st_intersects(b.geom, mb.buffer)
	group by b.id, b.id_gis, b.osm_type, b.building_type, b.build_year, b.levels, b.geom
),

/* третья итерация - уточнение по данным Альтермага */
building3 as (
	select 
		b.id,
		b.id_gis,
		b.osm_type,
		case
			when b.building_type = 'other'
				and max(a.id) is not null
				then 'mkd'
			else b.building_type
		end building_type,
		b.build_year,
		sum(a.population) population,
		case
			when (b.levels is null and max(a.id) is not null)
				or max(a.floor) > b.levels
				then max(a.floor)::smallint
			else b.levels
		end levels,
		st_area(b.geom::geography)::int area_m2,
		b.geom
	from building2 b
	left join index2019.data_pop_altermag a
		on a.id_gis = b.id_gis
			and st_intersects(a.geom, b.geom)
			and a.floor > 1
	group by b.id, b.id_gis, b.osm_type, b.building_type, b.build_year, b.levels, b.geom
)

select * from building3;
create index on building3(id_gis);
create index on building3 using gist(geom);

drop table if exists building4;
create table building4 as 

with
/* отбор кварталов landuse = residential по выгрузке OpenStreetMap */
landuse1 as (
	select l.*, b.id_gis
	from index2019.data_boundary b
	join osm.landusages_ru l
		on st_intersects(b.geom, l.geom)
			and l.type in ('residential', 'allotments')
	where b.id_gis = 1080 -- дебаг
),

/* подсчёт средней площади здания на квартал landuse = residential (поиск кварталов ИЖС) */
landuse2 as (
	select l.*, avg(area_m2) avg_build_area
	from landuse1 l
	join building3 b
		on b.id_gis = l.id_gis
			and st_intersects(l.geom, b.geom)
--			and b.building_type <> 'other'
	group by l.id, l.id_gis, l.name, l.type, l.geom
),

/* четвёртая итерация - уточнение ИЖС по средней площади здания на квартал и площади здания */
building4 as (
	select distinct on(b.id)
		b.id,
		b.id_gis,
		b.osm_type,
		case
			when b.building_type = 'other'
				then case
					when l.id is not null
						and avg_build_area <= 200
						and st_area(b.geom::geography, true) <= 550
--						then 'residential'
						then 'igs'
					else b.building_type
				end
			else b.building_type
		end building_type,
		b.build_year,
		b.population,
		b.levels,
		b.area_m2,
		b.geom
	from building3 b
	left join landuse2 l
		on b.id_gis = l.id_gis
			and st_intersects(b.geom, l.geom)
			and l.type in ('residential', 'allotments')
)

select * from building4;
create index on building4(id_gis);
create index on building4 using gist(geom);


drop table if exists russia.building_classify;
create table russia.building_classify as 

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
alter table tmp.building_classified_1080 drop column id;
alter table tmp.building_classified_1080 add column id serial primary key;
create index on tmp.building_classified_1080 using gist(geom);
create index on tmp.building_classified_1080 (levels);
create index on tmp.building_classified_1080 (build_year);
create index on tmp.building_classified_1080 (building_type);

/* комментарии */
comment on table tmp.building_classified_1080 is 'Типология зданий (жилые/нежилые) + этажность и год постройки. Источники: OpenStreetMap, Альтермаг, dom.gosuslugi.ru и dom.mingkh.ru';
comment on column tmp.building_classified_1080.id is 'Первичный ключ';
comment on column tmp.building_classified_1080.id_gis is 'id_gis города';
comment on column tmp.building_classified_1080.osm_type is 'Тип здания по OpenStreetMap';
comment on column tmp.building_classified_1080.building_type is 'Тип здания (МКД/ИЖС/Прочее)';
comment on column tmp.building_classified_1080.build_year is 'Год постройки';
comment on column tmp.building_classified_1080.levels is 'Количество этажей';
comment on column tmp.building_classified_1080.geom is 'Геометрия';
