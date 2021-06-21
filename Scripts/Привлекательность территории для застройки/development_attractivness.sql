/* Привлекательность территории для строительства */
/* Время расчёта для всех городов России ~ 20 ч. */
/* Время расчёта для Перми ~ 40 сек. */
/* Время расчёта для Екатеринбурга ~ 2 мин. */
--
/* В качестве исходника берём предрасчитанные урбанизированные территории городов и откладываем 800 м. буффер */
drop table if exists urban_buffer;
create temp table urban_buffer as
select id_gis, st_buffer(geom::geography, 800)::geometry geom
from russia.city_built_area_light
--where id_gis <= 100
-- select * from urban_buffer;
;
create index on urban_buffer using gist(geom);
create index on urban_buffer(id_gis)
;
/* Пересечением с буфером выбираем ячейки гексагональной сетки 1 га. */
drop table if exists grid_urban;
create temp table grid_urban as
select distinct on(g.id)
	g.id,
	g.id_gis,
	round((st_area(g.geom::geography)::numeric / 10000)::numeric, 2) area_ha,
	g.geom
from urban_buffer u
join russia.hex_stat_2020 g
	on u.id_gis = g.id_gis 
		and st_intersects(g.geom, u.geom)
--where u.id_gis = 1038
--	and st_isvalid(u.geom)
group by 
	g.id,
	g.id_gis,
	g.geom
-- select * from grid_urban;
;
create index on grid_urban using gist(geom);
create index on grid_urban(id_gis)
;
/* Фильтруем сетку. Выбрасываем водные поверхности. */
drop table if exists grid_filtered_1;
create temp table grid_filtered_1 as
select distinct on(g.id) g.*
from grid_urban g
left join embankment.city_waterarea w
	on g.id_gis = w.id_gis 
		and st_intersects(g.geom, w.geom)
--where g.id_gis = 1038
	and w.id is null
group by 
	g.id,
	g.id_gis,
	g.area_ha,
	g.geom
-- select * from grid_filtered_1;
-- select * from embankment.city_waterarea where id_gis = 1038;
;
create index on grid_filtered_1 using gist(geom);
create index on grid_filtered_1(id_gis)
;
/* Фильтруем сетку. Выбрасываем благоустроенное озеленение (по данным Индекса качества городской среды). */
drop table if exists grid_filtered_2;
create temp table grid_filtered_2 as
select g.*
from grid_filtered_1 g
left join index2020.data_greenery gr
	on g.id_gis = gr.id_gis 
		and st_intersects(g.geom, gr.geom)
--where g.id_gis = 1038
group by 
	g.id,
	g.id_gis,
	g.area_ha,
	g.geom
-- оставляем ячейки, пересекающие зелень менее чем на 10% от их площади:                                                                 
having coalesce(sum(st_area(st_intersection(g.geom, gr.geom)::geography)), 0) <=  0.1 * g.area_ha * 10000
-- select * from index2020.data_greenery where id_gis = 1038 and id is null;
;
create index on grid_filtered_2 using gist(geom);
create index on grid_filtered_2(id_gis)
;
/* Фильтруем сетку. Выбрасываем кладбища (по данным Open Street Map). */
drop table if exists grid_filtered_3;
create temp table grid_filtered_3 as
select g.*
from grid_filtered_2 g
left join russia.landuse_osm l
--	on g.id_gis = l.id_gis 
		on st_intersects(g.geom, l.geom)
		and l.type = 'cemetery'
--where g.id_gis = 1038
group by 
	g.id,
	g.id_gis,
	g.area_ha,
	g.geom
-- оставляем ячейки, пересекающие зелень менее чем на 10% от их площади:                                                                 
having coalesce(sum(st_area(st_intersection(g.geom, l.geom)::geography)), 0) <=  0.1 * g.area_ha * 10000
-- select * from index2020.data_greenery where id_gis = 1038 and id is null;
;
create index on grid_filtered_3 using gist(geom);
create index on grid_filtered_3 (id_gis)
;
-- Рассчёт плотности застройки (с учётом суммарной поэтажной площади зданий)
drop table if exists density;
create temp table density as
select
	g.id,
	g.id_gis,
	g.area_ha,
	coalesce(round(((sum(st_area(st_intersection(g.geom, b.geom)::geography) * case when b.levels is null then 1 else b.levels end) / 1000 / nullif(g.area_ha, 0)) * 0.95)::numeric, 2), 0) build_density_1km2_ha,
	g.geom
from grid_filtered_3 g
left join street_classify.building_classify_2_pass b
	on b.id_gis = g.id_gis 
		and st_intersects(g.geom, b.geom)
--where g.id_gis = 1038
group by 
	g.id,
	g.id_gis,
	g.area_ha,
	g.geom
