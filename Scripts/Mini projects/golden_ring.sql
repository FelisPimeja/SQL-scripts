/* Статистика по населению и удалённости от ОКН для населённых пунктов следующих Субъектов: */
/* Тульская область, Ярославская область, Калужская область, Ивановская область, Костромская область,
	Московская область, Рязанская область, Владимирская область, Тверская область */

/* Собираем матрёшку административных границ */
/* Извлекаем Субъекты */
drop table if exists regions;
create temp table regions as
select * from osm.admin_ru
where admin_level = 4
	and name in (
	    'Тульская область',
	    'Ярославская область',
	    'Калужская область',
	    'Ивановская область',
	    'Костромская область',
	    'Московская область',
	    'Рязанская область',
	    'Владимирская область',
	    'Тверская область'
	);
create index on regions(name);
create index on regions using gist(geom);

/* Ищем как населённые пункты вложены по регионам */
drop table if exists  place_osm_1;
create temp table place_osm_1 as 
select
	p.*,
	r.name region
from regions r
left join osm.places_ru p
	on st_intersects(r.geom, p.geom)
		and p.type in ('city', 'hamlet', 'isolated_dwelling', 'town', 'village');
create index on place_osm_1 using gist(geom);

--select count(*) from place_osm_1

/* Ищем как населённые пункты вложены по районам */
drop table if exists place_osm_2;
create temp table place_osm_2 as (
	select p.*, r.name raion
	from place_osm_1 p
	left join osm.admin_ru r
		on st_intersects(r.geom, p.geom)
			and r.admin_level = 6
);
create index on place_osm_2 using gist(geom);

--select count(*) from place_osm_2
--select * from place_osm1 limit 10

/* Ищем как населённые пункты вложены по поселениям */
drop table if exists place_osm;
create temp table place_osm as (
	select distinct on(p.id)
		p.id,
		p.name,
		p.type,
		p.population,
		p.geom,
		r.name poselenie,
		p.raion,
		p.region
	from place_osm_2 p
	left join osm.admin_ru r
		on st_intersects(r.geom, p.geom)
			and r.admin_level = 8
);
create index on place_osm(name);
create index on place_osm using gist(geom);
create index on place_osm using gist((geom::geography));

--select count(*) from place_osm

/* Ищем какие населённые пункты из третьего источника попадают в заданные регионы */
drop table if exists  place_stat;
create temp table place_stat as (
	select p.type, p.name, p.peoples population, p.geom
	from regions r
	join russia.place_all p
		on st_intersects(r.geom, p.geom)
			and p.level = 3
);
create index on place_stat(population);
create index on place_stat(name);
create index on place_stat(type);
create index on place_stat using gist(geom);
create index on place_stat using gist((geom::geography));

drop table if exists  okn;
create temp table okn as (
	select
		p.general_id,
		p.nativename "name",
		p.general__categorytype_value "type",
		p.geom
	from regions r
	join index2019.data_okn p
	 on st_intersects(r.geom, p.geom)
);
create index on okn(name);
create index on okn using gist(geom);
create index on okn using gist((geom::geography));

--select "type", count(*) from okn group by "type"
--select count(*) from okn

/* Сопоставляем точки населённых пунктов из OpenStreetMap и третьего источника */
drop table if exists  place;
create temp table place as
select
	p1.id,
	coalesce(p2.type, '') type_stat,
	p1.name,
--		p2.name name_stat,
	p1.type type_osm,
	case 
		when p2.population is null
			then p1.population
		else p2.population
	end population,
	case 
		when p2.population is not null
			then 'Росстат 2010'::text
		when p1.population is not null 
			then 'OpenStreetMap'::text
	end population_source,
	p1.geom,
	p1.poselenie,
	p1.raion,
	p1.region
from place_osm p1
left join lateral (
	select p2.*
	from place_stat p2
	where st_dwithin(p1.geom::geography, p2.geom::geography, 10000)
		and p1.name ilike p2.name
	order by p1.geom::geography <-> p2.geom::geography
	limit 1
) p2 on true;

--select * from place where population > 0
create index on place using gist(geom);
create index on place using gist((geom::geography));

--select count(*) from place

