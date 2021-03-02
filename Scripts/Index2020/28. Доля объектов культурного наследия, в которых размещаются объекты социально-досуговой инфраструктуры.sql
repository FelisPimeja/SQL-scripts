
/* 28-й индикатор. Доля объектов культурного наследия, */
/* в которых размещаются объекты социально-досуговой инфраструктуры */
/* to do: исправить на использование зданий 2020!!! */
/* Время расчёта ~ 15 мин.  */

/* Визуализация заматченных памятников */
/* Фильтрация памятников  */
create index on index2020.data_okn(nativename);
drop table if exists okn_filtered;
create temp table okn_filtered as (
	select
		id,
		id_gis,
		nativename,
		geom
	from index2020.data_okn
	where nativename !~* 'могил|ограда| стел+а|обелиск|мемориал|бюст|надгроб|склеп|знак|улица|статуя|урна|памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок'
		or (nativename ~* 'жилой|дом|домик|флигель|башня|ансамбль|часовн|палаты|терем|павильон|школ|церковь'
			and nativename !~* 'памятник|скульптур|место|стена|кладбище|мост|пруд|фонтан|участок')
);
create index on okn_filtered using gist(geom);
create index on okn_filtered using gist((geom::geography));
create index on okn_filtered(id_gis);

/* Матчинг памятников и зданий из OpenStreetMap */
drop table if exists osm_okn;
create temp table osm_okn as (
	select distinct on (o.geom)
		o.id,
		o.nativename,
		o.id_gis,
--		st_collect(o.geom, b.geom), -- для дебага
		o.geom okn_geom,
		b.geom osm_geom	
	from okn_filtered o
	join lateral (
		select b.geom
		from index2019.data_building b
		where o.id_gis = b.id_gis
			and st_dwithin(o.geom::geography, b.geom::geography, 5)
		order by o.geom::geography <-> b.geom::geography
		limit 1
	) b on true
--	where o.id_gis < 10 -- для дебага
);
create index on osm_okn using gist(osm_geom);
create index on osm_okn using gist((osm_geom::geography));
create index on osm_okn using gist((st_centroid(osm_geom)::geography));
create index on osm_okn(id_gis);

/* Матчинг предыдущего продукта и социально-досуговых POI из Яндекса */
drop table if exists index2020.viz_i28;
create table index2020.viz_i28 as 
select
	o.id,
	o.nativename,
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
	from index2020.data_poi p
	where o.id_gis = p.id_gis
--		and p.sdz is true -- Для правильного расчёта индикатора эту строку надо раскоментировать. Но индикатор рассчитывается неправильно для сохранения приемственности результатов
		and st_dwithin(o.osm_geom::geography, p.geom::geography, 5)
	order by p.geom::geography <-> (st_centroid(o.osm_geom))::geography
	limit 1
) p on true;


/* Индексы  */
alter table index2020.viz_i28 add primary key(id);
create index on index2020.viz_i28(id_gis);
--create index on index2020.viz_i28 using gist(okn_geom);
create index on index2020.viz_i28 using gist(osm_geom);
--create index on index2020.viz_i28 using gist(sdz_geom);

/* Комментарии */
comment on table index2020.viz_i28 is 'Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры. 28-й индикатор.';
comment on column index2020.viz_i28.id is 'Уникальный идентификатор объекта культурного наследия';
comment on column index2020.viz_i28.nativename is 'Официальное название объекта культурного наследия';
comment on column index2020.viz_i28.id_gis is 'Уникальный идентификатор города';
comment on column index2020.viz_i28.sdz_id is 'Уникальный идентификатор объекта социально-досуговой инфраструктуры';
comment on column index2020.viz_i28.sdz_name is 'Название объекта социально-досуговой инфраструктуры';
--comment on column index2020.viz_i28.okn_geom is 'Геометрия объекта культурного наследия';
comment on column index2020.viz_i28.osm_geom is 'Геометрия здания из OpenStreetMap в котором предположительно находится объект культурного наследия';
--comment on column index2020.viz_i28.sdz_geom is 'Геометрия объекта социально-досуговой инфраструктуры';


/* Подсчёт числа памятников в каждом городе всего и с фильтрацией  */
drop table  if exists index2020.ind_i28;
create table index2020.ind_i28 as
select
	b.id_gis,
	b.city,
	b.region_name,
	coalesce(o.count, 0) okn_total,
	coalesce(f.count, 0) okn_filtered,
	coalesce(m.count, 0) okn_matching_sdz,
	coalesce(round((m.count * 100 / o.count::numeric), 2), 0) okn_poi_percent_all,
	coalesce(round((m.count * 100 / f.count::numeric), 2), 0) okn_poi_percent_filtered
