select
	p.id_gis,
	b.CatRosStat, 
--	regexp_replace(b.CatRosStat, '(\d+?)\.\s.*$', '\1') r,
	sum(b.gba) sum_gba,
	count(p.*) frequency
from editor.poi_spb_no_duplic_for_test p
left join editor.classificator_1310_gba_v3_29_01_2021 b using(rubrics)
where
--	sde.st_intersects(shape, sde.st_transform(sde.st_multipolygon %WKT2%, 4326))
	gba is not null
--	and p.id_gis <= 1000
group by p.id_gis, b.CatRosStat
order by id_gis, regexp_replace(b.CatRosStat, '(\d+?)\.\s.*$', '\1')::int


--select distinct id_gis, count(*) from editor.poi_spb_no_duplic_for_test p group by id_gis



select * from editor.classificator_1310_gba_v3_29_01_2021




select (row_number() over())::int id, p.id_gis, b.CatRosStat, sum(b.gba) sum_gba, count(p.*) frequency
from sdekbvector.editor.poi_spb_NO_duplic_for_test p
left join sdekbvector.editor.classificator_1310_gba_v3_29_01_2021 b
using(rubrics)
where sde.st_intersects(shape, sde.st_transform(sde.st_multipolygon %WKT2%, 4326))
and gba is not null
group by p.id_gis, b.CatRosStat
order by id_gis, regexp_replace(b.CatRosStat, '(\d+?)\.\s.*$', '\1')::int