/* Проверяем расстояние от населённых пунктов до всех ОКН из реестра Минкульта в радиусе 100 км. */
drop table if exists  place_final;
create temp table place_final as 
select
	p.*,
	array_to_string(array_agg(o.name || ' (' || case when o.dist_km = 0 then '< 1'::text else o.dist_km::text end || ' км.)' order by dist_km), ', 
') okn_in_100km_radius
from place p
left join lateral (
	select
		o.name,
		o.general_id,
		o.type,
		round((st_distance(p.geom::geography, o.geom::geography) / 1000)::numeric) dist_km
	from okn o
	where st_dwithin(p.geom::geography, o.geom::geography, 100000)
	order by p.geom::geography <-> o.geom::geography
	limit 10
) o on true
group by
	p.id,
	p.type_stat,
	p.name,
	p.type_osm,
	p.population,
	p.population_source,
	p.geom,
	p.poselenie,
	p.raion,
	p.region
;

select
--	(row_number() over())::int id,
	type_stat "Тип н.п.",
	name "Название",
--	type_osm,
	population "Население, чел.",
	population_source "Насел., источник",
--	geom,
--	admin_id,
	poselenie "Поселение",
	raion "Район/Округ",
	region "Субъект РФ",
	okn_in_100km_radius "ОКН в 100 км. радиусе"
from place_final
where name is not null
order by region, raion, poselenie, population desc nulls last;







/* Выборка населённых пунктов */
with p as (
select p.*, r.name name2
 from russia.osm_admin_boundary_region r
 left join "osm"."places_ru" p
  on st_intersects(r.geom, p.geom)
 	and p."type" in ('city', 'hamlet', 'isolated_dwelling', 'town', 'village')
 where r.id in (5,6,7,12,13,55,56,66,85)
)
select p.*, r2.name name3
 FROM osm.admin_ru r2
 left join p
  on st_intersects(r2.geom, p.geom)
 where r2.admin_level = 6
 	and (
		(p.name = 'Тверь' and p.name2 = 'Тверская область' and r2.name = 'городской округ Тверь') or
		(p.name = 'Ржев' and p.name2 = 'Тверская область' and r2.name = 'городской округ Ржев') or
		(p.name = 'Вышний Волочёк' and p.name2 = 'Тверская область' and r2.name = 'городской округ Вышний Волочёк') or
		(p.name = 'Торжок' and p.name2 = 'Тверская область' and r2.name = 'городской округ Торжок') or
		(p.name = 'Нелидово' and p.name2 = 'Тверская область' and r2.name = 'Нелидовский городской округ') or
		(p.name = 'Осташков' and p.name2 = 'Тверская область' and r2.name = 'Осташковский городской округ') or
		(p.name = 'Калязин' and p.name2 = 'Тверская область' and r2.name = 'Калязинский район') or
		(p.name = 'Торопец' and p.name2 = 'Тверская область' and r2.name = 'Торопецкий район') or
		(p.name = 'Старица' and p.name2 = 'Тверская область' and r2.name = 'Старицкий район') or
		(p.name = 'Городня' and p.name2 = 'Тверская область' and r2.name = 'Конаковский район') or
		(p.name = 'Берново' and p.name2 = 'Тверская область' and r2.name = 'Старицкий район') or
		(p.name = 'Светлица' and p.name2 = 'Тверская область' and r2.name = 'Осташковский городской округ') or
		(p.name = 'Василево' and p.name2 = 'Тверская область' and r2.name = 'Торжокский район') or
		(p.name = 'Волговерховье' and p.name2 = 'Тверская область' and r2.name = 'Осташковский городской округ') or
		(p.name = 'Калуга' and p.name2 = 'Калужская область' and r2.name = 'городской округ Калуга') or
		(p.name = 'Обнинск' and p.name2 = 'Калужская область' and r2.name = 'городской округ Обнинск') or
		(p.name = 'Малоярославец' and p.name2 = 'Калужская область' and r2.name = 'Малоярославецкий район') or
		(p.name = 'Козельск' and p.name2 = 'Калужская область' and r2.name = 'Козельский район') or
		(p.name = 'Боровск' and p.name2 = 'Калужская область' and r2.name = 'Боровский район') or
		(p.name = 'Таруса' and p.name2 = 'Калужская область' and r2.name = 'Тарусский район') or
		(p.name = 'Никола-Ленивец' and p.name2 = 'Калужская область' and r2.name = 'Дзержинский район') or
		(p.name = 'Климов Завод' and p.name2 = 'Калужская область' and r2.name = 'Юхновский район') or
		(p.name = 'Петрово' and p.name2 = 'Калужская область' and r2.name = 'Боровский район') or
		(p.name = 'Имени Льва Толстого' and p.name2 = 'Калужская область' and r2.name = 'Дзержинский район') or
		(p.name = 'Тула' and p.name2 = 'Тульская область' and r2.name = 'городской округ Тула') or
		(p.name = 'Алексин' and p.name2 = 'Тульская область' and r2.name = 'городской округ Алексин') or
		(p.name = 'Белёв' and p.name2 = 'Тульская область' and r2.name = 'Белёвский район') or
		(p.name = 'Одоев' and p.name2 = 'Тульская область' and r2.name = 'Одоевский район') or
		(p.name = 'Крапивна' and p.name2 = 'Тульская область' and r2.name = 'Щёкинский район') or
		(p.name = 'Монастырщино' and p.name2 = 'Тульская область' and r2.name = 'Кимовский район') or
		(p.name = 'Бяково' and p.name2 = 'Тульская область' and r2.name = 'Венёвский район') or
		(p.name = 'Гурьево' and p.name2 = 'Тульская область' and r2.name = 'Венёвский район') or
		(p.name = 'Страхово' and p.name2 = 'Тульская область' and r2.name = 'Заокский район') or
		(p.name = 'Ясная Поляна' and p.name2 = 'Тульская область' and r2.name = 'Щёкинский район') or
		(p.name = 'Рязань' and p.name2 = 'Рязанская область' and r2.name = 'городской округ Рязань') or
		(p.name = 'Касимов' and p.name2 = 'Рязанская область' and r2.name = 'городской округ Касимов') or
		(p.name = 'Спас-Клепики' and p.name2 = 'Рязанская область' and r2.name = 'Клепиковский район') or
		(p.name = 'Пощупово' and p.name2 = 'Рязанская область' and r2.name = 'Рыбновский район') or
		(p.name = 'Брыкин Бор' and p.name2 = 'Рязанская область' and r2.name = 'Спасский район') or
		(p.name = 'Выша' and p.name2 = 'Рязанская область' and r2.name = 'Шацкий район') or
		(p.name = 'Старая Рязань' and p.name2 = 'Рязанская область' and r2.name = 'Спасский район') or
		(p.name = 'Иваново' and p.name2 = 'Ивановская область' and r2.name = 'городской округ Иваново') or
		(p.name = 'Кинешма' and p.name2 = 'Ивановская область' and r2.name = 'городской округ Кинешма') or
		(p.name = 'Шуя' and p.name2 = 'Ивановская область' and r2.name = 'городской округ Шуя') or
		(p.name = 'Юрьевец' and p.name2 = 'Ивановская область' and r2.name = 'Юрьевецкий район') or
		(p.name = 'Палех' and p.name2 = 'Ивановская область' and r2.name = 'Палехский район') or
		(p.name = 'Плёс' and p.name2 = 'Ивановская область' and r2.name = 'Приволжский район') or
		(p.name = 'Решма' and p.name2 = 'Ивановская область' and r2.name = 'Кинешемский район') or
		(p.name = 'Худынино' and p.name2 = 'Ивановская область' and r2.name = 'Ивановский район') or
		(p.name = 'Уводь' and p.name2 = 'Ивановская область' and r2.name = 'Ивановский район') or
		(p.name = 'Тимирязево' and p.name2 = 'Ивановская область' and r2.name = 'Лухский район') or
		(p.name = 'Владимир' and p.name2 = 'Владимирская область' and r2.name = 'городской округ Владимир') or
		(p.name = 'Муром' and p.name2 = 'Владимирская область' and r2.name = 'городской округ Муром') or
		(p.name = 'Гусь-Хрустальный' and p.name2 = 'Владимирская область' and r2.name = 'городской округ Гусь-Хрустальный') or
		(p.name = 'Юрьев-Польский' and p.name2 = 'Владимирская область' and r2.name = 'Юрьев-Польский район') or
		(p.name = 'Гороховец' and p.name2 = 'Владимирская область' and r2.name = 'Гороховецкий район') or
		(p.name = 'Суздаль' and p.name2 = 'Владимирская область' and r2.name = 'Суздальский район') or
		(p.name = 'Боголюбово' and p.name2 = 'Владимирская область' and r2.name = 'Суздальский район') or
		(p.name = 'Кидекша' and p.name2 = 'Владимирская область' and r2.name = 'Суздальский район') or
		(p.name = 'Кострома' and p.name2 = 'Костромская область' and r2.name = 'городской округ Кострома') or
		(p.name = 'Буй' and p.name2 = 'Костромская область' and r2.name = 'городской округ Буй') or
		(p.name = 'Нерехта' and p.name2 = 'Костромская область' and r2.name = 'Нерехтский район') or
		(p.name = 'Галич' and p.name2 = 'Костромская область' and r2.name = 'городской округ Галич') or
		(p.name = 'Красное-на-Волге' and p.name2 = 'Костромская область' and r2.name = 'Красносельский район') or
		(p.name = 'Макарьев' and p.name2 = 'Костромская область' and r2.name = 'Макарьевский район') or
		(p.name = 'Солигалич' and p.name2 = 'Костромская область' and r2.name = 'Солигаличский район') or
		(p.name = 'Чухлома' and p.name2 = 'Костромская область' and r2.name = 'Чухломский район') or
		(p.name = 'Судиславль' and p.name2 = 'Костромская область' and r2.name = 'Судиславский район') or
		(p.name = 'Сусанино' and p.name2 = 'Костромская область' and r2.name = 'Сусанинский район') or
		(p.name = 'Кологрив' and p.name2 = 'Костромская область' and r2.name = 'Кологривский район') or
		(p.name = 'Щелыково' and p.name2 = 'Костромская область' and r2.name = 'Островский район') or
		(p.name = 'Троица' and p.name2 = 'Костромская область' and r2.name = 'Нерехтский район') or
		(p.name = 'Сумароково' and p.name2 = 'Костромская область' and r2.name = 'Сусанинский район') or
		(p.name = 'Ярославль' and p.name2 = 'Ярославская область' and r2.name = 'городской округ Ярославль') or
		(p.name = 'Рыбинск' and p.name2 = 'Ярославская область' and r2.name = 'городской округ Рыбинск') or
		(p.name = 'Тутаев' and p.name2 = 'Ярославская область' and r2.name = 'Тутаевский район') or
		(p.name = 'Переславль-Залесский' and p.name2 = 'Ярославская область' and r2.name = 'городской округ Переславль-Залесский') or
		(p.name = 'Углич' and p.name2 = 'Ярославская область' and r2.name = 'Угличский район') or
		(p.name = 'Ростов' and p.name2 = 'Ярославская область' and r2.name = 'Ростовский район') or
		(p.name = 'Мышкин' and p.name2 = 'Ярославская область' and r2.name = 'Мышкинский район') or
		(p.name = 'Борисоглебский' and p.name2 = 'Ярославская область' and r2.name = 'Борисоглебский район') or
		(p.name = 'Карабиха' and p.name2 = 'Ярославская область' and r2.name = 'Ярославский район') or
		(p.name = 'Подольск' and p.name2 = 'Московская область' and r2.name = 'городской округ Подольск') or
		(p.name = 'Коломна' and p.name2 = 'Московская область' and r2.name = 'Коломенский городской округ') or
		(p.name = 'Серпухов' and p.name2 = 'Московская область' and r2.name = 'городской округ Серпухов') or
		(p.name = 'Орехово-Зуево' and p.name2 = 'Московская область' and r2.name = 'Орехово-Зуевский городской округ') or
		(p.name = 'Ногинск' and p.name2 = 'Московская область' and r2.name = 'Богородский городской округ') or
		(p.name = 'Сергиев Посад' and p.name2 = 'Московская область' and r2.name = 'Сергиево-Посадский городской округ') or
		(p.name = 'Клин' and p.name2 = 'Московская область' and r2.name = 'городской округ Клин') or
		(p.name = 'Егорьевск' and p.name2 = 'Московская область' and r2.name = 'городской округ Егорьевск') or
		(p.name = 'Чехов' and p.name2 = 'Московская область' and r2.name = 'городской округ Чехов') or
		(p.name = 'Дмитров' and p.name2 = 'Московская область' and r2.name = 'Дмитровский городской округ') or
		(p.name = 'Павловский Посад' and p.name2 = 'Московская область' and r2.name = 'городской округ Павловский Посад') or
		(p.name = 'Дзержинский' and p.name2 = 'Московская область' and r2.name = 'городской округ Дзержинский') or
		(p.name = 'Солнечногорск' and p.name2 = 'Московская область' and r2.name = 'городской округ Солнечногорск') or
		(p.name = 'Кашира' and p.name2 = 'Московская область' and r2.name = 'городской округ Кашира') or
		(p.name = 'Истра' and p.name2 = 'Московская область' and r2.name = 'городской округ Истра') or
		(p.name = 'Можайск' and p.name2 = 'Московская область' and r2.name = 'Можайский городской округ') or
		(p.name = 'Озёры' and p.name2 = 'Московская область' and r2.name = 'городской округ Озёры') or
		(p.name = 'Зарайск' and p.name2 = 'Московская область' and r2.name = 'городской округ Зарайск') or
		(p.name = 'Бронницы' and p.name2 = 'Московская область' and r2.name = 'городской округ Бронницы') or
		(p.name = 'Звенигород' and p.name2 = 'Московская область' and r2.name = 'Одинцовский городской округ') or
		(p.name = 'Монино' and p.name2 = 'Московская область' and r2.name = 'городской округ Щёлково') or
		(p.name = 'Кубинка' and p.name2 = 'Московская область' and r2.name = 'Одинцовский городской округ') or
		(p.name = 'Волоколамск' and p.name2 = 'Московская область' and r2.name = 'Волоколамский городской округ') or
		(p.name = 'Руза' and p.name2 = 'Московская область' and r2.name = 'Рузский городской округ') or
		(p.name = 'Талдом' and p.name2 = 'Московская область' and r2.name = 'Талдомский городской округ') or
		(p.name = 'Большие Вязёмы' and p.name2 = 'Московская область' and r2.name = 'Одинцовский городской округ') or
		(p.name = 'Верея' and p.name2 = 'Московская область' and r2.name = 'Наро-Фоминский городской округ') or
		(p.name = 'Горки Ленинские' and p.name2 = 'Московская область' and r2.name = 'Ленинский городской округ') or
		(p.name = 'Марфино' and p.name2 = 'Московская область' and r2.name = 'городской округ Мытищи') or
		(p.name = 'Архангельское' and p.name2 = 'Московская область' and r2.name = 'городской округ Красногорск') or
		(p.name = 'Данки' and p.name2 = 'Московская область' and r2.name = 'городской округ Серпухов') or
		(p.name = 'Мураново' and p.name2 = 'Московская область' and r2.name = 'Пушкинский городской округ') or
		(p.name = 'Мелихово' and p.name2 = 'Московская область' and r2.name = 'городской округ Чехов') or
		(p.name = 'Теряево' and p.name2 = 'Московская область' and r2.name = 'Волоколамский городской округ')
	)
;




/* Достаём ООПТ на 9 регионов и ищем ближайшие к ним населённые пункты (для Excel)*/

select
	o.id,
	o.category "Тип ООПТ",
	o.name "Наименование ООПТ",
	round((st_area(o.geom::geography) / 10000)::numeric) "Площадь охранной зоны, га",
	o.status "Статус ООПТ",
	o.region "Субъект",
	c.name  "Ближайший населённый пункт",
	round((st_distance(o.geom::geography, c.geom::geography) / 1000)::numeric, 2) "Расст. до ближ. насел. пункта, км"
from (
	select distinct on(o.id) o.*
	from russia.osm_admin_boundary_region r
	left join russia.oopt_3 o
	  on st_intersects(r.geom, o.geom)
	where r.id in (5,6,7,12,13,55,56,66,85)
) o
left join lateral (
	select c.*
	from russia.place_all c
	order by c.geom::geography <-> o.geom::geography
	limit 1
) c on true


