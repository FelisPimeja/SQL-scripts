/* Неполный набор различных манипуляций над сводной таблицей по станциям РЖД */
/* Сохранён "на всякий случай" */


select
	s.name,
	s.id,
	s.id_gis,
	r.id_gis,
	s.geom
from russia.rzd_railway_station_svod s
full outer join russia.rzd_railway_station r using (id)
where not r.id_gis = s.id_gis



alter table russia.rzd_railway_station_svod 
	add column first_floor_location text
	


update russia.rzd_railway_station_svod s
	set multimodality = case
		when st_dwithin(s.geom::geography, r.geom::geography, 800)
			
		Морской/ Речной порт
		Аэропорт
		Автовокзал
		Связь с аэропортом (аэроэкспресс)
		Метро
		Наземный общественный транспорт


	from russia.rzd_branche_zone r
	where (s.railroad_name is null or s.railroad_name = '')
		and st_intersects(r.geom, s.geom)

Морской/ Речной порт
Аэропорт
Автовокзал
Связь с аэропортом (аэроэкспресс)
Метро
Наземный общественный транспорт		
		
		
		
		
update russia.rzd_railway_station_svod s
	set multimodality = v.multi
	from (
	select
	s.id,
	s.name station_name,
	array_to_string(array_agg(array[
		case when p1.id is not null then 'Морской/Речной порт' end,
		case when p2.id is not null then 'Аэропорт' end, 
		case when p3.id is not null then 'Автовокзал' end, 
		case when p4.id is not null then 'Метро' end, 
		case when p5.id is not null then 'Наземный общественный транспорт' end 
	]), ', ') multi--,
--	st_collect(array[s.geom, p1.geom, p2.geom, p3.geom, p4.geom, p5.geom]) geom
from russia.rzd_railway_station_svod s
left join lateral (
	select p.*
	from (
		select p.* from index2019.data_poi p
		join osm.waterareas_ru w
			on st_dwithin(p.geom::geography, w.geom::geography, 200)
	) p
	where p.rubrics = 'Порт'
		and st_dwithin(s.geom::geography, p.geom::geography, 800)
	limit 1
	) p1 on true 
left join lateral (
	select p.*
	from index2019.data_poi p
	where p.rubrics = 'Аэропорт'
		and st_dwithin(s.geom::geography, p.geom::geography, 800)
	limit 1
	) p2 on true 
left join lateral (
	select p.*
	from index2019.data_poi p
	where p.rubrics = 'Автовокзал'
		and st_dwithin(s.geom::geography, p.geom::geography, 800)
	limit 1
	) p3 on true 
left join lateral (
	select p.*
	from osm.transport_points_ru p
	where p.type = 'subway_entrance'
		and st_dwithin(s.geom::geography, p.geom::geography, 800)
	limit 1
	) p4 on true 
left join lateral (
	select p.*
	from index2019.data_poi p
	where p.rubrics = 'Остановка общественного транспорта'
		and st_dwithin(s.geom::geography, p.geom::geography, 800)
	limit 1
	) p5 on true 
--where s.id < 1000
group by s.id, s.name --, p1.geom, p2.geom, p3.geom, p4.geom, p5.geom
) v
where s.id = v.id
		
		
		
		
update russia.rzd_railway_station_svod s
	set pop_in_2km_radius = sa.sum_pop
	from (			
		--explain
		select s.id, s.name, sum(p.population) sum_pop
		from tmp.tmp_railway_service_areas s
		join index2019.data_pop_altermag p 
			on st_intersects(s.geom, p.geom)
				and s.id_gis = p.id_gis
		group by s.id, s.name
	) sa 
	where s.id = sa.id

create index on tmp.tmp_railway_service_areas(id_gis);
		

update russia.rzd_railway_station_svod s
	set terminal_building = case 
		when (
			station_building_id is not null
				or dzv_terminal is true 
				or cdpo_terminal is true 
				or dze_terminal is true
				or dze_building is true
		)
			then true::bool 
		else false::bool 
	end 

	
select
	id_gis,
	city,
--	count(*)
	region_name--,
