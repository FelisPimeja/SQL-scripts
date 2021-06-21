select
	p.id_gis,
	b.b.CatRosStat--, 
--	sum(b.gba) sum_gba,
--	count(p.*) total_poi
from editor.poi_spb_no_duplic_for_test p
left join editor.classificator_1310_gba_v3_29_01_2021 b using(rubrics)

where
--	sde.st_intersects(shape, sde.st_transform(sde.st_multipolygon %WKT2%, 4326))
	gba is not null
	and p.id_gis = 1074
group by p.id_gis, b.CatRosStat




select * from editor.poi_spb_no_duplic_for_test