from index2020.data_boundary b
left join (select id_gis, count(*) from index2020.data_okn group by id_gis) o using(id_gis)
left join (select id_gis, count(*) from okn_filtered group by id_gis) f using(id_gis)
left join (select id_gis, count(*) from index2020.viz_i28 group by id_gis) m using(id_gis);

/* Индексы  */
alter table index2020.ind_i28 add primary key(id_gis);


/* Комментарии */
comment on table index2020.ind_i28 is 'Доля объектов культурного наследия. 28-й индикатор? в которых размещаются объекты социально-досуговой инфраструктуры.';
comment on column index2020.ind_i28.id_gis is 'Уникальный идентификатор города';
comment on column index2020.ind_i28.city is 'Город';
comment on column index2020.ind_i28.region_name is 'Субъект РФ';
comment on column index2020.ind_i28.okn_total is 'Всего объектов культурного наследия в городе';
comment on column index2020.ind_i28.okn_filtered is 'Всего объектов культурного наследия в городе после фильтрации по признаку "не здание"';
comment on column index2020.ind_i28.okn_matching_sdz is 'Всего объектов культурного наследия в которых расположены объекты социально-досуговой инфраструктуры';
comment on column index2020.ind_i28.okn_poi_percent_all is
'Процент объектов культурного наследия в которых расположены объекты социально-досуговой инфраструктуры от общего числа объектов культурного наследия в городе';
comment on column index2020.ind_i28.okn_poi_percent_filtered is
'Процент объектов культурного наследия в которых расположены объекты социально-досуговой инфраструктуры от общего числа объектов культурного наследия в городе после фильтрации';


/* Проверки */
/* Сравнение с 2019 годом. */
drop table if exists index2020.comp_i28;
create table index2020.comp_i28 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region_name,
	coalesce(i2.okn_matching_sdz, 0) okn_matching_sdz_2019,
	coalesce(i1.okn_matching_sdz, 0) okn_matching_sdz_2020,
	coalesce(i2.okn_total, 0) okn_total_2019,
	coalesce(i1.okn_total, 0) okn_total_2020,
	coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0) okn_poi_percent_all_2019,
	coalesce(i1.okn_poi_percent_all, 0) okn_poi_percent_all_2020,
	(case 
		when coalesce(i1.okn_poi_percent_all, 0) > coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0)
			then 2020
	 	when coalesce(i1.okn_poi_percent_all, 0) = coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0)
			then null
		else 2019
	end)::smallint higher_value -- в каком году показатель выше
from index2020.ind_i28 i1
left join index2019.ind_i28_v2 i2 using(id_gis)
order by id_gis;

/* Комментарии */
comment on table index2020.comp_i28 is 'Сравнение с 2018 годом. 28-й индикатор. Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры.';
comment on column index2020.comp_i28.id_gis is 'Уникальный идентификатор города';
comment on column index2020.comp_i28.city is 'Город';
comment on column index2020.comp_i28.region_name is 'Субъект РФ';
comment on column index2020.comp_i28.okn_matching_sdz_2020 is 'Объекты культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2020 г., ед.';
comment on column index2020.comp_i28.okn_matching_sdz_2019 is 'Объекты культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2019 г., ед.';
comment on column index2020.comp_i28.okn_total_2020 is 'Численность объектов культурного наследия в городе в 2020 г., ед.';
comment on column index2020.comp_i28.okn_total_2019 is 'Численность объектов культурного наследия в городе в 2019 г., ед.';
comment on column index2020.comp_i28.okn_poi_percent_all_2020 is 'Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2020 г.';
comment on column index2020.comp_i28.okn_poi_percent_all_2019 is 'Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры в 2019 г.';
comment on column index2020.comp_i28.higher_value is 'В каком году показатель "Доля объектов культурного наследия, в которых размещаются объекты социально-досуговой инфраструктуры" выше';



/* Вывод в Excel */
select 
	id_gis "id_gis города",
	city "Город",
	region_name "Субъект РФ",
	okn_matching_sdz_2019 "ОКН + СДЗ 2019",
	okn_matching_sdz_2020 "ОКН + СДЗ 2020",
	okn_total_2019 "Всего ОКН 2019",
	okn_total_2020 "Всего ОКН 2020",
	okn_poi_percent_all_2019 "% ОКН + СДЗ 2019",
	okn_poi_percent_all_2020 "% ОКН + СДЗ 2020",
	case when higher_value is null then 'Поровну' else higher_value::text end "В каком году больше"
from index2020.comp_i28;