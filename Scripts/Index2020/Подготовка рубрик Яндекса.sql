/* Подготовка рубрик Яндекса (новый формат таблицы POI) */
/* Время выполнения на данных 2020 г ~ 10 мин. */
/* Разбираем рубрики из списка в отдельные строки */
drop table if exists poi1;
create temp table poi1 as 
select
	id,
	company_id,
	"name",
	id_gis,
	geom,
	category_name category_name,
	replace(unnest(string_to_array(category_name, '","')), '"', '') distinct_cat
from russia.poi_yandex_2020
where id_gis is not null -- id_gis предварительно должны быть проставлены по последней версии границ!!!
--limit 1000000
;
create index on poi1(distinct_cat);

/* Присваиваем старые значения рубрик */
drop table if exists poi2;
create temp table poi2 as 
select
	p.id,
	p.company_id,
	p."name",
	p.id_gis,
	p.geom,
	p.category_name category_new,
	r.rubrics_old rubrics,
	r.subrubrics,
	r.category,
	r.sdz,
	r.odz,
	r.greenz,
	r.leisurez,
	r.ipa,
	r.stretail,
	r.trade,
	r.food,
	r.services
from index2020.data_rubrics_connect r
join poi1 p
	on r.rubrics_new = p.distinct_cat
where r.rubrics_old is not null
group by
	p.id,
	p.category_name,
	r.rubrics_old,
	r.subrubrics,
	r.category,
	p.company_id,
	p."name",
	p.id_gis,
	p.geom,
	r.sdz,
	r.odz,
	r.greenz,
	r.leisurez,
	r.ipa,
	r.stretail,
	r.trade,
	r.food,
	r.services
;
create index on poi2(rubrics);

-- Сначала я хотел агрегировать рубрики в одну строку, чтобы избежать ненужного дублирования
-- Но в процессе последующего дебага индикаторов отказался от этой идеи
-- Лучше если для индекса они будут максимально наследовать старую структуру
-- Так в последствии проще искать изменения в показателях

/* Агрегируем старые значения рубрик в список 
drop table if exists poi3;
create temp table poi3 as 
select distinct on (id, category_old)
	company_id,
	"name",
	id_gis,
	geom,
	category_name category_new,
	array_to_string(array_agg('"' || category_old || '"'), ';') rubrics,
	subrubrics,
	category,
	bool_or(sdz) sdz,
	bool_or(odz) odz,
	bool_or(greenz) greenz,
	bool_or(leisurez) leisurez,
	bool_or(ipa) ipa,
	bool_or(stretail) stretail,
	bool_or(trade) trade,
	bool_or(food) food,
	bool_or(services) services
from poi2
group by
	id,
	category_old,
	category_name,
	company_id,
	"name",
	id_gis,
	geom,
	subrubrics,
	category
;*/
/* Ручные правки таблицы POI */
/* Избирательные участки и петанк отсутствуют в выгрузке Яндекса 2020, поэтому было решено добавить их из выгрузки 2019 */
insert into poi2 (company_id, "name",	id_gis,	geom, rubrics, sdz, odz, greenz, leisurez, ipa, stretail, trade, food, services)
select company_id::bigint, "name",	id_gis,	geom, rubrics,  sdz, odz, greenz, leisurez, ipa, stretail, trade, food, services
from index2019.data_poi p
where p.rubrics in ('Избирательные комиссии и участки', 'Петанк');

create index on poi2(id_gis);
create index on poi2 using gist(geom);

/* Проверяем на вхождение в торговый центр */
drop table if exists index2020.data_poi;
create table index2020.data_poi as 
select
	(row_number() over())::int fid,
	p.*,
	case when m.id is not null then true::bool else false::bool end mall
from poi2 p
left join index2020.data_mall m 
	on m.id_gis = p.id_gis 
		and st_intersects(m.geom, p.geom);

alter table index2020.data_poi add primary key (fid);
create index on index2020.data_poi(rubrics); -- нейминг для лучшей обратной совместимости
create index on index2020.data_poi(category_new);
create index on index2020.data_poi(subrubrics);
create index on index2020.data_poi(category);
create index on index2020.data_poi(company_id);
create index on index2020.data_poi("name");
create index on index2020.data_poi(id_gis);
create index on index2020.data_poi(sdz);
create index on index2020.data_poi(odz);
create index on index2020.data_poi(greenz);
create index on index2020.data_poi(leisurez);
create index on index2020.data_poi(ipa);
create index on index2020.data_poi(stretail);
create index on index2020.data_poi(trade);
create index on index2020.data_poi(food);
create index on index2020.data_poi(services);
create index on index2020.data_poi(mall);
create index on index2020.data_poi using gist(geom);
create index on index2020.data_poi using gist((geom::geography));

/* Оперные театры отсутствуют как самостоятельная рубрика в выгрузке Яндекса 2020, поэтому добавляем её вручную на основе названия театра */
update index2020.data_poi set rubrics = ('"Опера",' || rubrics) where rubrics like '%"Театр"%' and name ~* 'опер';



/* Парки, скверы и лесопарки из Яндекса для сверки слоя Благоустроенного озеленения отдельным слоем */
create table index2020.tmp_greenery_yandex as 
	select 
		id,
		name,
		description,
		id_gis,
		geom
	from russia.poi_yandex_2020
	where category_name ~ 'Лесопарк|Парк культуры и отдыха|Сквер'
		and id_gis is not null
;

alter table index2020.tmp_greenery_yandex add primary key(id);
create index on index2020.tmp_greenery_yandex(id_gis);
create index on index2020.tmp_greenery_yandex(name);
create index on index2020.tmp_greenery_yandex using gist(geom);
create index on index2020.tmp_greenery_yandex using gist((geom::geography));

comment on table is index2020.tmp_greenery_yandex 'Парки, скверы и лесопарки из Яндекса для сверки слоя Благоустроенного озеленения';
