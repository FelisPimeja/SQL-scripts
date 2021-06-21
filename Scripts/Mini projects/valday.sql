/* Расчёт WalkScore на данных Яндекса и доп слое "благоустроенного озеленения" из состава индекса 2020 */
/* Время расчёта 11,5 часов на данных 2020 г. */
/* Фильтрация по id_gis */
--drop table if exists city;
--create temp table city as
--select id_gis from russia.city
--;
--create index on city(id_gis);
create index on tmp.valday_grid using gist((st_centroid(geom)::geography));


/* Подготовка POI Яндекса для расчёта WalkScore */
drop table if exists poi;
create temp table poi as
select --distinct on (p.company_id) -- По идее дубликаты рубрик мёрджить не нужно!!!
--	(row_number() over())::int id,
	p.geom::geography geog,
	p.name, 
	p.category_name,
	case
		when p.category_name ilike '%Детский сад%' then 1::smallint
		when p.category_name ilike '%Общеобразовательная школа%'
			or p.category_name ilike '%Частная школа%'
				then 2::smallint
		when p.category_name ilike '%ВУЗ%' then 3::smallint
		when p.category_name ilike 'Продукты питания'
			or p.category_name ilike '%Продуктовый рынок%'
			or p.category_name ilike '%Рынок%'
				then 4::smallint
		when p.category_name ilike '%агазин%' and p.category_name not ilike '%Продукты питания%' then 5::smallint
		when p.category_name ilike '%клиник%'
			or p.category_name ilike '%Медицин%'
				then 6::smallint
		when p.category_name ilike '%Быстрое питание%' then 7::smallint
		when p.category_name ilike '%Кафе%' then 8::smallint
		when p.category_name ilike '%Ресторан%' then 9::smallint
		when p.category_name ilike '%Кинотеатр%' then 10::smallint
		when p.category_name ilike '%Театр%'
			or p.category_name ilike '%Музей%'
				then 11::smallint
		when p.category_name ilike '%Развлечения%' then 12::smallint
--		when rubrics = '' then 13::smallint
		when p.category_name ilike '%Библиотека%' then 14::smallint
		when p.category_name ilike '%Спортивная школа%'
			or p.category_name ilike '%Спортивно-развлекательный центр%'
			or p.category_name ilike '%Спортивное поле%'
			or p.category_name ilike '%Спортивный клуб%'
			or p.category_name ilike '%Спортивный комплекс%'
			or p.category_name ilike '%Спортплощадка%'
			or p.category_name ilike '%Фитнес-клуб%'
				then 15::smallint
	end wlk_ind
from tmp.valday_grid c
left join russia.poi_yandex_2020 p
	on st_intersects(p.geom, c.geom);

-- Добавляем точки точки зелёных насаждений общего пользования из контуров "благоустроенного озеленения" из состава Индекса качества городской среды 2020
insert into poi (geog, wlk_ind)
select
	(st_dumppoints(g.geom)).geom::geometry::geography geog,
	13::smallint wlk_ind
from index2020.data_greenery g
where g.id_gis in (98, 486);

-- Индексы
alter table poi add column id serial primary key;
create index on poi(wlk_ind);
create index on poi using gist(geog);

drop table if exists tmp.valday_poi;
create table tmp.valday_poi as
	select
		geog::geometry(point, 4326) geom,
		name, 
		category_name,
		wlk_ind
	from poi;

drop table if exists hex_grid;
create temp table hex_grid as select id, st_centroid(geom)::geography geog from tmp.valday_grid;
create index on hex_grid using gist(geog);


