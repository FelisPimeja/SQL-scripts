/* генерация квартальной сетки и статистики на данных OpenStreetMap.
Алгоритм: https://docs.google.com/document/d/1y9j93d0SrOJo7WOOQ2IxIj72nmbNIem28eN_J3kTDXc/edit 
+ данные по году постройки из МИН ЖКХ */

/* время расчёта ~ 3.5 часа для всех городов России */

/* to do */
-- 1. Полностью перенести механизм сопоставления с реестром ОКН в скрипт типизации зданий
-- 2. Проверить почему osm типы house, detached не конвертировался в igs

/* !!! дебаг - задаём город !!! */
drop table if exists city;
create temp table city as
select id_gis::smallint, geom from index2019.data_boundary
where id_gis = 1084 -- дебаг
;
create index on city(id_gis);
create index on city using gist(geom);

/* подготовка памятников - фильтрация по типу (из названия) и извлечения дат */
/* фильтрация по имени + извлечение даты из полей general_createdate и nativename */
drop table if exists okn_filtered;
create temp table okn_filtered as
with step1 as (
	select
		o.nativeid,
		o.id_gis,
		o.nativename,
		unnest(regexp_match(replace(o.nativename,'Х','X'), '\d\d\d\d|[XIV]+'))::varchar date_from_name,
		general_createdate,
		unnest(regexp_match(replace(o.general_createdate,'Х','X'), '\d\d\d\d|[XIV]+'))::varchar date_from_createdate,
		o.geom
	from city c
	left join index2019.data_okn o using(id_gis)
	where (o.nativename !~* 'могил|ограда| стел+а|обелиск|мемориал|бюст|надгроб|склеп|знак|улица|статуя|урна|памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок'
		or (o.nativename ~* 'жилой|дом|домик|флигель|башня|ансамбль|часовн|палаты|терем|павильон|школ|церковь'
			and o.nativename !~* 'памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок')
		)
--	and c.id_gis = 777 -- дебаг
), -- поиск и вычленение года или века из атрибута года постройки и названия памятника

/* выбираем дату из двух полей */
step2 as (
select
	nativeid,
	id_gis,
	nativename,
	case 
		when date_from_name is null and date_from_createdate is not null
			then date_from_createdate
		when date_from_name is not null and date_from_createdate is null
			then date_from_name
		when date_from_name is null and date_from_createdate is null
			then null
		else date_from_createdate
	end date,
	geom
from step1 
) -- сравнение извлечённых дат

/* отфильтровываем только нужный диапазон дат */
select * from step2
where
	(date = any('{XX, XIX, XVIII, XVII, XVI, XV, XIV, XIII, XII, XI, X, IX, VIII, VII, VI, V, IV, III, II, I}')
	or (regexp_match(date, '\d') is not null and date::int < 1917)); --проверка, чтобы год был до 1917
--order by date

create index on okn_filtered(id_gis);
create index on okn_filtered using gist(geom);
create index on okn_filtered using gist((geom::geography));
	
/* привязка фильтрованных ОКН к класифицированным зданиям */
drop table if exists okn_matched;
create temp table okn_matched as
select distinct on (o.geom)
	b.id,
	o.nativeid,
	o.nativename,
	o.id_gis,
	o.date--,
--		st_collect(o.geom, b.geom), -- для дебага
--	o.geom okn_geom,
--	b.geom osm_geom	
from okn_filtered o
join lateral (
	select b.id, b.geom
	from russia.building_classify b
	where o.id_gis = b.id_gis
		and st_dwithin(o.geom::geography, b.geom::geography, 5)
	order by o.geom::geography <-> (st_centroid(b.geom))::geography
	limit 1
) b on true;
--	where o.id_gis < 10 -- для дебага

create index on okn_matched(id_gis);
create index on okn_matched(id);

/* извлечение дорог */
drop table if exists roads;
create temp table roads as 
select row_number() over () id, id_gis, name, type, geom
from (
	select r.name, r.type, r.id_gis, (st_dump(r.geom)).geom
	from index2019.data_road r
	join city c using(id_gis)
	where (
		type != all('{track,path,footway,cycleway,steps,service}')
		or name != ''
	) -- фильтруем по типу
) a;

create index on roads(id_gis);
create index on roads(type);
create index on roads using gist(geom);


/* первое приближение кварталов - очерчиваем 50 м. буферы от зданий (уже предрасчитано) */
drop table if exists building_buffers;
create temp table building_buffers as 
select
	b.id_gis,
	b.geom
