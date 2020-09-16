--Подсчёт неактивных земель для городов ВЭБа
--explain
select 
	b.id_gis,
	b.city,
	b.region_name,
	coalesce(round((sum(st_area((
		case
			when st_within(l.geom, b.geom)
				then l.geom
			else st_collectionextract(st_intersection(b.geom, l.geom), 3)
		end
	)::geography)) / 10000)::numeric, 2), 0) total_area_inactive_ha
from (select b.* from russia.city_boundary b join veb_rf.city c using(id_gis)) b
left join osm.landusages_ru l
	on st_intersects(b.geom, l.geom)
		and l.type in ('industrial', 'railway', 'military', 'port', 'brownfield', 'quarry', 'harbour')
group by b.id_gis, b.city, b.region_name
order by b.id_gis;