/* Расчёт WalkScore */
-- Расчёт исходных расстояний до ближайших точек
drop table if exists sc;
create temp table sc as 
--explain
with d1 as (
    select
        g.id,
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  1) kind, --  800
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  2) schl, -- 1000
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  3) univ, -- 1200
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  4) food, -- 1200
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  5) shop, --  800
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  6) heal, -- 1000
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  7) fast, --  800
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  8) cafe, -- 1000
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind =  9) rest, -- 1200
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind = 10) cine, -- 1600
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind = 11) thea, -- 1400
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind = 12) entr, -- 1200
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind = 13) park, -- 1200
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind = 14) bibl, -- 1400
        min(st_distance(g.geog, p.geog)) filter(where p.wlk_ind = 15) fitn  -- 1200 
    from hex_grid g
    left join poi p
        on st_dwithin(g.geog, p.geog, 1600)
    group by g.id
)
select
	d1.id,
    case
        when kind < 200 then 100
        when kind > 199 and kind <  400 then 100 - (kind - 200) /  4
        when kind > 399 and kind <  800 then  50 - (kind - 400) /  8
        else 0
    end kind,
	case
        when schl < 300 then 100
        when schl > 299 and schl <  500 then 100 - (schl - 300) /  4
        when schl > 499 and schl < 1000 then  50 - (schl - 500) / 10
        else 0
    end schl,
	case
        when univ < 400 then 100
        when univ > 399 and univ <  800 then 100 - (univ - 400) /  8
        when univ > 799 and univ < 1200 then  50 - (univ - 800) /  8
        else 0
    end univ,
	case
        when food < 400 then 100
        when food > 399 and food <  600 then 100 - (food - 400) /  4
        when food > 599 and food < 1200 then  50 - (food - 600) / 12
        else 0
    end food,
	case
        when shop < 200 then 100
        when shop > 199 and shop <  400 then 100 - (shop - 200) /  4
        when shop > 399 and shop <  800 then  50 - (shop - 400) /  8
        else 0
    end shop,
	case
        when heal < 300 then 100
        when heal > 299 and heal <  500 then 100 - (heal - 300) /  4
        when heal > 499 and heal < 1000 then  50 - (heal - 500) / 10
        else 0
    end heal,
	case
        when fast < 200 then 100
        when fast > 199 and fast <  400 then 100 - (fast - 200) /  4
        when fast > 399 and fast <  800 then  50 - (fast - 400) /  8
        else 0
    end fast,
	case
        when cafe < 300 then 100
        when cafe > 299 and cafe <  500 then 100 - (cafe - 300) /  4
        when cafe > 499 and cafe < 1000 then  50 - (cafe - 500) / 10
        else 0
    end cafe,
	case
        when rest < 400 then 100
        when rest > 399 and rest <  600 then 100 - (rest - 400) /  4
        when rest > 599 and rest < 1200 then  50 - (rest - 600) / 12
        else 0
    end rest,
	case
        when cine < 600 then 100
        when cine > 599 and cine <  800 then 100 - (cine - 600) /  4
        when cine > 799 and cine < 1600 then  50 - (cine - 800) / 16
        else 0
    end cine,
	case
        when thea < 500 then 100
        when thea > 499 and thea <  700 then 100 - (thea - 500) /  4
        when thea > 699 and thea < 1400 then  50 - (thea - 700) / 14
        else 0
    end thea,
	case
        when entr < 400 then 100
        when entr > 399 and entr <  600 then 100 - (entr - 400) /  4
        when entr > 599 and entr < 1200 then  50 - (entr - 600) / 12
        else 0
    end entr,
	case
        when park < 400 then 100
        when park > 399 and park <  600 then 100 - (park - 400) /  4
        when park > 599 and park < 1200 then  50 - (park - 600) / 12
        else 0
    end park,
	case
        when bibl < 500 then 100
        when bibl > 499 and bibl <  700 then 100 - (bibl - 500) /  4
        when bibl > 699 and bibl < 1400 then  50 - (bibl - 700) / 14
        else 0
    end bibl,
	case
        when fitn < 400 then 100
        when fitn > 399 and fitn <  600 then 100 - (fitn - 400) /  4
        when fitn > 599 and fitn < 1200 then  50 - (fitn - 600) / 12
        else 0
    end fitn