from city c 
join russia.city_built_area_light b using(id_gis);

create index on building_buffers(id_gis);
create index on building_buffers using gist(geom);

/* вырезаем воду (полигональную и линейную) и железнодорожные пути */
/* собираем площадную воду */
drop table if exists waterareas;
create temp table waterareas as
select b.id_gis, w.geom
from building_buffers b
join osm.waterareas_ru w
	on st_intersects(b.geom, w.geom)
		and st_area(w.geom::geography) > 20000 -- отбрасываем водоёмы меньше 2 га
		and st_isvalid(w.geom); -- check geometry

/* собираем линейную воду с буфером */
drop table if exists waterways;
create temp table waterways as		
select b.id_gis, st_multi(st_buffer(w.geom::geography, 10)::geometry)::geometry(multipolygon, 4326) geom
from building_buffers b
join osm.waterways_ru w
	on st_intersects(b.geom, w.geom)
		and w.tunnel = '' -- check for waterways in tunnels
		and st_isvalid(w.geom); -- check geometry	

/* собираем линейную жд пути с буфером */
drop table if exists railway_buffer;
create temp table railway_buffer as	
select b.id_gis, (st_buffer(r.geom::geography, (case when r.type = 'tram' then 5 else 10 end)))::geometry geom -- разной ширины буфер для трамвая и железной дороги
from building_buffers b
join osm.railroads_ru r
	on st_intersects(b.geom, r.geom)	
		and r.type not in ('subway','monorail','funicular') -- отбрасываем метро, монорельс и фуникулёр
		and r.tunnel != 1 and r.bridge != 1 -- отбрасываем мосты и туннели
		and st_isvalid(r.geom); -- check geometry

/* собираем ысё вышеперечисленное в один объект */
drop table if exists area_union;
create temp table area_union as			
select id_gis, st_buffer(st_collect(geom), 0) geom
from (
	select * from waterareas
	union all select * from waterways
	union all select * from railway_buffer
) un
group by id_gis;

/* вырезаем ысё вышесобранное из буфера от зданий */
drop table if exists boundary_clip;
create temp table boundary_clip as 
select
	b.id_gis,
	case 
		when l.geom is not null -- Проверяем, что вторая геометрия не отсутствует и действительно есть, что вырезать. В противном случае на выходе будет Null
			then st_difference(st_collectionextract(st_makevalid(b.geom), 3), st_collectionextract(st_makevalid(l.geom), 3))
		else b.geom
	end geom
from building_buffers b
left join area_union l using(id_gis);

create index on boundary_clip(id_gis);
create index on boundary_clip using gist(geom);

/* подготовка квартальной сетки */
drop table if exists split;
create temp table split as 
select b.id_gis, (st_dump(st_difference(b.geom, st_buffer(st_collect(st_buffer(r.geom::geography, case when r.type in ('track', 'path', 'service', 'footway', 'living_street') then 3 when r.type in ('residential', 'tertiary', 'unclassified') then 5 else 7.5 end, 'endcap=square join=mitre')::geometry), 0)))).geom geom
from boundary_clip b
join roads r using(id_gis)
group by b.id_gis, b.geom;

create index on split(id_gis);
create index on split using gist(geom);

/* отбивка буфера и фильтрация кварталов по площади и "ширине" */
drop table if exists quater_raw;
create temp table quater_raw as 
select b.id_gis, (st_dump(st_buffer(st_buffer(q.geom::geography, -5), 5,'endcap=square join=mitre')::geometry)).geom::geometry(polygon, 4326) geom
from boundary_clip b
join split q
	on b.id_gis = q.id_gis
		and st_intersects(b.geom, q.geom)
where
	not st_isempty(st_buffer(q.geom::geography, -8)::geometry)
	and	st_area(q.geom::geography) > 200
--			and	st_area(q.geom::geography) <= 800000 -- максимально допустимый размер микрорайона по Градостроительному кодексу
;

drop table if exists quater_raw2;
create temp table quater_raw2 as
select id_gis, geom
from quater_raw
where st_isempty(st_buffer(geom::geography, -15)::geometry)
union all 
select id_gis, geom
from (
	select id_gis, (st_dump(st_buffer(st_buffer(st_buffer(geom::geography, -15), 10, 'endcap=square join=mitre'), 5, 'quad_segs=1')::geometry)).geom::geometry(polygon, 4326) geom
	from quater_raw
) q
where st_area(q.geom::geography) > 500;

create index on quater_raw2(id_gis);
create index on quater_raw2 using gist(geom);

