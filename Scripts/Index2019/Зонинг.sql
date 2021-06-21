/* Зонинг. Статистика по POI на гексагональной сетке */
/* Время расчёта ~ 3 часа */
drop materialized view if exists index2019.stat_zoning cascade; 
create materialized view index2019.stat_zoning as
with zoning_pop as (
	select
		g.id,
		coalesce(sum(p.population), 0) as sum_pop,
		coalesce(count(p.id), 0) as count_pop
	from index2019.data_hexgrid g
	join index2019.data_pop_altermag p
		on st_intersects(p.geom, g.geom)
			and p.id_gis = g.id_gis
--			and g.id_gis < 30 -- для дебага	
	group by g.id
),

zoning_sdz as (
	select
		g.id,
		coalesce(count(p.id), 0) as sdz
	from index2019.data_hexgrid g
	join index2019.data_poi p
		on st_intersects(p.geom, g.geom)
			and p.id_gis = g.id_gis
			and p.sdz is true
			and p.mall is false
--			and g.id_gis < 30 -- для дебага	
	group by g.id
),

zoning_odz as (
	select
		g.id,
		coalesce(count(p.id), 0) as odz
	from index2019.data_hexgrid g
	join index2019.data_poi p
		on st_intersects(p.geom, g.geom)
			and p.id_gis = g.id_gis
			and p.odz is true
			and p.mall is false
--			and g.id_gis < 30 -- для дебага	
	group by g.id
),

sbrbr_count as (
	select
		g.id,
		count(distinct p.subrubrics) as count
	from index2019.data_hexgrid g
	join index2019.data_poi p 
		on st_intersects(p.geom, g.geom)
			and p.id_gis = g.id_gis
			and p.mall is false
--			and g.id_gis < 30 -- для дебага	
	group by g.id
)

select
	g.id::int,
	g.id_gis::smallint,
	coalesce(z1.sum_pop, 0)::int as pop,
	coalesce(z1.count_pop, 0)::smallint as z1_pop,
	coalesce(z2.sdz, 0)::smallint as z2_sdz,
	coalesce(z3.odz, 0)::smallint as z3_odz,
	coalesce(round((z3.odz::numeric / (coalesce(z1.count_pop,0) + coalesce(z2.sdz,0) + z3.odz)), 4), 0) as mu_odz,
	coalesce(sb.count, 0)::smallint as sbrbr_count,
	g.area_ha
from index2019.data_hexgrid g
left join zoning_pop z1 using(id)
left join zoning_sdz z2 using(id)
left join zoning_odz z3 using(id)
left join sbrbr_count sb using(id)
--where g.id_gis < 30 -- для дебага	
;

/* Индексы */
create unique index on index2019.stat_zoning (id);
create index on index2019.stat_zoning (id_gis);
create index on index2019.stat_zoning (pop);
create index on index2019.stat_zoning (z1_pop);
create index on index2019.stat_zoning (z2_sdz);
create index on index2019.stat_zoning (z3_odz);
create index on index2019.stat_zoning (mu_odz);
create index on index2019.stat_zoning (sbrbr_count);
create index on index2019.stat_zoning (area_ha);
cluster index2019.stat_zoning using stat_zoning_id_gis_idx;

/* Комментарии */
comment on materialized view index2019.stat_zoning is 'Зонинг. Статистика по POI на гексагональной сетке';
comment on column index2019.stat_zoning.id is 'Уникальный идентификатор ячейки сетки';
comment on column index2019.stat_zoning.id_gis is 'Уникальный идентификатор города';
comment on column index2019.stat_zoning.pop is 'Суммарное число жителей в ячейке';
comment on column index2019.stat_zoning.z1_pop is 'Количество точек Альтермага в ячейке';
comment on column index2019.stat_zoning.z2_sdz is 'Количество объектов социально-досуговой инфраструктуры в ячейки';
comment on column index2019.stat_zoning.z3_odz is 'Количество объектов общественно-делового назначения в ячейки';
comment on column index2019.stat_zoning.mu_odz is 'Доля общественно-деловой функции в ячейке';
comment on column index2019.stat_zoning.sbrbr_count is 'Разнообразие сабрубрик в ячейке';
comment on column index2019.stat_zoning.area_ha is 'Площадь ячейки';