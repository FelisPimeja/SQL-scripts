/* Расчёт WalkScore на данных Яндекса и доп слое "благокстроенного озеленения" из состава индекса 2020 */
/* Время расчёта 211 часов на данных 2020 г. */
/* Фильтрация по id_gis */
drop table if exists city;
create temp table city as
select id_gis from russia.city
--where id_gis = 1074  --дебаг -- 3 min 48 s.
;
create index on city(id_gis);

/* Подготовка POI Яндекса для расчёта WalkScore */
drop table if exists poi;
create temp table poi as
select --distinct on (p.company_id) -- По идее дубликаты рубрик мёрджить не нужно!!!
--	(row_number() over())::int id,
	p.geom::geography geog,
	p.name, 
	p.id_gis,
	p.category,
	p.subrubrics, --дебаг
	p.rubrics,
	case
		when p.rubrics = 'Детский сад' then 1::smallint
		when p.rubrics = 'Общеобразовательная школа' or p.rubrics = 'Частная школа' then 2::smallint
		when p.rubrics = 'ВУЗ' then 3::smallint
		when p.subrubrics = 'Продукты питания' or p.rubrics in ('Продуктовый рынок', 'Рынок') then 4::smallint
		when p.rubrics like '%агазин%' and p.subrubrics != 'Продукты питания' then 5::smallint
		when p.subrubrics = 'Медицинские центры и клиники' or p.subrubrics = 'Медицинские услуги' then 6::smallint
		when p.rubrics = 'Быстрое питание' then 7::smallint
		when p.rubrics = 'Кафе' then 8::smallint
		when p.rubrics = 'Ресторан' then 9::smallint
		when p.rubrics = 'Кинотеатр' then 10::smallint
		when p.rubrics = 'Театр' or p.rubrics = 'Музей' then 11::smallint
		when p.subrubrics = 'Развлечения' then 12::smallint
--		when rubrics = '' then 13::smallint
		when p.rubrics = 'Библиотека' then 14::smallint
		when p.rubrics in (
			'Спортивная школа',
			'Спортивно-развлекательный центр',
			'Спортивное поле',
			'Спортивный клуб',
			'Спортивный комплекс',
			'Спортплощадка',
			'Фитнес-клуб'
		) then 15::smallint
	end wlk_ind
from city c
left join index2020.data_poi p using(id_gis);

-- Добавляем точки точки зелёных насаждений общего пользования из контуров "благоустроенного озеленения" из состава Индекса качества городской среды 2020
insert into poi (id_gis, geog, wlk_ind)
select
	g.id_gis,
	(st_dumppoints(g.geom)).geom::geometry::geography geog,
	13::smallint wlk_ind
from city c
left join index2020.data_greenery g using (id_gis);

-- Индексы
alter table poi add column id serial primary key;
create index on poi(id_gis);
create index on poi(wlk_ind);
create index on poi using gist(geog);

--drop table if exists walkscore.poi_t;
--create table walkscore.poi_t as select * from poi;
--create index on index2020.data_hexgrid using gist((st_centroid(geom)::geography));
drop table if exists hex_grid;
create temp table hex_grid as select id, id_gis, st_centroid(geom)::geography geog from  index2020.data_hexgrid where id_gis in (select * from city);
create index on hex_grid(id_gis);
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
        on g.id_gis = p.id_gis
            and st_dwithin(g.geog, p.geog, 1600)
    group by g.id, g.id_gis
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
drop table if exists walkscore.walkscore2020;
create table walkscore.walkscore2020 as
select
	g.id,
	g.id_gis::int2,
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
from city c
left join index2020.data_hexgrid g using(id_gis)
left join sc using(id)
left join r1 using(id);

/* Первичный ключ и индексы*/
alter table walkscore.walkscore2020 add primary key(id);
create index on walkscore.walkscore2020 (id_gis);
create index on walkscore.walkscore2020 (kind);
create index on walkscore.walkscore2020 (schl);
create index on walkscore.walkscore2020 (univ);
create index on walkscore.walkscore2020 (food);
create index on walkscore.walkscore2020 (shop);
create index on walkscore.walkscore2020 (heal);
create index on walkscore.walkscore2020 (fast);
create index on walkscore.walkscore2020 (cafe);
create index on walkscore.walkscore2020 (rest);
create index on walkscore.walkscore2020 (cine);
create index on walkscore.walkscore2020 (thea);
create index on walkscore.walkscore2020 (entr);
create index on walkscore.walkscore2020 (park);
create index on walkscore.walkscore2020 (bibl);
create index on walkscore.walkscore2020 (fitn);
create index on walkscore.walkscore2020 (r_1);
create index on walkscore.walkscore2020 (r_2);
create index on walkscore.walkscore2020 (r_3);
create index on walkscore.walkscore2020 (r_4);
create index on walkscore.walkscore2020 (r_5);
create index on walkscore.walkscore2020 (r_all);
create index on walkscore.walkscore2020 using gist(geom);
--cluster walkscore.walkscore using walkscore_geom_idx; -- Ахтунг - кластеризация занимает 25 часов!!!

/* Комментарии */
comment on table walkscore.walkscore2020 is 'Индекс пешеходной доступности WalkScore посчитанный на данных Яндекс 2020 и гексагональной сетке 1 га, построенной для Индекса качества городской среды 2020';
comment on column walkscore.walkscore2020.id is 'Первичный ключ';
comment on column walkscore.walkscore2020.id_gis is 'id_gis города';
comment on column walkscore.walkscore2020.kind is 'Уровень доступности детских садов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.schl is 'Уровень доступности школ в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.univ is 'Уровень доступности высших учебных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.food is 'Уровень доступности продуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.shop is 'Уровень доступности непродуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.heal is 'Уровень доступности учреждений здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.fast is 'Уровень доступности предприятий быстрого питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.cafe is 'Уровень доступности кафе в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.rest is 'Уровень доступности ресторанов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.cine is 'Уровень доступности кинотеатров в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.thea is 'Уровень доступности театров в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.entr is 'Уровень доступности развлекательных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.park is 'Уровень доступности парков и других зелёных зон в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.bibl is 'Уровень доступности библиотек в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.fitn is 'Уровень доступности фитнес центров и спортивных учреждений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.r_1 is 'Средневзвешенный уровень доступности образования в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.r_2 is 'Средневзвешенный уровень доступности магазинов и здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.r_3 is 'Средневзвешенный уровень доступности общественного питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.r_4 is 'Средневзвешенный уровень доступности досуга и развлечений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.r_5 is 'Средневзвешенный уровень доступности спорта и рекреации в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.r_all is 'Средневзвешенный уровень пешеходной доступности в баллах - итоговый WalkScore (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2020.geom is 'Геометрия - гексагональные ячейки';

--create table walkscore.poi as select * from poi;
--create index on walkscore.poi(wlk_ind);
--create index on walkscore.poi using gist(geog);




