drop table if exists raw_quater;
create temp table raw_quater as
select
	(row_number() over())::int id,
	q.id_gis::smallint,
	round((st_area(q.geom::geography) / 10000)::numeric, 2) area_ha,
	st_multi(case
		when st_within(q.geom, b.geom)
			then q.geom
		else st_intersection(b.geom, q.geom)
	end)::geometry(multipolygon, 4326) geom
from quater_raw2 q
join index2019.data_boundary b
on b.id_gis = q.id_gis
	and st_intersects(b.geom, q.geom);

create index on raw_quater(id_gis);
create index on raw_quater using gist(geom);

/* расчёт основных показателей */
drop table if exists quater_stat;
create temp table quater_stat as 
select
	q.*,
	case 
		when max(b.id) filter(where b.building_type <> 'other') is not null
			then true
		else false
	end residential_function,
	coalesce(round((sum(b.area_m2))::numeric / 10000, 2), 0) footprint_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd'))::numeric / 10000, 2), 0) footprint_mkd_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'igs'))::numeric / 10000, 2), 0) footprint_igs_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'other'))::numeric / 10000, 2), 0) footprint_other_ha,

	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels between 1 and 3))::numeric / 10000, 2), 0) footprint_mkd_1_3_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels between 4 and 9))::numeric / 10000, 2), 0) footprint_mkd_4_9_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels > 9))::numeric / 10000, 2), 0) footprint_mkd_10_ha,

	count(b.*)::smallint building_count,
	coalesce(count(b.*) filter(where b.building_type = 'mkd'), 0)::smallint building_mkd_count,
	coalesce(count(b.*) filter(where b.building_type = 'igs'), 0)::smallint building_igs_count,
	coalesce(count(b.*) filter(where b.building_type = 'other'), 0)::smallint building_other_count,

	count(b.*) filter(where b.built_year <= 1917 or o.id is not null) old_building_count,
	
	percentile_disc(0.5) within group(order by b.area_m2) building_median_area_m2,

	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type = 'mkd') mkd_median_level,
	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type = 'other') other_median_level,
	percentile_disc(0.5) within group(order by b.built_year) filter(where b.building_type <> 'other') median_built_year,
	mode() within group(order by b.built_year) filter(where b.building_type <> 'other') mode_built_year
from raw_quater q
join russia.building_classify b
	on q.id_gis = b.id_gis
		and st_intersects(q.geom, b.geom)
left join okn_matched o
	on o.id = b.id
		and o.id_gis = b.id_gis
group by q.id, q.id_gis, q.area_ha, q.geom;


/* классификация кварталов по типам среды на основе расчитанных показателей */
drop table if exists classify_v7;
create temp table classify_v7 as
select
	*,
	case
		when residential_function is false
			or building_mkd_count + building_igs_count < 3 -- отбрасываем нежилые кварталы с 1-2 жилыми домами
				and building_count > 6
			then 'Нежилая городская среда'
		when old_building_count >= 0.7 * building_mkd_count
			and footprint_mkd_ha > footprint_igs_ha
			and building_mkd_count + building_igs_count > 0.2 * building_count -- !!! допущение
			then 'Историческая смешанная городская среда'
		else case
			when footprint_igs_ha > 0.7 * (footprint_mkd_ha + footprint_igs_ha)
				and footprint_igs_ha > 2 * footprint_mkd_ha
				and footprint_igs_ha > 0.6 * footprint_ha
					or (
						building_igs_count > 3 * building_other_count
							and footprint_igs_ha > 0.9 * footprint_mkd_ha -- !!! todo: поискать условия для низкого количества зданий
					)
					or (
						building_igs_count <= 5
							and building_other_count <= 3
							and building_mkd_count = 0
					)
				then 'Индивидуальная жилая городская среда'
			when footprint_mkd_ha > 0.7 * footprint_other_ha -- общие условия для многоквартирной застройки
				and footprint_mkd_ha >  2 * footprint_igs_ha
				then case
					when mkd_median_level between 1 and 3 -- медианная этажность
						and footprint_mkd_ha > footprint_igs_ha + footprint_other_ha
						and footprint_mkd_1_3_ha > footprint_mkd_4_9_ha
						and footprint_mkd_1_3_ha > 2 * footprint_mkd_10_ha
						then case 
							when median_built_year between 1918 and 1959
								or median_built_year is null -- !!!большое допущение в условиях отсутствия датировок
								then 'Советская малоэтажная разреженная городская среда'
							when median_built_year between 1960 and 1990
								then 'Позднесоветская малоэтажная разреженная городская среда'
							when median_built_year > 1990
								then 'Современная малоэтажная разреженная городская среда'
						end
					when mkd_median_level > 3
						then case
							when median_built_year between 1918 and case when id_gis in (777, 778) then 1959 else 1960 end -- верхняя граница 1959 для Москвы и Санкт-Петербурга и 1960 для всех остальных городов
								then 'Cоветская периметральная городская среда'
							else case
								when mkd_median_level between 4 and 9
									then 'Среднеэтажная микрорайонная городская среда'
								when mkd_median_level > 9
									then 'Многоэтажная микрорайонная городская среда'
							end
						end
				end
		end
	end::varchar quater_class