--	admin_status
from russia.city 
where city in (
	'Нарьян-Мар','Белоярский','Когалым','Лангепас',
	'Мегион','Нефтеюганск','Нижневартовск','Нягань',
	'Покачи','Пыть-Ях','Радужный','Сургут','Урай',
	'Ханты-Мансийск','Югорск','Анадырь','Губкинский',
	'Лабытнанги','Муравленко','Надым','Новый Уренгой',
	'Ноябрьск','Салехард'
)
	and id_gis not in (1095)
--group by city
order by city


update russia.city c
	set utm_zone = u.utm_zone
	from world.utm_zones u 
	where st_intersects(u.geom, c.geom)





777 'Развитый'
778,1071,1083,1078,1076,1081 'Развивающийся'
1082,1075,1074,1077,1082,1084,1080,1079,1073 'Отстающий'

select id_gis, city from russia.city where city in (
'Москва',
'Санкт-Петербург',
'Краснодар',
'Екатеринбург',
'Самара',
'Уфа',
'Казань',
'Нижний Новгород',
'Красноярск',
'Пермь',
'Ростов-на-Дону',
'Волгоград',
'Новосибирск',
'Челябинск',
'Омск',
'Воронеж'
)	
	
	
select distinct climate_region_koppen from russia.rzd_railway_station_svod order by climate_region_koppen

select purchase_power, array_to_string(array_agg(id_gis), ',') id_gis
from tmp.tmp_purchase_power group by purchase_power 
		
select * from russia.rzd_railway_station_svod where geom is null



update russia.rzd_railway_station_svod s
	set
		settlement_size = case 
			when r.pop2020 > 1000000 then 'XXL Крупнейшие'
			when r.pop2020 between 250000 and 1000000 then 'XL Крупные'
			when r.pop2020 between 100000 and 250000 then 'L Большие'
			when r.pop2020 between 50000 and 100000 then 'M Средние'
			when r.pop2020 between 25000 and 50000 then 'S Малые тип 1'
			when r.pop2020 between 5000 and 25000 then 'XS Малые тип 2'
			when r.pop2020 < 5000 then 'XXS Малые тип 3'
		end,
		city = r.place_name
	from (
		select
			s.id,
			s.name,
			p.name place_name,
			p.peoples pop2020
		from russia.rzd_railway_station_svod s
		left join lateral (
			select p.id, p.name, p.peoples 
			from russia.place_all p
			where st_dwithin(s.geom::geography, p.geom::geography, 1000)
			order by s.geom::geography <-> p.geom::geography
			limit 1
		) p on true 
		where s.id_gis is null
	) r 
	where s.id = r.id
		and s.id_gis is null;
		

alter table russia.rzd_railway_station_svod 
	add column track_divarication bool;
	

	
alter table russia.rzd_railway_station_svod
	add column building_type text,
	add column address text,
	add column passanger_type text,
	add column build_date text,
	add column architect text,
	add column project text,
	add column is_operating bool,
	add column current_status text,
	add column in_settlement_location text,
	add column in_settlement_role text,
	add column building_platform_location text,
	add column relative_to_ground_level text,
	add column tracks_total smallint,
	add column platforms_total smallint,
	add column high_platforms_total smallint,
	add column low_platforms_total smallint,
	add column middle_platforms_total smallint,
	add column terminal_platform_relation text,
	add column comment_on_tracks_platforms text,
	add column suburb_trains_separate_terminal bool,
	add column long_distance_trains_winter smallint,
	add column long_distance_trains_summer smallint,
	add column suburb_trains_winter smallint,
	add column suburb_trains_summer smallint,
	add column passanger_flow_suburb_trains int,
	add column passanger_flow_long_distance_trains int,
	add column terminal_total_area_m2 text,
	add column terminal_common_use_area_m2 text,
	add column functional_use text,
	add column services text,
	add column transport_accessability text,
	add column disabled_accessability text,
	add column comment_disabled_accessability text,
	add column surroundings text,
	add column building_features text,
	add column contacts text;