from d1
;
-- Подсчёт средневзвешенных групповых значений индекса
drop table if exists r0;
create temp table r0 as 
select
    id,
    case
        when kind = schl and kind = univ then kind
        when kind > schl and kind = univ then ((3 * kind) + (2 * schl)) / 5
        when kind < schl and kind = univ then (kind + schl) / 2
        when kind = schl and kind > univ then ((3 * kind) + (2 * univ)) / 5
        when kind > schl and kind > univ then ((3 * ((3 * kind) + (2 * schl)) / 5) + (2 * univ)) / 5
        when kind < schl and kind > univ then ((3 * (kind + schl) / 2) + (2 * univ)) / 5
        when kind = schl and kind < univ then (kind + univ) / 2
        when kind > schl and kind < univ then (((3 * kind) + (2 * schl)) / 5 + univ) / 2
        else ((kind + schl) / 2 + univ) / 2
    end r_1,
    case
        when food  = heal and food = shop then food
        when food != heal and (food + heal) / 2 = shop then (food + heal) / 2
        when food  = heal and food > shop then ((3 * food)+(2 * shop)) / 5
        when food != heal and (food + heal) / 2 > shop then ((3 * (food + heal) / 2) + (2 * shop)) / 5
        when food  = heal and food < shop then (food + shop) / 2
        else ((food + heal) / 2 + shop) / 2
    end r_2,
    case
        when rest = cafe and rest = fast then rest
        when rest > cafe and rest = fast then ((3 * rest) + (2 * cafe)) / 5
        when rest < cafe and rest = fast then (rest + cafe) / 2
        when rest = cafe and rest > fast then ((3 * rest) + (2 * fast)) / 5
        when rest > cafe and rest > fast then ((3 * ((3 * rest) + (2 * cafe)) / 5) + (2 * fast)) / 5
        when rest < cafe and rest > fast then ((3 * (rest + cafe) / 2) + (2 * fast)) / 5
        when rest = cafe and rest < fast then (rest + fast) / 2
        when rest > cafe and rest < fast then (((3 * rest) + (2 * cafe)) / 5 + fast) / 2
        else ((rest + cafe) / 2 + fast) / 2
    end r_3,
    case
        when cine = entr and cine = thea then cine
        when cine > entr and cine = thea then ((3 * cine) + (2 * entr)) / 5
        when cine < entr and cine = thea then (cine + entr) / 2
        when cine = entr and cine > thea then ((3 * cine) + (2 * thea)) / 5
        when cine > entr and cine > thea then ((3 * ((3 * cine) + (2 * entr)) / 5) + (2 * thea)) / 5
        when cine < entr and cine > thea then ((3 * (cine + entr) / 2) + (2 * thea)) / 5
        when cine = entr and cine < thea then (cine + thea) / 2
        when cine > entr and cine < thea then (((3 * cine) + (2 * entr)) / 5 + thea) / 2
        else ((cine + entr) / 2 + thea) / 2
    end r_4,
    case
        when park  = fitn and park = bibl then park
        when park != fitn and (park + fitn) / 2 = bibl then (park + fitn) / 2
        when park  = fitn and park > bibl then ((3 * park) + (2 * bibl)) / 5
        when park != fitn and (park + fitn) / 2 > bibl then ((3 * (park + fitn) / 2) + (2 * bibl)) / 5
        when park  = fitn and park < bibl then (park + bibl) / 2
        else ((park + fitn) / 2 + bibl) / 2
    end r_5
from sc;


-- Второй шаг взвешивания групп
drop table if exists r1;
create temp table r1 as 
select
    r0.id,
    sc.kind,
    sc.schl,
    sc.univ,
    sc.food,
    sc.heal,
    sc.shop,
    sc.rest,
    sc.cafe,
    sc.fast,
    sc.cine,
    sc.entr,
    sc.thea,
    sc.park,
    sc.fitn,
    sc.bibl,
    case
        when (kind  = 100 or schl  = 100 or univ  = 100) and r_1 * 1.2 <  100 then r_1 * 1.2
        when (kind  = 100 or schl  = 100 or univ  = 100) and r_1 * 1.2 >= 100 then 100
        else r_1
    end r_1,
    case
        when (food  = 100 or shop  = 100 or heal = 100) and r_2 * 1.2 <  100 then r_2 * 1.2
        when (food  = 100 or shop  = 100 or heal = 100) and r_2 * 1.2 >= 100 then 100
        else r_2
    end r_2,
    case
        when (rest  = 100 or cafe  = 100 or fast  = 100) and r_3 * 1.2 <  100 then r_3 * 1.2
        when (rest  = 100 or cafe  = 100 or fast  = 100) and r_3 * 1.2 >= 100 then 100
        else r_3
    end r_3,
    case
        when (park = 100 or bibl  = 100 or fitn  = 100) and r_4 * 1.2 <  100 then r_4 * 1.2
        when (park = 100 or bibl  = 100 or fitn  = 100) and r_4 * 1.2 >= 100 then 100
        else r_4
    end r_4,
    case
        when (cine  = 100 or thea = 100 or entr  = 100) and r_5 * 1.2 <  100 then r_5 * 1.2
        when (cine  = 100 or thea = 100 or entr  = 100) and r_5 * 1.2 >= 100 then 100
        else r_5
    end r_5