from quater_stat
where building_count > 1 -- отбрасываем кварталы с одним зданием...
;

create index on classify_v7(id_gis);
create index on classify_v7(quater_class);
create index on classify_v7(building_median_area_m2);
create index on classify_v7 using gist(geom);














-- !!! Дальше необкатано !!!



-- Пытаемся доклассифицировать здания
drop table if exists building_class2;
create temp table building_class2 as
select distinct on (b.id)
	b.id_gis,
	q.id quater_id,
	b.osm_type,
	case 
		when (q.quater_class = 'Нежилая городская среда' or q.quater_class is null)
			and q.building_median_area_m2 <= 250
			and b.area_m2 <= 300
			and b.osm_type = 'yes'
			then 'igs'::varchar
		/* часть которую нужно будет перенести в общую классификацию зданий */
		when b.osm_type = 'house' and b.building_type = 'other'
			then 'igs'::varchar
		when b.osm_type = 'detached' and b.building_type = 'other'
			then 'igs'::varchar
		-- Пока выключка
		/*
		when b.osm_type = 'garages' or b.osm_type = 'garage'
			or (
				b.area_m2 >= 500
					and st_isempty(st_buffer(b.geom::geography, -4)::geometry)
			)
			then 'garage'::varchar
		when b.osm_type = 'school'
			then 'school'::varchar
		when b.osm_type = 'kindergarten'
			then 'kindergarten'::varchar
		when b.osm_type = 'university'
			then 'university'::varchar
		when b.osm_type in ('industrial', 'tank', 'tanks')
			then 'industrial'::varchar
		when b.osm_type = 'warehouse'
			then 'warehouse'::varchar
		when b.osm_type = 'office'
			then 'office'::varchar
		when b.osm_type = 'parking'
			then 'parking'::varchar
		when b.osm_type in ('service', 'shed', 'transformer')
			then 'service'::varchar
		when b.osm_type in ('shop', 'store', 'supermarket')
			then 'shop'::varchar
		when b.osm_type = 'retail' or b.osm_type = 'commercial'
			then 'commercial'::varchar
		*/
		else b.building_type
	end building_type,
	case 
		when (q.quater_class = 'Нежилая городская среда' or q.quater_class is null)
			and q.building_median_area_m2 <= 250
			and b.area_m2 <= 300
			and b.osm_type = 'yes'
			then true::bool
		when (
			b.area_m2 >= 500
				and st_isempty(st_buffer(b.geom::geography, -4)::geometry)
		)
			then true::bool
		else false::bool
	end new_flag,
	b.building_type_source,
	b.built_year,
	b.built_year_source,
	b.population,
	b.population_source,
	b.levels,
	b.levels_source,
	b.area_m2,
	b.geom,
	b.okn_id,
	b.id
from russia.building_classify b
join classify_v7 q
	on q.id_gis = b.id_gis 
		and st_intersects(q.geom, b.geom) -- потом переделать с учётом случаем неполного вхождения
;

-- Записываем новые классифицированные домики
drop table if exists street_classify.building_classify_2;
create table street_classify.building_classify_2 as
select * from building_class2;

create index on street_classify.building_classify_2(id_gis);
create index on street_classify.building_classify_2(building_type);


-- попытка кластеризации
drop table if exists street_classify.cluster_1084;
create table street_classify.cluster_1084 as
select
	b.*,
	st_clusterdbscan(b.geom, 0.0005, 4) over(partition by b.building_type) cid
from building_class2 b
--join classify_v7 q
--	on b.quater_id = q.id
--		and (q.quater_class = 'Нежилая городская среда' or q.quater_class is null)
where b.quater_id = 438
;