update russia.rzd_railway_station_svod s 
	set
		"class" = t."class", 
		building_type = t.building_type,
		address = t.address,
		passanger_type = t.passanger_type,
		build_date = t.build_date,
		architect = t.architect,
		project = t.project,
		is_operating = case when t.is_operating = 'Да' then true::bool when t.is_operating = 'Нет' then false::bool else null end,
		current_status = t.current_status,
		in_settlement_location = t.in_settlement_location,
		in_settlement_role = t.in_settlement_role,
		building_platform_location = t."building-platform_location",
		relative_to_ground_level = t.relative_to_ground_level,
		tracks_total = t.tracks_total::smallint,
		platforms_total = t.platforms_total::smallint,
		high_platforms_total = t.high_platforms_total::smallint,
		low_platforms_total = t.low_platforms_total::smallint,
		middle_platforms_total = t.middle_platforms_total::smallint,
		terminal_platform_relation = t."terminal-platform_relation",
		comment_on_tracks_platforms = t."comment_on_tracks-platforms",
		suburb_trains_separate_terminal = case when t.suburb_trains_separate_terminal = 'Да' then true::bool when t.suburb_trains_separate_terminal = 'Нет' then false::bool else null end,
		long_distance_trains_winter = t."long-distance_trains_winter"::smallint,
		long_distance_trains_summer = t."long-distance_trains_summer"::smallint,
		suburb_trains_winter = t.suburb_trains_winter::smallint,
		suburb_trains_summer = t.suburb_trains__summer::smallint,
		passanger_flow_suburb_trains = t.passanger_flow_suburb_trains::int,
		passanger_flow_long_distance_trains = t.passanger_flow_long_distance_trains::int,
		terminal_total_area_m2 = t.terminal_total_area_m2,
		terminal_common_use_area_m2 = t.terminal_common_use_area_m2,
		functional_use = t.functional_use,
		services = t.services_,
		transport_accessability = t.transport_accessability,
		disabled_accessability = t.disabled_accessability,
		comment_disabled_accessability = t.comment_disabled_accessability,
		surroundings = t.surroundings,
		building_features = t.building_features,
		contacts = t.contacts,
		is_okn = case when case when t.is_okn = 'Да' then true::bool when t.is_okn = 'Нет' then false::bool else null end is not null and s.is_okn <> case when t.is_okn = 'Да' then true::bool when t.is_okn = 'Нет' then false::bool else null end then case when t.is_okn = 'Да' then true::bool when t.is_okn = 'Нет' then false::bool else null end end
	from (
		select s.id sid, t.*
		from tmp.tmp_rzd_svod_6 t
		join lateral (
			select s.id 
			from russia.rzd_railway_station_svod s
			where st_dwithin(s.geom::geography, t.geom::geography, 1000)
			order by s.geom::geography <-> t.geom::geography
			limit 1
		) s on true
	) t
	where t.sid = s.id;

update russia.rzd_railway_station_svod s 
	set functional_use = r.functional_use
	from (
		select
			s.id,
			s.name,
		--	array_to_string(array_agg(distinct l."type"), ',') landuse,
			case 
				when sum(st_area(l.geom::geography)) filter(where l.type in ('industrial', 'railway')) > 0.5 * sum(st_area(l.geom::geography))
					then 'Промышленная территория'
				when sum(st_area(l.geom::geography)) filter(where l.type not in ('industrial', 'railway')) > 5000
					then 'Общественно-деловая и жилая территория'
				else null
			end functional_use,
			s.geom
		from russia.rzd_railway_station_svod s
		left join osm.landusages_ru l
			on st_dwithin(s.geom::geography, l.geom::geography, 800)
				and l.type in ('residential','school','cemetery','place_of_worship','park','stadium','barracks','college','industrial','pitch','allotments','recreation_ground','playground','railway')
		group by s.id, s.name, s.geom
	) r
	where s.id = r.id;

create index on street_classify.building_classify_2_pass using gist((geom::geography));


update russia.rzd_railway_station_svod s 
	set functional_use = r.functional_use
	from (
		select 
			s.id,
			s.name,
--			s.functional_use,
			case 
				when s.functional_use is not null 
					then s.functional_use 
				else case
					when count(b.id) > 10
						then 'Общественно-деловая и жилая территория'
					else null 
				end 
			end functional_use,
			s.geom
		from russia.rzd_railway_station_svod s
		left join street_classify.building_classify_2_pass b 
			on st_dwithin(s.geom::geography, b.geom::geography, 800)
		group by s.id, s.name, s.geom, s.functional_use
	) r
	where s.id = r.id
		and s.functional_use is null;
		
	
	
	
	
	
update russia.rzd_railway_station_svod s 
	set track_divarication = true
	where "type" in ('Станция','Вокзал')
	
