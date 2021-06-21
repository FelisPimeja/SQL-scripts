/* 28-й индикатор. Доля объектов культурного наследия, */
/* в которых размещаются объекты социально-досуговой инфраструктуры */
/* Время расчёта ~ 3,5 часа  */

/* Визуализация заматченных памятников */
drop materialized view  if exists index2019.viz_i28 cascade;
create materialized view index2019.viz_i28 as 
/* Фильтрация памятников  */
with okn_filtered as (
	select
		id,
		id_gis,
		nativename,
		general__address_fulladdress fulladdress,
		geom
	from index2019.data_okn
	where nativename !~* 'могил|ограда| стел+а|обелиск|мемориал|бюст|надгроб|склеп|знак|улица|статуя|урна|памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок'
		or (nativename ~* 'жилой|дом|домик|флигель|башня|ансамбль|часовн|палаты|терем|павильон|школ|церковь'
			and nativename !~* 'памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок')
),

/* Матчинг памятников и зданий из OpenStreetMap */
osm_okn as (
	select distinct on (o.geom)
		o.id,
		o.nativename,
		o.id_gis,
		o.fulladdress,
--		st_collect(o.geom, b.geom), -- для дебага
		o.geom okn_geom,
		b.geom osm_geom	
	from okn_filtered o
	join lateral (
		select b.geom
		from index2019.data_building b
		where o.id_gis = b.id_gis
			and st_dwithin(o.geom::geography, b.geom::geography, 5)
		order by o.geom::geography <-> (st_centroid(b.geom))::geography
		limit 1
	) b on true
--	where o.id_gis < 10 -- для дебага
)

/* Матчинг предыдущего продукта и социально-досуговых POI из Яндекса */
select
	o.id,
	o.nativename,
	o.fulladdress,
	o.id_gis,
	p.id sdz_id,
	p.name sdz_name,
--	st_collect(st_collect(o.okn_geom, o.osm_geom), p.geom), -- для дебага
--	o.okn_geom,
--	p.geom sdz_geom,
	o.osm_geom
from osm_okn o
join lateral (
	select p.id, p.name, p.geom
	from index2019.data_poi p
	where o.id_gis = p.id_gis
		and p.sdz is true
		and st_dwithin(o.osm_geom::geography, p.geom::geography, 5)
	order by p.geom::geography <-> (st_centroid(o.osm_geom))::geography
	limit 1
) p on true;


/* Индексы  */
create unique index on index2019.viz_i28(id);
create index on index2019.viz_i28(id_gis);
--create index on index2019.viz_i28 using gist(okn_geom);
create index on index2019.viz_i28 using gist(osm_geom);
--create index on index2019.viz_i28 using gist(sdz_geom);

/* Комментарии */
comment on materialized view index2019.viz_i28 is 'Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры. 28-й индикатор.';
comment on column index2019.viz_i28.id is 'Уникальный идентификатор объекта культурного наследия';
comment on column index2019.viz_i28.nativename is 'Официальное название объекта культурного наследия';
comment on column index2019.viz_i28.fulladdress is 'Полный адрес объекта культурного наследия';
comment on column index2019.viz_i28.id_gis is 'Уникальный идентификатор города';
comment on column index2019.viz_i28.sdz_id is 'Уникальный идентификатор объекта социально-досуговой инфраструктуры';
comment on column index2019.viz_i28.sdz_name is 'Название объекта социально-досуговой инфраструктуры';
--comment on column index2019.viz_i28.okn_geom is 'Геометрия объекта культурного наследия';
comment on column index2019.viz_i28.osm_geom is 'Геометрия здания из OpenStreetMap в котором предположительно находится объект культурного наследия';
--comment on column index2019.viz_i28.sdz_geom is 'Геометрия объекта социально-досуговой инфраструктуры';