-- перерасчёт кварталов
/* расчёт основных показателей */
drop table if exists quater_stat2;
create temp table quater_stat2 as 
select
	q.*,
	case 
		when max(b.id) filter(where b.building_type <> 'other') is not null
			then true
		else false
	end residential_function,
	coalesce(round((sum(b.area_m2))::numeric / 10000, 2), 0) footprint_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd'))::numeric / 10000, 2), 0) footprint_mkd_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'igs'))::numeric / 10000, 2), 0) footprint_igs_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'other'))::numeric / 10000, 2), 0) footprint_other_ha,

	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels between 1 and 3))::numeric / 10000, 2), 0) footprint_mkd_1_3_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels between 4 and 9))::numeric / 10000, 2), 0) footprint_mkd_4_9_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels > 9))::numeric / 10000, 2), 0) footprint_mkd_10_ha,

	count(b.*)::smallint building_count,
	coalesce(count(b.*) filter(where b.building_type = 'mkd'), 0)::smallint building_mkd_count,
	coalesce(count(b.*) filter(where b.building_type = 'igs'), 0)::smallint building_igs_count,
	coalesce(count(b.*) filter(where b.building_type = 'other'), 0)::smallint building_other_count,

	(count(b.*) filter(where b.built_year <= 1917 or o.id is not null))::int2 old_building_count,
	
	percentile_disc(0.5) within group(order by b.area_m2) building_median_area_m2,

	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type = 'mkd') mkd_median_level,
	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type = 'other') other_median_level,
	percentile_disc(0.5) within group(order by b.built_year) filter(where b.building_type <> 'other') median_built_year,
	mode() within group(order by b.built_year) filter(where b.building_type <> 'other') mode_built_year
from raw_quater q
join building_class2 b
	on q.id_gis = b.id_gis
		and st_intersects(q.geom, b.geom)
left join okn_matched o
	on o.id = b.id
		and o.id_gis = b.id_gis
group by q.id, q.id_gis, q.area_ha, q.geom;


/* второй проход. классификация кварталов по типам среды на основе расчитанных показателей */
drop table if exists street_classify.q_1084_v8;
create table street_classify.q_1084_v8 as
select
	*,
	case
		when residential_function is false
			or building_mkd_count + building_igs_count < 3 -- отбрасываем нежилые кварталы с 1-2 жилыми домами
				and building_count > 6
			then 'Нежилая городская среда'
		when old_building_count >= 0.7 * building_mkd_count
			and footprint_mkd_ha > footprint_igs_ha
			and building_mkd_count + building_igs_count > 0.2 * building_count -- !!! допущение
			then 'Историческая смешанная городская среда'
		else case
			when footprint_igs_ha > 0.7 * (footprint_mkd_ha + footprint_igs_ha)
				and footprint_igs_ha > 2 * footprint_mkd_ha
				and footprint_igs_ha > 0.6 * footprint_ha
					or (
						building_igs_count > 3 * building_other_count
							and footprint_igs_ha > 0.9 * footprint_mkd_ha -- !!! todo: поискать условия для низкого количества зданий
					)
					or (
						building_igs_count <= 5
							and building_other_count <= 3
							and building_mkd_count = 0
					)
				then 'Индивидуальная жилая городская среда'
			when footprint_mkd_ha > 0.7 * footprint_other_ha -- общие условия для многоквартирной застройки
				and footprint_mkd_ha >  2 * footprint_igs_ha
				then case
					when mkd_median_level between 1 and 3 -- медианная этажность
						and footprint_mkd_ha > footprint_igs_ha + footprint_other_ha
						and footprint_mkd_1_3_ha > footprint_mkd_4_9_ha
						and footprint_mkd_1_3_ha > 2 * footprint_mkd_10_ha
						then case 
							when median_built_year between 1918 and 1959
								or median_built_year is null -- !!!большое допущение в условиях отсутствия датировок
								then 'Советская малоэтажная разреженная городская среда'
							when median_built_year between 1960 and 1990
								then 'Позднесоветская малоэтажная разреженная городская среда'
							when median_built_year > 1990
								then 'Современная малоэтажная разреженная городская среда'
						end
					when mkd_median_level > 3
						then case
							when median_built_year between 1918 and case when id_gis in (777, 778) then 1959 else 1960 end -- верхняя граница 1959 для Москвы и Санкт-Петербурга и 1960 для всех остальных городов
								then 'Cоветская периметральная городская среда'
							else case
								when mkd_median_level between 4 and 9
									then 'Среднеэтажная микрорайонная городская среда'
								when mkd_median_level > 9
									then 'Многоэтажная микрорайонная городская среда'
							end
						end
				end
		end
	end::varchar quater_class

