/* Зонинг. Статистика по POI на гексагональной сетке */
/* Время расчёта ~ 1 час */
drop table if exists zoning_pop; 
create temp table zoning_pop as
	select
		g.id::int,
		g.id_gis::smallint,
		coalesce(count(p.id), 0)::smallint as z1_pop,
		coalesce(sum(p.population), 0)::int as pop,
		g.area_ha,
		g.geom
	from index2020.data_hexgrid g
	left join index2020.data_pop_altermag p
		on st_intersects(p.geom, g.geom)
			and p.id_gis = g.id_gis
--	where g.id_gis <= 10 -- для дебага	
	group by g.id, g.geom;
create index on zoning_pop(id_gis);
create index on zoning_pop using gist(geom);
;
drop table if exists index2020.stat_zoning; 
create table index2020.stat_zoning as
	select
		g.*,
		coalesce(count(p.id) filter(where p.sdz is true and p.mall is false), 0)::smallint as z2_sdz,
		coalesce(count(p.id) filter(where p.odz is true and p.mall is false), 0)::smallint as z3_odz,
		coalesce(round(((count(p.id) filter(where p.odz is true and p.mall is false)/* z3 */)::numeric / nullif(g.z1_pop/* z1 */ + (count(p.id) filter(where p.sdz is true and p.mall is false))/* z2 */ + count(p.id) filter(where p.odz is true and p.mall is false)/* z3 */, 0)), 4), 0) as mu_odz,
		coalesce(count(distinct p.subrubrics) filter(where p.mall is false), 0)::smallint as sbrbr_count
	from zoning_pop g
	left join index2020.data_poi p
		on st_intersects(p.geom, g.geom)
			and p.id_gis = g.id_gis
	group by g.id, g.id_gis, g.z1_pop, g.pop, g.area_ha, g.geom
;
/* Индексы */
alter table index2020.stat_zoning add primary key(id);
create index on index2020.stat_zoning (id_gis);
create index on index2020.stat_zoning (pop);
create index on index2020.stat_zoning (z1_pop);
create index on index2020.stat_zoning (z2_sdz);
create index on index2020.stat_zoning (z3_odz);
create index on index2020.stat_zoning (mu_odz);
create index on index2020.stat_zoning (sbrbr_count);
create index on index2020.stat_zoning (area_ha);
--cluster index2020.stat_zoning using stat_zoning_id_gis_idx
;
/* Комментарии */
comment on table index2020.stat_zoning is 'Зонинг. Статистика по POI на гексагональной сетке';
comment on column index2020.stat_zoning.id is 'Уникальный идентификатор ячейки сетки';
comment on column index2020.stat_zoning.id_gis is 'Уникальный идентификатор города';
comment on column index2020.stat_zoning.pop is 'Суммарное число жителей в ячейке';
comment on column index2020.stat_zoning.z1_pop is 'Количество точек Альтермага в ячейке';
comment on column index2020.stat_zoning.z2_sdz is 'Количество объектов социально-досуговой инфраструктуры в ячейки';
comment on column index2020.stat_zoning.z3_odz is 'Количество объектов общественно-делового назначения в ячейки';
comment on column index2020.stat_zoning.mu_odz is 'Доля общественно-деловой функции в ячейке';
comment on column index2020.stat_zoning.sbrbr_count is 'Разнообразие сабрубрик в ячейке';
comment on column index2020.stat_zoning.area_ha is 'Площадь ячейки';