select * from russia.rzd_railway_station_svod
where "type" in ('Станция','Вокзал');






comment on table russia.rzd_railway_station_svod is 'Сводная таблица с информацией по станциям и остановочным пунктам РЖД';
comment on column russia.rzd_railway_station_svod.id is 'Первичный ключ';
comment on column russia.rzd_railway_station_svod.esr_id is 'Код ЕСР (единая сетевая разметка)';
comment on column russia.rzd_railway_station_svod.type is 'Тип объекта (Станция/Остановочный пункт)';
comment on column russia.rzd_railway_station_svod.name is 'Наименование станции/остановочного пункта  (в соответствии с ТР №4)';
comment on column russia.rzd_railway_station_svod.railroad_name is 'Наименование филиала железной дороги';
comment on column russia.rzd_railway_station_svod.operation_list is 'Производимые коммерческие операции';
comment on column russia.rzd_railway_station_svod.transit_point is 'Транзитные пункты';
comment on column russia.rzd_railway_station_svod.class is 'Класс';
comment on column russia.rzd_railway_station_svod.comment is 'Комментарий';
comment on column russia.rzd_railway_station_svod.name_en is 'Название на английском';
comment on column russia.rzd_railway_station_svod.id_gis is 'id_gis города';
comment on column russia.rzd_railway_station_svod.settlement_name is 'Город\населенный пункт размещения';
comment on column russia.rzd_railway_station_svod.region is 'Субъект РФ';
comment on column russia.rzd_railway_station_svod.dzv_terminal is 'Наличие здания вокзала в ведомстве ДЖВ';
comment on column russia.rzd_railway_station_svod.cdpo_terminal is 'Наличие здания вокзала или пассажирского здания в ведомстве ЦДПО';
comment on column russia.rzd_railway_station_svod.dze_terminal is 'Наличие здания вокзала в ведомстве ДЗЭ';
comment on column russia.rzd_railway_station_svod.dze_building is 'Наличие пассажирского здания в ведомстве ДЗЭ';
comment on column russia.rzd_railway_station_svod.terminal_name is 'Название станционного здания';
comment on column russia.rzd_railway_station_svod.terminal_address is 'Адрес станционного здания';
comment on column russia.rzd_railway_station_svod.terminal_okn_rzd is 'Здание является ОКН (по мнению РЖД)';
comment on column russia.rzd_railway_station_svod.terminal_okn_mincult is 'Здание является ОКН (по данным реестра)';
comment on column russia.rzd_railway_station_svod.okn_id_mincult is 'id ОКН в реестре Минкульта';
comment on column russia.rzd_railway_station_svod.okn_name_mincult is 'Название ОКН';
comment on column russia.rzd_railway_station_svod.okn_date is 'Датировка ОКН';
comment on column russia.rzd_railway_station_svod.x is 'X';
comment on column russia.rzd_railway_station_svod.y is 'Y';
comment on column russia.rzd_railway_station_svod.geom is 'Геометрия';
comment on column russia.rzd_railway_station_svod.station_building_id is 'id станционного здания (внешний ключ)';
comment on column russia.rzd_railway_station_svod.climate_region is 'Климатический район по СП';
comment on column russia.rzd_railway_station_svod.climate_region_koppen is 'Климатический регион по Кёппену (код)';
comment on column russia.rzd_railway_station_svod.climate_region_koppen_def is 'Климатический регион по Кёппену (расшифровка)';
comment on column russia.rzd_railway_station_svod.topography is 'Характер рельефа местности';
comment on column russia.rzd_railway_station_svod.settlement_pop is 'Население населённого пункта';
comment on column russia.rzd_railway_station_svod.settlement_size is 'Величина населенного пункта';
comment on column russia.rzd_railway_station_svod.settlement_economy_level is 'Экономическое влияние (Уровень ВВП / ВГП)';
comment on column russia.rzd_railway_station_svod.purchase_power is 'Покупательная способность (отношение зп к стоимости стандартного потреб. набора)';
comment on column russia.rzd_railway_station_svod.settlement_admin_status is 'Административный статус';
comment on column russia.rzd_railway_station_svod.fz is 'Функциональное наполнение окружения (r=800м)';
comment on column russia.rzd_railway_station_svod.pop_in_2km_radius is 'Население (количество жителей в изохроне пешеходной доступности 2км)';
comment on column russia.rzd_railway_station_svod.multimodality is 'Мультимодальность';
comment on column russia.rzd_railway_station_svod.terminal_building is 'Наличие вокзала / пассажирского здания';
comment on column russia.rzd_railway_station_svod.is_okn is 'Охранный статус';
comment on column russia.rzd_railway_station_svod.building_type is 'Тип здания';
comment on column russia.rzd_railway_station_svod.address is 'Подробный адрес';
comment on column russia.rzd_railway_station_svod.passanger_type is 'Категории пассажиров';
comment on column russia.rzd_railway_station_svod.build_date is 'Период строительства';
comment on column russia.rzd_railway_station_svod.architect is 'Авторы проекта';
comment on column russia.rzd_railway_station_svod.project is 'Тип проекта';
comment on column russia.rzd_railway_station_svod.is_operating is 'Находится в эксплуатации';
comment on column russia.rzd_railway_station_svod.current_status is 'Текущее состояние';
comment on column russia.rzd_railway_station_svod.in_settlement_location is 'Расположение в городе\в населенном пункте';
comment on column russia.rzd_railway_station_svod.in_settlement_role is 'Роль в городе';
comment on column russia.rzd_railway_station_svod.building_platform_location is 'Расположение зданий, путей и платформ';
comment on column russia.rzd_railway_station_svod.relative_to_ground_level is 'Расположение относительно уровня земли';
comment on column russia.rzd_railway_station_svod.tracks_total is 'Количество путей';
comment on column russia.rzd_railway_station_svod.platforms_total is 'Количество платформ';
comment on column russia.rzd_railway_station_svod.high_platforms_total is 'Количество высоких платформ (1100 мм)';
comment on column russia.rzd_railway_station_svod.low_platforms_total is 'Количество низких платформ (200 мм)';
comment on column russia.rzd_railway_station_svod.middle_platforms_total is 'Количество средних платформ (550 мм)';
comment on column russia.rzd_railway_station_svod.terminal_platform_relation is 'Связь платформ и здания вокзала';
comment on column russia.rzd_railway_station_svod.comment_on_tracks_platforms is 'Пути и платформы. Примечания.';
comment on column russia.rzd_railway_station_svod.suburb_trains_separate_terminal is 'Наличие отдельного здания для пассажиров пригородных поездов';
comment on column russia.rzd_railway_station_svod.long_distance_trains_winter is 'Пары поездов дальнее следование - ЗИМА';
comment on column russia.rzd_railway_station_svod.long_distance_trains_summer is 'Пары поездов дальнее следование - ЛЕТО';
comment on column russia.rzd_railway_station_svod.suburb_trains_winter is 'Пары поездов пригород - ЗИМА';
comment on column russia.rzd_railway_station_svod.suburb_trains_summer is 'Пары поездов пригород - ЛЕТО';
comment on column russia.rzd_railway_station_svod.passanger_flow_suburb_trains is 'Пассажиропоток (пригородный)';
comment on column russia.rzd_railway_station_svod.passanger_flow_long_distance_trains is 'Пассажиропоток (дальний)';
comment on column russia.rzd_railway_station_svod.terminal_total_area_m2 is 'Общая площадь вокзала';
comment on column russia.rzd_railway_station_svod.terminal_common_use_area_m2 is 'Площадь помещений общего пользования';
comment on column russia.rzd_railway_station_svod.functional_use is 'Функциональное использование';
comment on column russia.rzd_railway_station_svod.services is 'Услуги и сервисы для пассажиров';
comment on column russia.rzd_railway_station_svod.transport_accessability is 'Транспортная доступность';
comment on column russia.rzd_railway_station_svod.disabled_accessability is 'Доступность МГН';
comment on column russia.rzd_railway_station_svod.comment_disabled_accessability is 'Доступность МГН. Примечания';
comment on column russia.rzd_railway_station_svod.surroundings is 'Окружение';
comment on column russia.rzd_railway_station_svod.building_features is 'Особенность здания (при наличии)';
comment on column russia.rzd_railway_station_svod.contacts is 'Контакты';
comment on column russia.rzd_railway_station_svod.track_divarication is 'Наличие путевого развития';