from quater_stat2
where building_count > 1 -- отбрасываем кварталы с одним зданием...
;



--Перепилить и добавить
--create index on russia.city_quater_type(id);
--create index on russia.city_quater_type(id_gis);
--create index on russia.city_quater_type(area_ha);
--create index on russia.city_quater_type(residential_function);
--create index on russia.city_quater_type(footprint_ha);
--create index on russia.city_quater_type(footprint_mkd_ha);
--create index on russia.city_quater_type(footprint_igs_ha);
--create index on russia.city_quater_type(footprint_other_ha);
--create index on russia.city_quater_type(footprint_mkd_1_3_ha);
--create index on russia.city_quater_type(footprint_mkd_4_9_ha);
--create index on russia.city_quater_type(footprint_mkd_10_ha);
--create index on russia.city_quater_type(building_count);
--create index on russia.city_quater_type(building_mkd_count);
--create index on russia.city_quater_type(building_igs_count);
--create index on russia.city_quater_type(building_other_count);
--create index on russia.city_quater_type(old_building_count);
--create index on russia.city_quater_type(mkd_median_level);
--create index on russia.city_quater_type(other_median_level);
--create index on russia.city_quater_type(median_built_year);
--create index on russia.city_quater_type(mode_built_year);
--create index on russia.city_quater_type(quater_class);
--create index on russia.city_quater_type using gist(geom);














/* Заново собираем статистику по кварталу -- надо потом вынести в классификацию кварталов */
/* Первый заход на всю Рооссию 39 мин. Возможно, из-за отсутствия индексов */
drop table if exists street_classify.quater_stat_tmp;
create table street_classify.quater_stat_tmp as
select
	q.id,
	q.id_gis,
	q.area_ha,
	q.geom,
	q.residential_function,
	q.footprint_ha,
	q.footprint_mkd_ha,
	q.footprint_igs_ha,
	q.footprint_other_ha,
	q.footprint_mkd_1_3_ha,
	q.footprint_mkd_4_9_ha,
	q.footprint_mkd_10_ha,
	q.building_count,
	q.building_mkd_count,
	q.building_igs_count,
	q.building_other_count,
	q.old_building_count,
	q.mkd_median_level,
	q.other_median_level,
	q.median_built_year,
	q.mode_built_year,
	q.quater_class,
	avg(b.area_m2) avg_building_area_m2,
	percentile_disc(0.5) within group(order by b.area_m2) median_building_area_m2,
	min(b.area_m2) min_building_area_m2,
	max(b.area_m2) max_building_area_m2
from russia.city_quater_type q
join russia.building_classify b 
	on b.id_gis = q.id_gis
		and st_intersects(b.geom, q.geom)
--where q.id_gis = 952
group by 	q.id,
	q.id_gis,
	q.area_ha,
	q.geom,
	q.residential_function,
	q.footprint_ha,
	q.footprint_mkd_ha,
	q.footprint_igs_ha,
	q.footprint_other_ha,
	q.footprint_mkd_1_3_ha,
	q.footprint_mkd_4_9_ha,
	q.footprint_mkd_10_ha,
	q.building_count,
	q.building_mkd_count,
	q.building_igs_count,
	q.building_other_count,
	q.old_building_count,
	q.mkd_median_level,
	q.other_median_level,
	q.median_built_year,
	q.mode_built_year,
	q.quater_class;

create index on street_classify.quater_stat_tmp(id_gis);
create index on street_classify.quater_stat_tmp using gist(geom);

drop table if exists street_classify.building_classify_2_pass;
create table street_classify.building_classify_2_pass as 
select
	b.id,
	b.id_gis,
	b.osm_type,
	case 
		when b.building_type = 'other' -- проверка, что тип здания не определён
			and b.osm_type = 'yes' -- чтобы не прихватить случайно то, что по ОСМ точно не жильё
			and (
				q.quater_class = 'Нежилая городская среда'
					or q.quater_class is null
			) -- проверка на тип среды из первой классификации
			and q.median_building_area_m2 <= 300
			and b.area_m2 between 40 and 300
			then 'igs'
		else b.building_type
	end building_type,
	case 
		when b.building_type = 'other' -- проверка, что тип здания не определён
			and (
				q.quater_class = 'Нежилая городская среда'
					or q.quater_class is null
			) -- проверка на тип среды из первой классификации
			and q.median_building_area_m2 <= 300
			and b.area_m2 between 40 and 300
			then 'Эвристика по площади'
		else b.building_type_source
	end building_type_source,
	b.built_year,
	b.built_year_source,
	b.population,
	b.population_source,
	b.levels,
	b.levels_source,
	b.area_m2,
	b.geom,
	b.okn_id,
	q.id quater_id
