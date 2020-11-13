/* Расчёт WalkScore на данных Яндекса и доп слое "благокстроенного озеленения" из состава индекса 2019 */
/* Фильтрация по id_gis */
drop table if exists city;
create temp table city as
select id_gis from russia.city
where id_gis <= 2000  --дебаг
;
create index on city(id_gis);

/* Подготовка POI Яндекса для расчёта WalkScore */
drop table if exists poi;
create temp table poi as
select --distinct on (p.company_id) -- По идее дубликаты рубрик мёрджить не нужно!!!
--	(row_number() over())::int id,
	p.geom,
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
left join index2019.data_poi p using(id_gis);

-- Добавляем точки точки зелёных насаждений общего пользования из контуров "благоустроенного озеленения" из состава Индекса качества городской среды 2019
insert into poi (id_gis, geom, wlk_ind)
select
	g.id_gis,
	(st_dumppoints(g.geom)).geom::geometry(point, 4326) geom,
	13::smallint wlk_ind
from city c
left join index2019.data_greenery g using (id_gis);

-- Индексы
alter table poi add column id serial primary key;
create index on poi(id_gis);
create index on poi(wlk_ind);
create index on poi using gist(geom);
create index on poi using gist((geom::geography));

--drop table if exists walkscore.poi_t;
--create table walkscore.poi_t as select * from poi;


/* Расчёт WalkScore */
-- Расчёт исходных расстояний до ближайших точек
drop table if exists sc;
create temp table sc as 
--explain
select
	g.id,
	case
        when p1.dist < 200 then 100
        when p1.dist > 199 and p1.dist < 400 then 100 - (p1.dist - 200) / 4
        when p1.dist > 399 and p1.dist < 800 then  50 - (p1.dist - 400) / 8
        else 0
    end kind,
	case
        when p2.dist < 300 then 100
        when p2.dist > 299 and p2.dist <  500 then 100 - (p2.dist - 300) /  4
        when p2.dist > 499 and p2.dist < 1000 then  50 - (p2.dist - 500) / 10
        else 0
    end schl,
	case
        when p3.dist < 400 then 100
        when p3.dist > 399 and p3.dist <  800 then 100 - (p3.dist - 400) / 8
        when p3.dist > 799 and p3.dist < 1200 then  50 - (p3.dist - 800) / 8
        else 0
    end univ,
	case
        when p4.dist < 400 then 100
        when p4.dist > 399 and p4.dist <  600 then 100 - (p4.dist - 400) /  4
        when p4.dist > 599 and p4.dist < 1200 then  50 - (p4.dist - 600) / 12
        else 0
    end food,
	case
        when p5.dist < 200 then 100
        when p5.dist > 199 and p5.dist < 400 then 100 - (p5.dist - 200) / 4
        when p5.dist > 399 and p5.dist < 800 then  50 - (p5.dist - 400) / 8
        else 0
    end shop,
	case
        when p6.dist < 300 then 100
        when p6.dist > 299 and p6.dist <  500 then 100 - (p6.dist - 300) /  4
        when p6.dist > 499 and p6.dist < 1000 then  50 - (p6.dist - 500) / 10
        else 0
    end heal,
	case
        when p7.dist < 200 then 100
        when p7.dist > 199 and p7.dist < 400 then 100 - (p7.dist - 200) / 4
        when p7.dist > 399 and p7.dist < 800 then  50 - (p7.dist - 400) / 8
        else 0
    end fast,
	case
        when p8.dist < 300 then 100
        when p8.dist > 299 and p8.dist <  500 then 100 - (p8.dist - 300) /  4
        when p8.dist > 499 and p8.dist < 1000 then  50 - (p8.dist - 500) / 10
        else 0
    end cafe,
	case
        when p9.dist < 400 then 100
        when p9.dist > 399 and p9.dist <  600 then 100 - (p9.dist - 400) /  4
        when p9.dist > 599 and p9.dist < 1200 then  50 - (p9.dist - 600) / 12
        else 0
    end rest,
	case
        when p10.dist < 600 then 100
        when p10.dist > 599 and p10.dist <  800 then 100 - (p10.dist - 600) /  4
        when p10.dist > 799 and p10.dist < 1600 then  50 - (p10.dist - 800) / 16
        else 0
    end cine,
	case
        when p11.dist < 500 then 100
        when p11.dist > 499 and p11.dist <  700 then 100 - (p11.dist - 500) /  4
        when p11.dist > 699 and p11.dist < 1400 then  50 - (p11.dist - 700) / 14
        else 0
    end thea,
	case
        when p12.dist < 400 then 100
        when p12.dist > 399 and p12.dist <  600 then 100 - (p12.dist - 400) /  4
        when p12.dist > 599 and p12.dist < 1200 then  50 - (p12.dist - 600) / 12
        else 0
    end entr,
	case
        when p13.dist < 400 then 100
        when p13.dist > 399 and p13.dist < 600 then 100 - (p13.dist - 400) /  4
        when p13.dist > 599 and p13.dist < 1200 then 50 - (p13.dist - 600) / 12
        else 0
    end park,
	case
        when p14.dist < 500 then 100
        when p14.dist > 499 and p14.dist <  700 then 100 - (p14.dist - 500) /  4
        when p14.dist > 699 and p14.dist < 1400 then  50 - (p14.dist - 700) / 14
        else 0
    end bibl,
	case
        when p15.dist < 400 then 100
        when p15.dist > 399 and p15.dist <  600 then 100 - (p15.dist - 400) /  4
        when p15.dist > 599 and p15.dist < 1200 then  50 - (p15.dist - 600) / 12
        else 0
    end fitn
