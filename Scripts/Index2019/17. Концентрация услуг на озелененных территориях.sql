/* 17-й индикатор. Концентрация услуг на озелененных территориях */
/* Время расчёта ~ 5 мин. */
/* Визуализация POI на озеленённых территориях */
drop materialized view if exists index2019.viz_i17_poi cascade; 
create materialized view index2019.viz_i17_poi as 

-- в расчёте 2018 под озеленёнными территориями подразумевались ndv1 >= 50 + благоустроенное озеленение.
-- в расчёте 2019 от этого было решено отказаться в пользу благоустроенного озеленения только
/*
select p.id, p.id_gis, p.name, p.rubrics, p.geom from index2019.data_poi p
join index2019.data_ndvi n
	on st_intersects(n.geom, p.geom)
		and (p.greenz is true)
		and (p.mall is false)
		and (n.id_gis = p.id_gis)
		and (n.ndvi >= 50)
--where p.id_gis < 300 -- для дебага
union
*/

select distinct on (p.id) p.id, p.id_gis, p.name, p.rubrics, p.geom from index2019.data_poi p
join index2019.data_greenery g
	on st_intersects(g.geom, p.geom)
		and (p.greenz is true)
		and (p.mall is false)
		and (g.id_gis = p.id_gis)
--where p.id_gis < 300 -- для дебага
;

/* Индексы */
create unique index on index2019.viz_i17_poi (id);
create index on index2019.viz_i17_poi (id_gis);
create index on index2019.viz_i17_poi (rubrics);
create index on index2019.viz_i17_poi using gist(geom);

/* Комментарии */
comment on materialized view index2019.viz_i17_poi is '17-й индикатор. Визуализация POI на озеленённых территориях';
comment on column index2019.viz_i17_poi.id is 'Уникальный идентификатор POI';
comment on column index2019.viz_i17_poi.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i17_poi.name is 'Название POI';
comment on column index2019.viz_i17_poi.rubrics is 'Рубрика, к которой относится POI';
comment on column index2019.viz_i17_poi.geom is 'Геометрия';


/* Расчёт индикатора */
drop materialized view if exists index2019.ind_i17 cascade; 
create materialized view index2019.ind_i17 as 
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(round((g.total_greenery_area_ha / 100)::numeric, 2), 0) as green_area_km2,
	coalesce(p.total_poi, 0) as total_poi_in_greenery,
	coalesce(round((p.total_poi * 100 / g.total_greenery_area_ha::numeric), 4), 0) as poi_to_km2
from index2019.data_boundary b
left join (select id_gis, sum(st_area(geom::geography)) / 10000 total_greenery_area_ha from index2019.data_greenery group by id_gis) g using(id_gis)
left join (select id_gis, count(*) total_poi from index2019.viz_i17_poi group by id_gis) p using(id_gis)
order by id_gis;

/* Индексы */
create unique index on index2019.ind_i17 (id_gis);

/* Комментарии */
comment on materialized view index2019.ind_i17 is '17-й индикатор. Концентрация услуг на озелененных территориях';
comment on column index2019.ind_i17.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i17.city is 'Город';
comment on column index2019.ind_i17.region is 'Субъект РФ';
comment on column index2019.ind_i17.green_area_km2 is 'Площадь благоустроенного озеленения, км. кв.';
comment on column index2019.ind_i17.total_poi_in_greenery is 'Общее число точек POI на озеленённой территории (благоустроенное озеленение)';
comment on column index2019.ind_i17.poi_to_km2 is 'Плотность точек POI на 1 км. кв. озеленённой территории';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i17;
create view index2019.comp_i17 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(round((i2.green_area_km2)::numeric, 4), 0) green_area_km2_2018,
	coalesce(i1.green_area_km2, 0) green_area_km2_2019,
	coalesce(i2.poi_in_greenery, 0) total_poi_in_greenery_2018,
	coalesce(i1.total_poi_in_greenery, 0) total_poi_in_greenery_2019,
	coalesce(round((i2.poi_to_km2)::numeric, 4), 0) poi_to_km2_2018,
	coalesce(i1.poi_to_km2, 0) poi_to_km2_2019,
	(case 
		when i1.poi_to_km2 > round(i2.poi_to_km2::numeric, 4)
			then 2019
	 	when i1.poi_to_km2 = round(i2.poi_to_km2::numeric, 4)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i17 i1
left join index2018.i17_poi_in_greenery_no_malls_ndvi i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i17 is 'Сравнение с 2018 годом. 17-й индикатор. Концентрация услуг на озелененных территориях.';
comment on column index2019.comp_i17.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i17.city is 'Город';
comment on column index2019.comp_i17.region is 'Субъект РФ';
comment on column index2019.comp_i17.green_area_km2_2018 is 'Площадь озеленения с качеством 50 <= NDVI на 2018 г., км2';
comment on column index2019.comp_i17.green_area_km2_2019 is 'Площадь благоустроенного озеленения на 2019 г., км2';
comment on column index2019.comp_i17.total_poi_in_greenery_2018 is 'Общее точек POI в границах благоустроенного озеленения в 2018 г., ед';
comment on column index2019.comp_i17.total_poi_in_greenery_2019 is 'Общее точек POI в границах благоустроенного озеленения в 2019 г., ед';
comment on column index2019.comp_i17.poi_to_km2_2018 is 'Концентрация услуг на озелененных территориях в 2018 г., ед/км2';
comment on column index2019.comp_i17.poi_to_km2_2019 is 'Концентрация услуг на озелененных территориях в 2019 г., ед/км2';
comment on column index2019.comp_i17.higher_value is 'В каком году показатель "Концентрация услуг на озелененных территориях" выше';