from street_classify.quater_stat_tmp q
join russia.building_classify b 
	on b.id_gis = q.id_gis
		and st_intersects(b.geom, q.geom)
--where q.id_gis = 952
;

create index on street_classify.building_classify_2_pass(id);
create index on street_classify.building_classify_2_pass(quater_id);
create index on street_classify.building_classify_2_pass(id_gis);
create index on street_classify.building_classify_2_pass using gist(geom);








/* генерация квартальной сетки и статистики на данных OpenStreetMap.
Алгоритм: https://docs.google.com/document/d/1y9j93d0SrOJo7WOOQ2IxIj72nmbNIem28eN_J3kTDXc/edit 
+ данные по году постройки из МИН ЖКХ */

/* время расчёта ~ 10 мин */

/* to do */
-- 1. Полностью перенести механизм сопоставления с реестром ОКН в скрипт типизации зданий
-- 2. Проверить почему osm типы house, detached не конвертировался в igs

/* !!! дебаг - задаём город !!! */
drop table if exists city;
create temp table city as
select id_gis::smallint, geom from index2019.data_boundary
--where id_gis < 2000 -- дебаг
;

create index on city(id_gis);
create index on city using gist(geom);


drop table if exists raw_quater;
create temp table raw_quater as
select
	id,
	id_gis::smallint,
	area_ha,
	geom
from russia.city_quater_type q
--where id_gis < 2000 -- дебаг
;

create index on raw_quater(id);
create index on raw_quater(id_gis);
create index on raw_quater using gist(geom);


/* расчёт основных показателей */
drop table if exists quater_stat;
create temp table quater_stat as 
select
	q.*,
	case 
		when max(b.id) filter(where b.building_type <> 'other') is not null
			then true
		else false
	end residential_function,
	coalesce(round((sum(b.area_m2))::numeric / 10000, 2), 0) footprint_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd'))::numeric / 10000, 2), 0) footprint_mkd_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'igs'))::numeric / 10000, 2), 0) footprint_igs_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'other'))::numeric / 10000, 2), 0) footprint_other_ha,

	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels between 1 and 3))::numeric / 10000, 2), 0) footprint_mkd_1_3_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels between 4 and 9))::numeric / 10000, 2), 0) footprint_mkd_4_9_ha,
	coalesce(round((sum(b.area_m2) filter(where b.building_type = 'mkd' and b.levels > 9))::numeric / 10000, 2), 0) footprint_mkd_10_ha,

	count(b.*)::smallint building_count,
	coalesce(count(b.*) filter(where b.building_type = 'mkd'), 0)::smallint building_mkd_count,
	coalesce(count(b.*) filter(where b.building_type = 'igs'), 0)::smallint building_igs_count,
	coalesce(count(b.*) filter(where b.building_type = 'other'), 0)::smallint building_other_count,

	count(b.*) filter(where b.built_year <= 1917 or b.okn_id is not null) old_building_count,
	
	percentile_disc(0.5) within group(order by b.area_m2) building_median_area_m2,

	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type = 'mkd') mkd_median_level,
	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type = 'other') other_median_level,
	percentile_disc(0.5) within group(order by b.built_year) filter(where b.building_type <> 'other') median_built_year,
	mode() within group(order by b.built_year) filter(where b.building_type <> 'other') mode_built_year
from raw_quater q
join street_classify.building_classify_2_pass b
	on q.id_gis = b.id_gis
		and q.id = b.quater_id 
group by q.id, q.id_gis, q.area_ha, q.geom;