from city c
left join index2019.data_hexgrid g using(id_gis)
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 1 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 800, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
) p1 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 2 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1000, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p2 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 3 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1200, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p3 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 4 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1200, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p4 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 5 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 800, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p5 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 6 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1000, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p6 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 7 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 800, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p7 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 8 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1000, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p8 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 9 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1200, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p9 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 10 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1600, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p10 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 11 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1400, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p11 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 12 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1200, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p12 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 13 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1200, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p13 on true
left join lateral (
    select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
    from poi p
    where p.wlk_ind = 14 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1400, true)
    order by st_centroid(g.geom)::geography <-> p.geom::geography
    limit 1
    ) p14 on true
left join lateral (
	select st_distance(st_centroid(g.geom)::geography, p.geom::geography, true) dist
	from poi p
	where p.wlk_ind = 15 and p.id_gis = g.id_gis
		and st_dwithin(st_centroid(g.geom)::geography, p.geom::geography, 1200, true)
	order by st_centroid(g.geom)::geography <-> p.geom::geography
	limit 1
) p15 on true;

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

--create index on index2019.data_hexgrid using gist((st_centroid(geom)::geography));

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
drop table if exists walkscore.walkscore2019;
create table walkscore.walkscore2019 as
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
left join index2019.data_hexgrid g using(id_gis)
left join sc using(id)
left join r1 using(id);

/* Первичный ключ и индексы*/
alter table walkscore.walkscore2019 add primary key(id);
create index on walkscore.walkscore2019 (id_gis);
create index on walkscore.walkscore2019 (kind);
create index on walkscore.walkscore2019 (schl);
create index on walkscore.walkscore2019 (univ);
create index on walkscore.walkscore2019 (food);
create index on walkscore.walkscore2019 (shop);
create index on walkscore.walkscore2019 (heal);
create index on walkscore.walkscore2019 (fast);
create index on walkscore.walkscore2019 (cafe);
create index on walkscore.walkscore2019 (rest);
create index on walkscore.walkscore2019 (cine);
create index on walkscore.walkscore2019 (thea);
create index on walkscore.walkscore2019 (entr);
create index on walkscore.walkscore2019 (park);
create index on walkscore.walkscore2019 (bibl);
create index on walkscore.walkscore2019 (fitn);
create index on walkscore.walkscore2019 (r_1);
create index on walkscore.walkscore2019 (r_2);
create index on walkscore.walkscore2019 (r_3);
create index on walkscore.walkscore2019 (r_4);
create index on walkscore.walkscore2019 (r_5);
create index on walkscore.walkscore2019 (r_all);
create index on walkscore.walkscore2019 using gist(geom);
--cluster walkscore.walkscore using walkscore_geom_idx; -- Ахтунг - кластеризация занимает 25 часов!!!

/* Комментарии */
comment on table walkscore.walkscore2019 is 'Индекс пешеходной доступности WalkScore посчитанный на данных Яндекс 2019 и гексагональной сетке 1 га, построенной для Индекса качества городской среды 2019';
comment on column walkscore.walkscore2019.id is 'Первичный ключ';
comment on column walkscore.walkscore2019.id_gis is 'id_gis города';
comment on column walkscore.walkscore2019.kind is 'Уровень доступности детских садов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.schl is 'Уровень доступности школ в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.univ is 'Уровень доступности высших учебных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.food is 'Уровень доступности продуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.shop is 'Уровень доступности непродуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.heal is 'Уровень доступности учреждений здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.fast is 'Уровень доступности предприятий быстрого питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.cafe is 'Уровень доступности кафе в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.rest is 'Уровень доступности ресторанов в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.cine is 'Уровень доступности кинотеатров в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.thea is 'Уровень доступности театров в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.entr is 'Уровень доступности развлекательных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.park is 'Уровень доступности парков и других зелёных зон в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.bibl is 'Уровень доступности библиотек в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.fitn is 'Уровень доступности фитнес центров и спортивных учреждений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.r_1 is 'Средневзвешенный уровень доступности образования в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.r_2 is 'Средневзвешенный уровень доступности магазинов и здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.r_3 is 'Средневзвешенный уровень доступности общественного питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.r_4 is 'Средневзвешенный уровень доступности досуга и развлечений в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.r_5 is 'Средневзвешенный уровень доступности спорта и рекреации в баллах (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.r_all is 'Средневзвешенный уровень пешеходной доступности в баллах - итоговый WalkScore (больше - лучше, максимум 100 баллов)';
comment on column walkscore.walkscore2019.geom is 'Геометрия - гексагональные ячейки';



