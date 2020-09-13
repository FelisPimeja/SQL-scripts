-- Сводный список станций РЖД с атрибутами вокзалов и ОКН
-- Время расчёта ~ 10 сек.

select
	s.id,
	s.esr_id "ЕСР код",
	case
		when sb.head_office is not null
			then 'Вокзал'
		when s.type = 'Станция'
			then 'Станция'
		when s.type = 'Остановочный пункт'
			then 'Остановочный пункт'
	end	"Тип",
	coalesce(s.name, '') "Название",
	coalesce(s.railroad_name, '') "Железная дорога",
	coalesce(s.operation_list, '') "Список доступных операций",
	coalesce(s.transit_point, '') "Транзитные точки",
	coalesce(s.comment, '') "Комментарий",
	coalesce(s.name_en, '') "Название на английском",
	s.id_gis "id_gis города",
	coalesce(b.city, '') "Город",
	a.name "Субъект РФ",
	case
		when sb.id is not null
			then 'есть'
		else 'нет'
	end "Наличие станционного здания",
	coalesce(sb.head_office, '') "Подчинённость станционного здания",
	coalesce(sb."name", '') "Название станционного здания",
	case 
		when sb.address is null
			then case 
				when o.general__address_fulladdress is not null 
					then o.general__address_fulladdress 
				else ''
			end
		else sb.address
	end "Адрес станционного здания",
	case
		when sb.okn_native_id is not null
			then 'да'
		else 'нет'
	end "Здание является ОКН",
	sb.okn_native_id "id ОКН в реестре Минкульта",
	coalesce(o.nativename, '') "Название ОКН",
	coalesce(o.general_createdate, '') "Датировка ОКН",
	round(st_x(s.geom)::numeric, 5) x,
	round(st_y(s.geom)::numeric, 5) y,
	coalesce(sb.phone, '') "Телефон",
	coalesce(sb.email, '') email,
	coalesce(sb.comment, '') "Комментарий по станционному зданию"
from russia.rzd_railway_station s
left join russia.rzd_railway_station_building sb
	on sb.station_id = s.id
left join russia.city_boundary b 
	on s.id_gis = b.id_gis
left join index2019.data_okn o 
	on o.nativeid = sb.okn_native_id
left join (
	select s.id, a.name
	from russia.rzd_railway_station s
	left join osm.admin_ru a
		on st_intersects(a.geom, s.geom)
			and a.admin_level = 4
			-- По быстрому отфильтровываем в ОСМ Крым и Севастополь, т.к. в них станции управляются не РЖД:
			and a.name not in ('Автономна Республіка Крим', 'Севастополь', 'Oğuz rayonu', 'Республика Крым')
) a on a.id = s.id

--select * from osm.admin_ru where admin_level = 4
--select distinct type from russia.rzd_railway_station

--select count(*) from russia.rzd_railway_station_building where official_status = 'вокзал'
update table russia.rzd_railway_station_building sb
	set station_id