from r0
join sc using(id);

-- Расчёт итогового индекса WalkScore
drop table if exists tmp.valday_walkscore;
create table tmp.valday_walkscore as
select
	g.id,
	g.geom,
	sc.kind::int2,
	sc.schl::int2,
	sc.univ::int2,
	sc.food::int2,
	sc.shop::int2,
	sc.heal::int2,
	sc.rest::int2,
	sc.cafe::int2,
	sc.fast::int2,
	sc.cine::int2,
	sc.entr::int2,
	sc.thea::int2,
	sc.park::int2,
	sc.fitn::int2,
	sc.bibl::int2,
	r1.r_1::int2,
	r1.r_2::int2,
	r1.r_3::int2,
	r1.r_4::int2,
	r1.r_5::int2,
	((r_1+r_2+r_3+r_4+r_5)/5)::int2 r_all
from tmp.valday_grid g
left join sc using(id)
left join r1 using(id);

/* Первичный ключ и индексы*/
alter table tmp.valday_walkscore add primary key(id);
create index on tmp.valday_walkscore (kind);
create index on tmp.valday_walkscore (schl);
create index on tmp.valday_walkscore (univ);
create index on tmp.valday_walkscore (food);
create index on tmp.valday_walkscore (shop);
create index on tmp.valday_walkscore (heal);
create index on tmp.valday_walkscore (fast);
create index on tmp.valday_walkscore (cafe);
create index on tmp.valday_walkscore (rest);
create index on tmp.valday_walkscore (cine);
create index on tmp.valday_walkscore (thea);
create index on tmp.valday_walkscore (entr);
create index on tmp.valday_walkscore (park);
create index on tmp.valday_walkscore (bibl);
create index on tmp.valday_walkscore (fitn);
create index on tmp.valday_walkscore (r_1);
create index on tmp.valday_walkscore (r_2);
create index on tmp.valday_walkscore (r_3);
create index on tmp.valday_walkscore (r_4);
create index on tmp.valday_walkscore (r_5);
create index on tmp.valday_walkscore (r_all);
create index on tmp.valday_walkscore using gist(geom);
--cluster walkscore.walkscore using walkscore_geom_idx; -- Ахтунг - кластеризация занимает 25 часов!!!

