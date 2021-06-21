/* 17-й индикатор. Концентрация услуг на озелененных территориях */
/* Время расчёта ~ 30 сек. */
/* Визуализация POI на озеленённых территориях */
drop table if exists index2020.viz_i17_poi; 
create table index2020.viz_i17_poi as 

-- в расчёте 2018 под озеленёнными территориями подразумевались ndv1 >= 50 + благоустроенное озеленение.
-- в расчёте 2019 от этого было решено отказаться в пользу благоустроенного озеленения только
/*
select p.id, p.id_gis, p.name, p.rubrics, p.geom from index2020.data_poi p
join index2020.data_ndvi n
	on st_intersects(n.geom, p.geom)
		and (p.greenz is true)
		and (p.mall is false)
		and (n.id_gis = p.id_gis)
		and (n.ndvi >= 50)
--where p.id_gis < 300 -- для дебага
union
*/

select distinct on (p.id)
	p.fid id,
	p.id_gis,
	p.name,
	p.rubrics,
	p.geom
from index2020.data_greenery g
join index2020.data_poi p
	on st_intersects(g.geom, p.geom)
		and p.greenz is true
		and p.mall is false
		and g.id_gis = p.id_gis
		and p.rubrics not in ('Скульптура', 'Памятник', 'Мемориал') -- Важная новация 2019 г. В рассчёт не попадают скульптуры в парках!
--where p.id_gis <= 100 -- для дебага
;
--select * from index2020.data_poi where id is null;
/* Индексы */
alter table index2020.viz_i17_poi add primary key(id);
create index on index2020.viz_i17_poi (id_gis);
create index on index2020.viz_i17_poi (rubrics);
create index on index2020.viz_i17_poi using gist(geom);

/* Комментарии */
comment on table index2020.viz_i17_poi is '17-й индикатор. Визуализация POI на озеленённых территориях';
comment on column index2020.viz_i17_poi.id is 'Уникальный идентификатор POI';
comment on column index2020.viz_i17_poi.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i17_poi.name is 'Название POI';
comment on column index2020.viz_i17_poi.rubrics is 'Рубрика, к которой относится POI';
comment on column index2020.viz_i17_poi.geom is 'Геометрия';


/* Расчёт индикатора */
drop table if exists index2020.ind_i17; 
create table index2020.ind_i17 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(round((g.total_greenery_area_ha / 100)::numeric, 2), 0) as green_area_km2,
	coalesce(p.total_poi, 0) as total_poi_in_greenery,
	coalesce(round((p.total_poi * 100 / g.total_greenery_area_ha::numeric), 4), 0) as poi_to_km2
from index2020.data_boundary b
left join (select id_gis, sum(st_area(geom::geography)) / 10000 total_greenery_area_ha from index2020.data_greenery group by id_gis) g using(id_gis)
left join (select id_gis, count(*) total_poi from index2020.viz_i17_poi group by id_gis) p using(id_gis)
order by id_gis;

/* Индексы */
alter table index2020.ind_i17 add primary key(id_gis);

/* Комментарии */
comment on table index2020.ind_i17 is '17-й индикатор. Концентрация услуг на озелененных территориях';
comment on column index2020.ind_i17.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i17.city is 'Город';
comment on column index2020.ind_i17.region is 'Субъект РФ';
comment on column index2020.ind_i17.green_area_km2 is 'Площадь благоустроенного озеленения, км. кв.';
comment on column index2020.ind_i17.total_poi_in_greenery is 'Общее число точек POI на озеленённой территории (благоустроенное озеленение)';
comment on column index2020.ind_i17.poi_to_km2 is 'Плотность точек POI на 1 км. кв. озеленённой территории';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i17;
create table index2020.comp_i17 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.green_area_km2, 0) green_area_km2_2019,
	coalesce(i1.green_area_km2, 0) green_area_km2_2020,
	coalesce(i2.total_poi_in_greenery, 0) total_poi_in_greenery_2019,
	coalesce(i1.total_poi_in_greenery, 0) total_poi_in_greenery_2020,
	coalesce(i2.poi_to_km2, 0) poi_to_km2_2019,
	coalesce(i1.poi_to_km2, 0) poi_to_km2_2020,
	(case 
		when i1.poi_to_km2 > i2.poi_to_km2
			then 2020
	 	when i1.poi_to_km2 = i2.poi_to_km2
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i17 i1
left join index2019.ind_i17_2 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i17 is 'Сравнение с 2019 годом. 17-й индикатор. Концентрация услуг на озелененных территориях.';
comment on column index2020.comp_i17.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i17.city is 'Город';
comment on column index2020.comp_i17.region is 'Субъект РФ';
comment on column index2020.comp_i17.green_area_km2_2019 is 'Площадь озеленения с качеством 50 <= NDVI на 2019 г., км2';
comment on column index2020.comp_i17.green_area_km2_2020 is 'Площадь благоустроенного озеленения на 2020 г., км2';
comment on column index2020.comp_i17.total_poi_in_greenery_2019 is 'Общее точек POI в границах благоустроенного озеленения в 2019 г., ед';
comment on column index2020.comp_i17.total_poi_in_greenery_2020 is 'Общее точек POI в границах благоустроенного озеленения в 2020 г., ед';
comment on column index2020.comp_i17.poi_to_km2_2019 is 'Концентрация услуг на озелененных территориях в 2019 г., ед/км2';
comment on column index2020.comp_i17.poi_to_km2_2020 is 'Концентрация услуг на озелененных территориях в 2020 г., ед/км2';
comment on column index2020.comp_i17.higher_value is 'В каком году показатель "Концентрация услуг на озелененных территориях" выше';


/* Вывод сравнительной таблицы в Excel */
/*
select 
	id_gis "id_gis города",
	city "Город",
	region "Субъект РФ",
	green_area_km2_2019 "Площадь благ. озел., км2 (2019)",
	green_area_km2_2020 "Площадь благ. озел., км2 (2020)",
	total_poi_in_greenery_2019 "Всего POI в гран благ озел, шт.(2019)",
	total_poi_in_greenery_2020 "Всего POI в гран благ озел, шт.(2020)",
	poi_to_km2_2019 "Конц. услуг на озел терр, ед/км2(2019)",
	poi_to_km2_2020 "Конц. услуг на озел терр, ед/км2(2020)",
	case when higher_value is null then 'поровну' else higher_value::text end "В каком году показатель выше"
from index2020.comp_i17;
*/