/* Подсчёт числа памятников в каждом городе всего и с фильтрацией  */
drop materialized view  if exists index2019.ind_i28;
create materialized view index2019.ind_i28 as
with okn_filtered as (
	select
		id,
		id_gis,
		nativename,
		geom
	from index2019.data_okn
	where nativename !~* 'могил|ограда| стел+а|обелиск|мемориал|бюст|надгроб|склеп|знак|улица|статуя|урна|памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок'
		or (nativename ~* 'жилой|дом|домик|флигель|башня|ансамбль|часовн|палаты|терем|павильон|школ|церковь'
			and nativename !~* 'памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок')
)

select
	b.id_gis,
	b.city,
	b.region,
	coalesce(o.count, 0) okn_total,
	coalesce(f.count, 0) okn_filtered,
	coalesce(m.count, 0) okn_matching_sdz,
	coalesce(round((m.count * 100 / o.count::numeric), 2), 0) okn_poi_percent_all,
	coalesce(round((m.count * 100 / f.count::numeric), 2), 0) okn_poi_percent_filtered
from index2019.data_boundary b
left join (select id_gis, count(*) from index2019.data_okn group by id_gis) o using(id_gis)
left join (select id_gis, count(*) from okn_filtered group by id_gis) f using(id_gis)
left join (select id_gis, count(*) from index2019.viz_i28 group by id_gis) m using(id_gis);

/* Индексы  */
create unique index on index2019.ind_i28(id_gis);


/* Комментарии */
comment on materialized view index2019.ind_i28 is 'Доля объектов культурного наследия. 28-й индикатор? в которых размещаются объекты социально-досуговой инфраструктуры.';
comment on column index2019.ind_i28.id_gis is 'Уникальный идентификатор города';
comment on column index2019.ind_i28.city is 'Город';
comment on column index2019.ind_i28.region is 'Субъект РФ';
comment on column index2019.ind_i28.okn_total is 'Всего объектов культурного наследия в городе';
comment on column index2019.ind_i28.okn_filtered is 'Всего объектов культурного наследия в городе после фильтрации по признаку "не здание"';
comment on column index2019.ind_i28.okn_matching_sdz is 'Всего объектов культурного наследия в которых расположены объекты социально-досуговой инфраструктуры';
comment on column index2019.ind_i28.okn_poi_percent_all is
'Процент объектов культурного наследия в которых расположены объекты социально-досуговой инфраструктуры от общего числа объектов культурного наследия в городе';
comment on column index2019.ind_i28.okn_poi_percent_filtered is
'Процент объектов культурного наследия в которых расположены объекты социально-досуговой инфраструктуры от общего числа объектов культурного наследия в городе после фильтрации';


/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i28;
create view index2019.comp_i28 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.okn_poi_count, 0) okn_matching_sdz_2018,
	coalesce(i1.okn_matching_sdz, 0) okn_matching_sdz_2019,
	coalesce(i2.okn_count_all, 0) okn_total_2018,
	coalesce(i1.okn_total, 0) okn_total_2019,
	coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0) okn_poi_percent_all_2018,
	coalesce(i1.okn_poi_percent_all, 0) okn_poi_percent_all_2019,
	(case 
		when coalesce(i1.okn_poi_percent_all, 0) > coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0)
			then 2019
	 	when coalesce(i1.okn_poi_percent_all, 0) = coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.ind_i28 i1
left join index2018.i28_okn_poi i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i28 is 'Сравнение с 2018 годом. 28-й индикатор. Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры.';
comment on column index2019.comp_i28.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i28.city is 'Город';
comment on column index2019.comp_i28.region is 'Субъект РФ';
comment on column index2019.comp_i28.okn_matching_sdz_2018 is 'Объекты культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2018 г., ед.';
comment on column index2019.comp_i28.okn_matching_sdz_2018 is 'Объекты культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2019 г., ед.';
comment on column index2019.comp_i28.okn_total_2018 is 'Численность объектов культурного наследия в городе в 2018 г., ед.';
comment on column index2019.comp_i28.okn_total_2018 is 'Численность объектов культурного наследия в городе в 2019 г., ед.';
comment on column index2019.comp_i28.okn_poi_percent_all_2018 is 'Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2018 г.';
comment on column index2019.comp_i28.okn_poi_percent_all_2018 is 'Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2018 г.';
comment on column index2019.comp_i28.higher_value is 'В каком году показатель "Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры" выше';