/* Комментарии */
comment on table tmp.valday_walkscore is 'Индекс пешеходной доступности WalkScore посчитанный на данных Яндекс 2020 и гексагональной сетке 1 га, построенной для Индекса качества городской среды 2020';
comment on column tmp.valday_walkscore.id is 'Первичный ключ';
comment on column tmp.valday_walkscore.kind is 'Уровень доступности детских садов в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.schl is 'Уровень доступности школ в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.univ is 'Уровень доступности высших учебных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.food is 'Уровень доступности продуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.shop is 'Уровень доступности непродуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.heal is 'Уровень доступности учреждений здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.fast is 'Уровень доступности предприятий быстрого питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.cafe is 'Уровень доступности кафе в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.rest is 'Уровень доступности ресторанов в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.cine is 'Уровень доступности кинотеатров в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.thea is 'Уровень доступности театров в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.entr is 'Уровень доступности развлекательных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.park is 'Уровень доступности парков и других зелёных зон в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.bibl is 'Уровень доступности библиотек в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.fitn is 'Уровень доступности фитнес центров и спортивных учреждений в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.r_1 is 'Средневзвешенный уровень доступности образования в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.r_2 is 'Средневзвешенный уровень доступности магазинов и здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.r_3 is 'Средневзвешенный уровень доступности общественного питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.r_4 is 'Средневзвешенный уровень доступности досуга и развлечений в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.r_5 is 'Средневзвешенный уровень доступности спорта и рекреации в баллах (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.r_all is 'Средневзвешенный уровень пешеходной доступности в баллах - итоговый WalkScore (больше - лучше, максимум 100 баллов)';
comment on column tmp.valday_walkscore.geom is 'Геометрия - гексагональные ячейки';

--create table walkscore.poi as select * from poi;
--create index on walkscore.poi(wlk_ind);
--create index on walkscore.poi using gist(geog);












create index on tmp.valday_building using gist(geom);

/* Привлекательность территории для строительства */
/* Время расчёта для всех городов России ~ 20 ч. */
/* Время расчёта для Перми ~ 40 сек. */
/* Время расчёта для Екатеринбурга ~ 2 мин. */
--
/* В качестве исходника берём предрасчитанные урбанизированные территории городов и откладываем 800 м. буффер */
drop table if exists urban_buffer;
create temp table urban_buffer as
select st_union(st_buffer(geom::geography, 800)::geometry) geom
from tmp.valday_building
--where id_gis <= 100
-- select * from urban_buffer;
;
create index on urban_buffer using gist(geom);
;
drop table if exists tmp.valday_urban_buffer;
create table tmp.valday_urban_buffer as select * from urban_buffer
;
/* Пересечением с буфером выбираем ячейки гексагональной сетки 1 га. */
drop table if exists grid_urban;
create temp table grid_urban as
select distinct on(g.id)
	g.id,
	round((st_area(g.geom::geography)::numeric / 10000)::numeric, 2) area_ha,
	g.geom
from urban_buffer u
join tmp.valday_grid g
	on st_intersects(g.geom, u.geom)
--where u.id_gis = 1038
--	and st_isvalid(u.geom)
group by 
	g.id,
	g.geom
-- select * from grid_urban;
;
create index on grid_urban using gist(geom);
;
/* Фильтруем сетку. Выбрасываем водные поверхности. */
drop table if exists grid_filtered_1;
create temp table grid_filtered_1 as
select distinct on(g.id) g.*
from grid_urban g
left join embankment.city_waterarea w
	on st_intersects(g.geom, w.geom)
--where g.id_gis = 1038
	and w.id is null
group by 
	g.id,
	g.area_ha,
	g.geom
-- select * from grid_filtered_1;
-- select * from embankment.city_waterarea where id_gis = 1038;
;
create index on grid_filtered_1 using gist(geom);
;
/* Фильтруем сетку. Выбрасываем благоустроенное озеленение (по данным Индекса качества городской среды). */
drop table if exists grid_filtered_2;
create temp table grid_filtered_2 as
select g.*
from grid_filtered_1 g
left join index2020.data_greenery gr
	on st_intersects(g.geom, gr.geom)
--where g.id_gis = 1038
group by 
	g.id,
	g.area_ha,
	g.geom
-- оставляем ячейки, пересекающие зелень менее чем на 10% от их площади:                                                                 
having coalesce(sum(st_area(st_intersection(g.geom, gr.geom)::geography)), 0) <=  0.1 * g.area_ha * 10000
-- select * from index2020.data_greenery where id_gis = 1038 and id is null;
;
create index on grid_filtered_2 using gist(geom);
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
	g.area_ha,
	coalesce(round(((sum(st_area(st_intersection(g.geom, b.geom)::geography) * case when b."level" is null then 1 else b."level" end) / 1000 / nullif(g.area_ha, 0)) * 0.95)::numeric, 2), 0) build_density_1km2_ha,
	g.geom
from grid_filtered_3 g
left join russia.building_osm b
		on st_intersects(g.geom, b.geom)
--where g.id_gis = 1038
group by 
	g.id,
	g.area_ha,
	g.geom
;
create index on density (id);
create index on density (build_density_1km2_ha)
;
/* --  */
--create index on tmp.valday_ipa_ita using gist(geom);
--create index on tmp.valday_ipa_ita(ipa);
--create index on tmp.valday_ipa_ita(ita);
drop table if exists ipa_ita;
create temp table ipa_ita as
select
	g.id,
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
left join tmp.valday_ipa_ita i
	on st_intersects(g.geom, i.geom)
--where g.id_gis = 1038
group by 
	g.id,
	g.geom
;
create index on ipa_ita (id);
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
;

-- Сношаем с WalkScore
drop table if exists tmp.valday_development_attractivness;
create table tmp.valday_development_attractivness as
select
	i.*,
	case
		when i.priority = 'Низкопривлекательная'  and w.r_all < 40 then 11::smallint
		when i.priority = 'Низкопривлекательная'  and w.r_all between 40 and 80 then 12::smallint
		when i.priority = 'Низкопривлекательная'  and w.r_all > 80 then 13::smallint
		when i.priority = 'Среднепривлекательная' and w.r_all < 40 then 21::smallint
		when i.priority = 'Среднепривлекательная' and w.r_all between 40 and 80 then 22::smallint
		when i.priority = 'Среднепривлекательная' and w.r_all > 80 then 23::smallint
		when i.priority = 'Высокопривлекательная' and w.r_all < 40 then 31::smallint
		when i.priority = 'Высокопривлекательная' and w.r_all between 40 and 80 then 32::smallint
		when i.priority = 'Высокопривлекательная' and w.r_all > 80 then 33::smallint
	end priority_grade
from priority i 
left join tmp.valday_walkscore w 
	on w.id = i.id
;
alter table tmp.valday_development_attractivness add primary key(id);
create index on tmp.valday_development_attractivness using gist(geom);
create index on tmp.valday_development_attractivness(build_density_1km2_ha);
create index on tmp.valday_development_attractivness(build_density_class);
create index on tmp.valday_development_attractivness(build_density_type);
create index on tmp.valday_development_attractivness(build_density_score);
create index on tmp.valday_development_attractivness(ipa);
create index on tmp.valday_development_attractivness(ita);
create index on tmp.valday_development_attractivness(sum_ipa_ita);
create index on tmp.valday_development_attractivness(priority);
create index on tmp.valday_development_attractivness(priority_grade)
;
/* Комментарии */
comment on table tmp.valday_development_attractivness is 'Привлекательность территории под развитие';
comment on column tmp.valday_development_attractivness.id is 'Первичный ключ';
comment on column tmp.valday_development_attractivness.geom is 'Геометрия';
comment on column tmp.valday_development_attractivness.area_ha is 'Площадь ячейки (с учётом обрезки по границам города)';
comment on column tmp.valday_development_attractivness.build_density_1km2_ha is 'Плотность застройки по футпринтам зданий, км2/га';
comment on column tmp.valday_development_attractivness.build_density_class is 'Класс территории по плотности застройки (Свободный/Низкая плотность/Высокая плотность)';
comment on column tmp.valday_development_attractivness.build_density_type is 'Средневзвешенный тип среды для ячейки (
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
comment on column tmp.valday_development_attractivness.build_density_score is 'Уровень застроенности по шкале от 0 до 3';
comment on column tmp.valday_development_attractivness.ipa is 'Максимальный индекс пешеходной активности в ячейке (на основе данных ipa-ita,  рассчитанных Сергеем Тюпановым)';
comment on column tmp.valday_development_attractivness.ita is 'Максимальный индекс транспортной активности в ячейке (на основе данных ipa-ita,  рассчитанных Сергеем Тюпановым)';
comment on column tmp.valday_development_attractivness.sum_ipa_ita is 'Средневзвешенная пешеходно-транспортная активность в ячейке (если плотность застройки < 0.6, то соотношение веса 0.7/0.3 в пользу транспортной активности. При более высокой плотности соотношение пешеходной и транспортной активности 0.5/0.5)';
comment on column tmp.valday_development_attractivness.priority is 'Базовый класс привлекательности территории (Низкопривлекательная/Среднепривлекательная/Высокопривлекательная)';
comment on column tmp.valday_development_attractivness.priority_grade is 'Взвешенная привлекательности территории (базовая привлекательность территории взвешенная на итоговом индексе WalkScore по трём классам:
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


















