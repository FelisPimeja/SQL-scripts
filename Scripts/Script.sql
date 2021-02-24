select 
	q.id_gis,
	c.city "Город",
	c.region_name "Субъект РФ",
	-- средняя и целевая площадь квартала
	case when (avg(q.public_transport_access::int) filter(where q.quater_class is not null)) <= 0.5 then 'Низкий' else 'Высокий' end "Ур. доступн. обществ. транспорта",
--	q.public_transport_access_reference,
--	q.public_transport_access_delta,
--	q.ipa,
	case
		when (avg(case when q.ipa = 'Средняя (2)' then 2 when q.ipa = 'Низкая (1)' then 1 when q.ipa = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 1
			then 'Низкий'
		when (avg(case when q.ipa = 'Средняя (2)' then 2 when q.ipa = 'Низкая (1)' then 1 when q.ipa = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 2
			then 'Средний'
		else 'Высокий'
	end "Пешеходн. связность с прилег. терр.",
--	q.ipa_delta,
	case
		when (avg(case when q.social_access = 'Средняя (2)' then 2 when q.social_access = 'Низкая (1)' then 1 when q.social_access = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 1
			then 'Низкий'
		when (avg(case when q.social_access = 'Средняя (2)' then 2 when q.social_access = 'Низкая (1)' then 1 when q.social_access = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 2
			then 'Средний'
		else 'Высокий'
	end "Обеспеч. соц. объектами",
--	q.social_access_reference,
--	q.social_access_delta,
	case
		when (avg(case when q.entertainment_access = 'Средняя (2)' then 2 when q.entertainment_access = 'Низкая (1)' then 1 when q.entertainment_access = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 1
			then 'Низкий'
		when (avg(case when q.entertainment_access = 'Средняя (2)' then 2 when q.entertainment_access = 'Низкая (1)' then 1 when q.entertainment_access = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 2
			then 'Средний'
		else 'Высокий'
	end "Обеспеч. развлекат. объектами",
--	q.entertainment_access_reference,
--	q.entertainment_access_delta,
	case
		when (avg(case when q.service_access = 'Средняя (2)' then 2 when q.service_access = 'Низкая (1)' then 1 when q.service_access = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 1
			then 'Низкий'
		when (avg(case when q.service_access = 'Средняя (2)' then 2 when q.service_access = 'Низкая (1)' then 1 when q.service_access = 'Высокая (3)' then 3 end) filter(where q.quater_class is not null)) <= 2
			then 'Средний'
		else 'Высокий'
	end  "Обеспеч. сервисн. объектами",
--	q.service_access_reference,
--	q.service_access_delta,
	case when (avg(q.greenery_access::int) filter(where q.quater_class is not null)) <= 0.5 then 'Низкий' else 'Высокий' end   "Обеспеч. дост. к озелен. терр."--,
--	avg(q.greenery_access) filter(where q.quater_class is not null) avg_greenery_access--,
--	q.greenery_access_reference,
--	q.greenery_access_delta,
--	q.odz_area_percent,
--	q.odz_area_percent_reference,
--	q.odz_area_percent_delta,
--	q.hazardous_dwelling,
--	q.hazardous_dwelling_reference,
--	q.hazardous_dwelling_delta,
--	q.negative_factors,
--	q.negative_factors_reference,
--	q.negative_factors_delta,
--	q.far,
--	q.sum_delta
from russia.city c 
left join street_classify.quater_stat_verify q using(id_gis)
group by 
	q.id_gis,
	c.city,
	c.region_name--,
--	q.area_ha_reference,
--	q.pop_density_reference,
--	q.built_density_reference,
--	q.residential_median_level_reference,
--	q.public_transport_access_reference,
--	q.ipa_reference,
--	q.social_access_reference,
--	q.entertainment_access_reference,
--	q.service_access_reference,
--	q.greenery_access_reference,
--	q.odz_area_percent_reference,
--	q.hazardous_dwelling_reference,
--	q.negative_factors_reference
	
	
select distinct quater_class from street_classify.quater_stat_verify