;
create index on density (id);
create index on density (id_gis);
create index on density (build_density_1km2_ha)
;
/* --  */
drop table if exists ipa_ita;
create temp table ipa_ita as
select
	g.id,
	g.id_gis,
	max(
		case
			when i.ita > 1 then 3::smallint
			when i.ita between 0.1 and 1 then 2::smallint
			else 1::smallint
		end
	) ita,
	max(
		case
			when i.ipa > 1 then 3::smallint
			when i.ipa between 0.1 and 1 then 2::smallint
			else 1::smallint
		end
	) ipa
from grid_filtered_3 g
left join russia.ipa_ita i
	on st_intersects(g.geom, i.geom)
			and i.id_gis = g.id_gis 			
--where g.id_gis = 1038
group by 
	g.id,
	g.id_gis,
	g.geom
;
create index on ipa_ita (id);
create index on ipa_ita (id_gis);
create index on ipa_ita (ipa);
create index on ipa_ita (ita)
;
/* Считаем привлекательность */
drop table if exists dens_grid;
create temp table dens_grid as
select
	d.*,
	case 
		when build_density_1km2_ha < 0.6 then 'Свободный'
		when build_density_1km2_ha between 0.6 and 5 then 'Низкая плотность'
		when build_density_1km2_ha between 5.01 and 10 then 'Средняя плотность'
		when build_density_1km2_ha > 10 then 'Высокая плотность'
	end build_density_class,
	case 
		when build_density_1km2_ha between 0.6 and 1 then '1 Дачная городская среда'
		when build_density_1km2_ha between 1.01 and 2 then '2 Сельская городская среда'
		when build_density_1km2_ha between 2.01 and 4 then '3 Историческая индивидуальная городская среда'
--		when build_density_1km2_ha between 4 and 5 then '4 Современная индивидуальная городская среда' 4
		when build_density_1km2_ha between 4.01 and 5 then '5 Советская малоэтажная разреженная городская среда'
		when build_density_1km2_ha between 5.01 and 7 then '6 Современная блокированная городская среда'
		when build_density_1km2_ha between 7.01 and 8 then '7 Советская малоэтажная периметральная городская среда'
		when build_density_1km2_ha between 8.01 and 10 then '8 Историческая разреженная городская среда'
--		when build_density_1km2_ha between 1.01 and 5 then '9 Советская среднеэтажная микрорайонная городская среда' 8
		when build_density_1km2_ha between 10.01 and 13 then '10 Современная малоэтажная городская среда'
		when build_density_1km2_ha between 13.01 and 14 then '11 Историческая периметральная городская среда'
		when build_density_1km2_ha between 14.01 and 15 then '12 Советская малоэтажная микрорайонная городская среда'
		when build_density_1km2_ha between 15.01 and 23 then '13 Советская среднеэтажная периметральная городская среда'
		when build_density_1km2_ha > 23 then '14 Современная многоэтажная городская среда'
	end build_density_type,
	case 
		when build_density_1km2_ha < 0.6 then 0::smallint
		when build_density_1km2_ha between 0.6 and 5 then 1::smallint
		when build_density_1km2_ha between 5.01 and 10 then 2::smallint
		when build_density_1km2_ha > 10 then 3::smallint
	end build_density_score,
	i.ipa,
	i.ita,
	case
		when build_density_1km2_ha < 0.6
			then ceil((0.7 * i.ita + 0.3 * i.ipa)::numeric)
		else ceil((0.5 * i.ita + 0.5 * i.ipa)::numeric)
	end sum_ipa_ita
from density d
left join ipa_ita i using(id)
;
create index on dens_grid using gist(geom);
create index on dens_grid using gist((geom::geography));
create index on dens_grid(build_density_1km2_ha);
create index on dens_grid(sum_ipa_ita)
;
drop table if exists priority;
create temp table priority as
select
	d1.*,
	case 
		when d1.build_density_1km2_ha < 0.6 and d1.sum_ipa_ita >= 2 then 'Высокопривлекательная'
		when d1.build_density_1km2_ha < 0.6 and d1.sum_ipa_ita < 2 and count(d2.id) > 0 is not null then 'Среднепривлекательная'
		when d1.build_density_1km2_ha < 0.6 and d1.sum_ipa_ita < 2 and count(d2.id) > 0 is null then 'Низкопривлекательная'		
		when d1.build_density_1km2_ha between 0.6 and 5 and d1.sum_ipa_ita = 3 then 'Высокопривлекательная'
		when d1.build_density_1km2_ha between 0.6 and 5 and d1.sum_ipa_ita = 2 then 'Среднепривлекательная'
		when d1.build_density_1km2_ha between 5.01 and 10 and d1.sum_ipa_ita = 3 then 'Среднепривлекательная'
		else 'Низкопривлекательная'
	end priority
from dens_grid d1
left join dens_grid d2
	on st_dwithin(d1.geom::geography, d2.geom::geography, 420)
		and d2.sum_ipa_ita >= 2
		and d1.id <> d2.id
