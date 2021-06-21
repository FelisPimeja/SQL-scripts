drop table if exists index2019.data_mall;
/* Таблица ТРЦ состоит из двух выборок */
create table index2019.data_mall as
/* Первая выборка - здания площадью более 5000 м. с эмпирически рассчитанной плотностью POI ритейла */ 
with density as (
	select
		b.*
	--	count(p.*) poi_count, -- для дебага
	--	count(p.*) / b.area_m poi_density, -- для дебага
	from index2019.data_building b
	join index2019.data_poi p
		on st_intersects(b.geom, p.geom)
			and b.id_gis = p.id_gis
			and p.stretail is true
--			and p.id_gis = 777 -- для дебага
			and b.area_m > 5000
	group by 
		b.id,
		b.name,
		b.type,
		b.id_gis,
		b.levels,
		b.area_m
	having (count(p.*) / b.area_m) between 0.01 and 0.035 -- Эмпирический показатель. Подобран визуальным сравнением разных выборок 
),

/* Вторая выборка - фильтрация зданий по нескольким сочетаниям тегов, названий и площади */
filtered as (
	select *
	from index2019.data_building
	where ((
			type = 'retail'
			and area_m > 1000
		)
		or (
			type = 'mall'
			and area_m > 2000
		)
		or (
			type in ('commercial', 'warehouse')
			and area_m > 5000
		)
		or (
			(
				name ilike '%торгов%'
				name ilike 'торгов%'
				or name ilike '%развлек%'
				or name ilike '%ТЦ%'
				or name ilike '%ТРЦ%'
				or name ilike '%ТРК%'
				or name ilike '%ТК%'
				or name ilike 'ТЦ%'
				or name ilike 'ТРЦ%'
				or name ilike 'ТРК%'
				or name ilike 'ТК%'
				or name ilike '%ашан%'
				or name ilike 'ашан%'
				or name ilike '%леруа%'
				or name ilike 'леруа%'
				or name ilike '%икеа%'
				or name ilike 'икеа%'
				or name ilike '%мега%'
				or name ilike 'мега%'
				or name ilike '%ok%'
				or name ilike 'ok%'
				or name ilike '%пассаж'
				or name ilike '%пассаж%'
			)
			and area_m > 5000
		))
)

/* Сборка двух выборок в одну таблицу */
select *
from density
union
select *
from filtered;

/* Индексы и первичный ключ */
create index on index2019.data_mall(id_gis);
create index on index2019.data_mall using gist(geom);
alter table index2019.data_mall add primary key(id);

/* Комментарии */
comment on table index2019.data_mall is
'Торговые центры в границах городов РФ.
Источники -  OpenStreetMap, Яндекс.
Актуальность - январь 2020 г.';