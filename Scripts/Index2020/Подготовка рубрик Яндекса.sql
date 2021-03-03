/* Подготовка рубрик Яндекса (новый формат таблицы POI) */
/* Время выполнения на данных 2020 г ~ 9 мин. */
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
create index on poi1(distinct_cat)
;
/* Присваиваем старые значения рубрик */
drop table if exists poi2;
create temp table poi2 as 
select
	p.id,
	p.company_id,
	p."name",
	p.id_gis,
	p.geom,
	p.category_name,
	r.rubrics_old category_old,
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
create index on poi2(category_old);
;
/* Агрегируем старые значения рубрик в список */
drop table if exists index2020.data_poi;
create table index2020.data_poi as 
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
;
/* Ручные правки таблицы POI */
/* Избирательные участки и петанк отсутствуют в выгрузке Яндекса 2020, поэтому было решено добавить их из выгрузки 2019 */
insert into index2020.data_poi (company_id, "name",	id_gis,	geom, rubrics, sdz, odz, greenz, leisurez, ipa, stretail, trade, food, services)
select company_id::bigint, "name",	id_gis,	geom, rubrics,  sdz, odz, greenz, leisurez, ipa, stretail, trade, food, services
from index2019.data_poi p
where p.rubrics in ('Избирательные комиссии и участки', 'Петанк')
;
/* Оперные театры отсутствуют как самостоятельная рубрика в выгрузке Яндекса 2020, поэтому добавляем её вручную на основе названия театра */
update index2020.data_poi set rubrics = ('"Опера",' || rubrics) where rubrics like '%"Театр"%' and name ~* 'опер'
;
alter table index2020.data_poi add column id int primary key generated always as identity;
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
create index on index2020.data_poi using gist(geom);
create index on index2020.data_poi using gist((geom::geography));

alter table index2020.data_poi add column mall bool;