group by
	d1.id,
	d1.id_gis,
	d1.area_ha,
	d1.build_density_1km2_ha,
	d1.geom,
	d1.build_density_class,
	d1.build_density_type,
	d1.build_density_score,
	d1.ipa,
	d1.ita,
	d1.sum_ipa_ita
;
create index on priority(id);
create index on priority(id_gis)
;

-- Сношаем с WalkScore
drop table if exists russia.development_attractivness;
create table russia.development_attractivness as
select
	i.*,
	case
		when i.priority = 'Низкопривлекательная'  and w.walkscore_r_all < 40 then 11::smallint
		when i.priority = 'Низкопривлекательная'  and w.walkscore_r_all between 40 and 80 then 12::smallint
		when i.priority = 'Низкопривлекательная'  and w.walkscore_r_all > 80 then 13::smallint
		when i.priority = 'Среднепривлекательная' and w.walkscore_r_all < 40 then 21::smallint
		when i.priority = 'Среднепривлекательная' and w.walkscore_r_all between 40 and 80 then 22::smallint
		when i.priority = 'Среднепривлекательная' and w.walkscore_r_all > 80 then 23::smallint
		when i.priority = 'Высокопривлекательная' and w.walkscore_r_all < 40 then 31::smallint
		when i.priority = 'Высокопривлекательная' and w.walkscore_r_all between 40 and 80 then 32::smallint
		when i.priority = 'Высокопривлекательная' and w.walkscore_r_all > 80 then 33::smallint
	end priority_grade
from priority i 
left join russia.hex_stat_2020 w 
	on w.id_gis = i.id_gis 
		and w.id = i.id
;
alter table russia.development_attractivness add primary key(id);
create index on russia.development_attractivness using gist(geom);
create index on russia.development_attractivness(build_density_1km2_ha);
create index on russia.development_attractivness(build_density_class);
create index on russia.development_attractivness(build_density_type);
create index on russia.development_attractivness(build_density_score);
create index on russia.development_attractivness(ipa);
create index on russia.development_attractivness(ita);
create index on russia.development_attractivness(sum_ipa_ita);
create index on russia.development_attractivness(priority);
create index on russia.development_attractivness(priority_grade)
;
/* Комментарии */
comment on table russia.development_attractivness is 'Привлекательность территории под развитие';
comment on column russia.development_attractivness.id is 'Первичный ключ';
comment on column russia.development_attractivness.geom is 'Геометрия';
comment on column russia.development_attractivness.area_ha is 'Площадь ячейки (с учётом обрезки по границам города)';
comment on column russia.development_attractivness.build_density_1km2_ha is 'Плотность застройки по футпринтам зданий, км2/га';
comment on column russia.development_attractivness.build_density_class is 'Класс территории по плотности застройки (Свободный/Низкая плотность/Высокая плотность)';
comment on column russia.development_attractivness.build_density_type is 'Средневзвешенный тип среды для ячейки (
1 Дачная городская среда
2 Сельская городская среда
3 Историческая индивидуальная городская среда
4 Современная индивидуальная городская среда
5 Советская малоэтажная разреженная городская среда
6 Современная блокированная городская среда
7 Советская малоэтажная периметральная городская среда
8 Историческая разреженная городская среда
9 Советская среднеэтажная микрорайонная городская среда
10 Современная малоэтажная городская среда
11 Историческая периметральная городская среда
12 Советская малоэтажная микрорайонная городская среда
13 Советская среднеэтажная периметральная городская среда
14 Современная многоэтажная городская среда)';
comment on column russia.development_attractivness.build_density_score is 'Уровень застроенности по шкале от 0 до 3';
comment on column russia.development_attractivness.ipa is 'Максимальный индекс пешеходной активности в ячейке (на основе данных ipa-ita,  рассчитанных Сергеем Тюпановым)';
comment on column russia.development_attractivness.ita is 'Максимальный индекс транспортной активности в ячейке (на основе данных ipa-ita,  рассчитанных Сергеем Тюпановым)';
comment on column russia.development_attractivness.sum_ipa_ita is 'Средневзвешенная пешеходно-транспортная активность в ячейке (если плотность застройки < 0.6, то соотношение веса 0.7/0.3 в пользу транспортной активности. При более высокой плотности соотношение пешеходной и транспортной активности 0.5/0.5)';
comment on column russia.development_attractivness.priority is 'Базовый класс привлекательности территории (Низкопривлекательная/Среднепривлекательная/Высокопривлекательная)';
comment on column russia.development_attractivness.priority_grade is 'Взвешенная привлекательности территории (базовая привлекательность территории взвешенная на итоговом индексе WalkScore по трём классам:
- < 40
- 40 - 80
- > 80
Итоговое ранжирование (больше -> привлекательнее):
Низкопривлекательные
- 11
- 12
- 13
Среднепривлекательные
- 21
- 22
- 23
Высокопривлекательные
- 31
- 32
- 33
)';