/* классификация кварталов по типам среды на основе расчитанных показателей */
drop table if exists russia.city_quater_type_re;
create table russia.city_quater_type_re as
select
	*,
	case
		when residential_function is false
			or building_mkd_count + building_igs_count < 3 -- отбрасываем нежилые кварталы с 1-2 жилыми домами
				and building_count > 6
			then 'Нежилая городская среда'
		when old_building_count >= 0.7 * building_mkd_count
			and footprint_mkd_ha > footprint_igs_ha
			and building_mkd_count + building_igs_count > 0.2 * building_count -- !!! допущение
			then 'Историческая смешанная городская среда'
		else case
			when footprint_igs_ha > 0.7 * (footprint_mkd_ha + footprint_igs_ha)
				and footprint_igs_ha > 2 * footprint_mkd_ha
				and footprint_igs_ha > 0.6 * footprint_ha
					or (
						building_igs_count > 3 * building_other_count
							and footprint_igs_ha > 0.9 * footprint_mkd_ha -- !!! todo: поискать условия для низкого количества зданий
					)
					or (
						building_igs_count <= 5
							and building_other_count <= 3
							and building_mkd_count = 0
					)
				then 'Индивидуальная жилая городская среда'
			when footprint_mkd_ha > 0.7 * footprint_other_ha -- общие условия для многоквартирной застройки
				and footprint_mkd_ha >  2 * footprint_igs_ha
				then case
					when mkd_median_level between 1 and 3 -- медианная этажность
						and footprint_mkd_ha > footprint_igs_ha + footprint_other_ha
						and footprint_mkd_1_3_ha > footprint_mkd_4_9_ha
						and footprint_mkd_1_3_ha > 2 * footprint_mkd_10_ha
						then case 
							when median_built_year between 1918 and 1959
								or median_built_year is null -- !!!большое допущение в условиях отсутствия датировок
								then 'Советская малоэтажная разреженная городская среда'
							when median_built_year between 1960 and 1990
								then 'Позднесоветская малоэтажная разреженная городская среда'
							when median_built_year > 1990
								then 'Современная малоэтажная разреженная городская среда'
						end
					when mkd_median_level > 3
						then case
							when median_built_year between 1918 and case when id_gis in (777, 778) then 1959 else 1960 end -- верхняя граница 1959 для Москвы и Санкт-Петербурга и 1960 для всех остальных городов
								then 'Cоветская периметральная городская среда'
							else case
								when mkd_median_level between 4 and 9
									then 'Среднеэтажная микрорайонная городская среда'
								when mkd_median_level > 9
									then 'Многоэтажная микрорайонная городская среда'
							end
						end
				end
		end
	end::varchar quater_class

from quater_stat
where building_count > 1 -- отбрасываем кварталы с одним зданием...
;

create index on russia.city_quater_type_re(id_gis);
create index on russia.city_quater_type_re(quater_class);
--create index on russia.city_quater_type_re(building_median_area_m2);
create index on russia.city_quater_type_re using gist(geom);






/* Далее не обкатано */




drop table if exists street_classify.building_tmp;
create table street_classify.building_tmp as
select
	*,
	round((st_perimeter(geom::geography) / nullif(area_m2, 0))::numeric, 3) ratio,
	round((st_perimeter(geom::geography) / nullif(sqrt(area_m2), 0))::numeric, 3) ratio2
from street_classify.building_classify_2_pass
where id_gis <= 100;
create index on street_classify.building_tmp using gist(geom);
create index on street_classify.building_tmp(ratio);
create index on street_classify.building_tmp(ratio2);

drop table if exists reproj;
create temp table reproj as
select 
	*,
	st_transform(geom, _st_bestsrid(geom)) tr_geom
from street_classify.building_classify_2_pass
where id_gis <= 100;
create index on reproj(id_gis);
create index on reproj using gist(tr_geom);


drop table if exists street_classify.building_cluster;
create table street_classify.building_cluster as
select
	ST_ClusterDBSCAN(tr_geom, eps := 50, minpoints := 5) over () AS cid,
	id_gis,
	st_centroid(geom)::geometry(point, 4326) geom
from reproj
where id_gis <= 100
	and (
		(building_type = 'igs'
			and building_type_source <> 'Эвристика по площади'
		) -- отбираем ИЖС, которые не были дектектированы эвристикой по площади
			or (
				((building_type = 'other'
					and osm_type = 'yes'
				) -- Также берём всё, что не было классифицировано и не имело чёткого значения в OpenStreetMap
					or (building_type = 'igs'
						and building_type_source = 'Эвристика по площади'
					) --  + ИЖС, которые были дектектированы эвристикой по площади
				)
					and area_m2 between 40 and 300
					and round((st_perimeter(geom::geography) / nullif(area_m2, 0))::numeric, 3) > 0.25
					and round((st_perimeter(geom::geography) / nullif(sqrt(area_m2), 0))::numeric, 3) < 4.7
			) -- Последние  2 пункта с дополнительными фильтрами по геометрии (отношение периметра и площади)
	)
;


--create index on street_classify.building_classify_2_pass(osm_type);
-- Странный косяк к которому надо будет вернуться!!!
--update street_classify.building_classify_2_pass 
--	set building_type = 'igs'
--	where osm_type = 'house';
	

-- Убрать из первичной классификации детект ИЖС по площади!!!









