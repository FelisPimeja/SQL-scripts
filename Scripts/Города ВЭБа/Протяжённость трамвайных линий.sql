/* Статистика по депо и протяжённости трамвайных линий в городах ВЭБа  */
-- По итогу, данные правились руками по Википедии. Достоверность по протяжённости путей нормальная, а по депо - так "себе"
drop table if exists city;
create temp table city as 
select b.* from russia.city_boundary b join veb_rf.city c using(id_gis);
create index on city using gist(geom);

drop table if exists tram_line;
create temp table tram_line as 
select
	b.id_gis,
	b.city,
	b.region_name,
	coalesce(round((sum(st_length(t.geom::geography)) / 1000)::numeric, 2), 0) tram_lines_length_km
from city b
left join osm.railroads_ru t
	on t.type =  'tram'
	and st_intersects(b.geom, t.geom)
group by b.id_gis, b.city, b.region_name
order by tram_lines_length_km desc;

drop table if exists tram_depot;
create temp table tram_depot as
select count(t.*) depot_count, b.id_gis
from (select *, exist(other_tags, 'depot:vehicle:tram') tram from osm_test.depot) t
join city b
	on st_intersects(b.geom, t.geom)
where t.tram is true
group by b.id_gis;

drop table if exists veb_rf.tram_stat;
create table veb_rf.tram_stat as
select
	b.id_gis,
	b.city,
	b.region_name,
	tl.tram_lines_length_km,
	td.depot_count
from city b
left join tram_line tl using(id_gis)
left join tram_depot td using(id_gis)
order by tram_lines_length_km desc;


-- Запросик для Excel
select
	b.id_gis,
	b.city "Город",
	b.region_name "Субъект РФ",
	tl.tram_lines_length_km "Протяжённость трамвайной сети",
	td.depot_count "Количество трамвайных депо"
from veb_rf.tram_stat;
	



