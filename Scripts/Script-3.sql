/* Заново собираем статистику по кварталу -- надо потом вынести в классификацию кварталов */
/* Первый заход на всю Рооссию 39 мин. Возможно, из-за отсутствия индексов */
drop table if exists street_classify.quater_stat_tmp2;
create table street_classify.quater_stat_tmp2 as
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
where q.id_gis in (
	6,8,10,34,45,73,84,87,115,155,175,184,185,200,205,
	225,235,274,296,384,400,408,425,444,452,468,472,
	474,487,504,530,552,575,619,635,636,645,678,680,
	689,721,725,737,742,751,1090,1093,1103,1120,1121,
	1122,1123
	)
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

create index on street_classify.quater_stat_tmp2(id_gis);
create index on street_classify.quater_stat_tmp2 using gist(geom);

drop table if exists street_classify.building_classify_2_pass2;
create table street_classify.building_classify_2_pass2 as 
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
from street_classify.quater_stat_tmp2 q
join russia.building_classify b 
	on b.id_gis = q.id_gis
		and st_intersects(b.geom, q.geom)
where q.id_gis in (
	6,8,10,34,45,73,84,87,115,155,175,184,185,200,205,
	225,235,274,296,384,400,408,425,444,452,468,472,
	474,487,504,530,552,575,619,635,636,645,678,680,
	689,721,725,737,742,751,1090,1093,1103,1120,1121,
	1122,1123
	)
;

create index on street_classify.building_classify_2_pass2(id);
create index on street_classify.building_classify_2_pass2(quater_id);
create index on street_classify.building_classify_2_pass2(id_gis);
create index on street_classify.building_classify_2_pass2 using gist(geom);
















































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
where id_gis in (
	6,8,10,34,45,73,84,87,115,155,175,184,185,200,205,
	225,235,274,296,384,400,408,425,444,452,468,472,
	474,487,504,530,552,575,619,635,636,645,678,680,
	689,721,725,737,742,751,1090,1093,1103,1120,1121,
	1122,1123
	)
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
from russia.city_quater_type
where id_gis in (
	6,8,10,34,45,73,84,87,115,155,175,184,185,200,205,
	225,235,274,296,384,400,408,425,444,452,468,472,
	474,487,504,530,552,575,619,635,636,645,678,680,
	689,721,725,737,742,751,1090,1093,1103,1120,1121,
	1122,1123
	)
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
join street_classify.building_classify_2_pass2 b
	on q.id_gis = b.id_gis
		and q.id = b.quater_id 
group by q.id, q.id_gis, q.area_ha, q.geom;


/* классификация кварталов по типам среды на основе расчитанных показателей */
drop table if exists russia.city_quater_type_re2;
create table russia.city_quater_type_re2 as
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

create index on russia.city_quater_type_re2(id_gis);
create index on russia.city_quater_type_re2(quater_class);
--create index on russia.city_quater_type_re(building_median_area_m2);
create index on russia.city_quater_type_re2 using gist(geom);




insert into russia.city_quater_type_re (
	id,
	id_gis,
	area_ha,
	geom,
	residential_function,
	footprint_ha,
	footprint_mkd_ha,
	footprint_igs_ha,
	footprint_other_ha,
	footprint_mkd_1_3_ha,
	footprint_mkd_4_9_ha,
	footprint_mkd_10_ha,
	building_count,
	building_mkd_count,
	building_igs_count,
	building_other_count,
	old_building_count,
	building_median_area_m2,
	mkd_median_level,
	other_median_level,
	median_built_year,
	mode_built_year,
	quater_class
)
select 
	500000 + id id,
	id_gis,
	area_ha,
	geom,
	residential_function,
	footprint_ha,
	footprint_mkd_ha,
	footprint_igs_ha,
	footprint_other_ha,
	footprint_mkd_1_3_ha,
	footprint_mkd_4_9_ha,
	footprint_mkd_10_ha,
	building_count,
	building_mkd_count,
	building_igs_count,
	building_other_count,
	old_building_count,
	building_median_area_m2,
	mkd_median_level,
	other_median_level,
	median_built_year,
	mode_built_year,
	quater_class
from russia.city_quater_type_re2

select max(id) from russia.city_quater_type_re



