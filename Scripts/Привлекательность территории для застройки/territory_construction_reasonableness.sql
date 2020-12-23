drop table if exists dens_grid;
create temp table dens_grid as
with density as (
	select
		g.id,
		g.id_gis,
		g.area_ha,
		coalesce(round(((sum(st_area(st_intersection(g.geom, b.geom)::geography) * case when b.levels is null then 1 else b.levels end) / 1000 / nullif(g.area_ha, 0)) * 0.95)::numeric, 2), 0) build_density_1km2_ha,
		g.geom
	from index2019.data_hexgrid g
	left join street_classify.building_classify_2_pass b
		on b.id_gis = g.id_gis 
			and st_intersects(g.geom, b.geom)
	where g.id_gis = 1083
	group by 
		g.id,
		g.id_gis,
		g.area_ha,
		g.geom
),
ipa_ita as (
	select
		g.id,
		g.id_gis,
		max(
			case
				when i."BTWNS7000_NORM" > 1 then 3::smallint
				when i."BTWNS7000_NORM" between 0.1 and 1 then 2::smallint
				else 1::smallint
			end
		) ita,
		max(
			case
				when i."IPA800" > 1 then 3::smallint
				when i."IPA800" between 0.1 and 1 then 2::smallint
				else 1::smallint
			end
		) ipa
	from index2019.data_hexgrid g
	left join tmp.tmp_1083_ita_ipa i
		on st_intersects(g.geom, i.geom)
--			and i.id_gis = g.id_gis 			
	where g.id_gis = 1083
	group by 
		g.id,
		g.id_gis,
		g.area_ha,
		g.geom
)
select
	d.*,
	case 
		when build_density_1km2_ha < 0.6 then 'Свободный'
		when build_density_1km2_ha between 0.6 and 5 then 'Низкая плотность'
		when build_density_1km2_ha between 5.01 and 10 then 'Средняя плотность'
		when build_density_1km2_ha > 10 then 'Высокая плотность'
	end build_density_class,
	case 
		when build_density_1km2_ha between 0.6 and 1 then '1 Дачная городская среда'
		when build_density_1km2_ha between 1.01 and 2 then '2 Сельская городская среда'
		when build_density_1km2_ha between 2.01 and 4 then '3 Историческая индивидуальная городская среда'
--		when build_density_1km2_ha between 4 and 5 then '4 Современная индивидуальная городская среда' 4
		when build_density_1km2_ha between 4.01 and 5 then '5 Советская малоэтажная разреженная городская среда'
		when build_density_1km2_ha between 5.01 and 7 then '6 Современная блокированная городская среда'
		when build_density_1km2_ha between 7.01 and 8 then '7 Советская малоэтажная периметральная городская среда'
		when build_density_1km2_ha between 8.01 and 10 then '8 Историческая разреженная городская среда'
--		when build_density_1km2_ha between 1.01 and 5 then '9 Советская среднеэтажная микрорайонная городская среда' 8
		when build_density_1km2_ha between 10.01 and 13 then '10 Современная малоэтажная городская среда'
		when build_density_1km2_ha between 13.01 and 14 then '11 Историческая периметральная городская среда'
		when build_density_1km2_ha between 14.01 and 15 then '12 Советская малоэтажная микрорайонная городская среда'
		when build_density_1km2_ha between 15.01 and 23 then '13 Советская среднеэтажная периметральная городская среда'
		when build_density_1km2_ha > 23 then '14 Современная многоэтажная городская среда'
	end build_density_type,
	case 
		when build_density_1km2_ha < 0.6 then 0::smallint
		when build_density_1km2_ha between 0.6 and 5 then 1::smallint
		when build_density_1km2_ha between 5.01 and 10 then 2::smallint
		when build_density_1km2_ha > 10 then 3::smallint
	end build_density_score,
	i.ipa,
	i.ita,
	case
		when build_density_1km2_ha < 0.6
			then ceil((0.7 * i.ita + 0.3 * i.ipa)::numeric)
		else ceil((0.5 * i.ita + 0.5 * i.ipa)::numeric)
	end sum_ipa_ita
from density d
left join ipa_ita i using(id)
;
create index on dens_grid using gist(geom);
create index on dens_grid using gist((geom::geography));
create index on dens_grid(build_density_1km2_ha);
create index on dens_grid(sum_ipa_ita);
drop table if exists tmp.tmp_1083_density_grid;
create table tmp.tmp_1083_density_grid as
select
	d1.*,
	case 
		when d1.build_density_1km2_ha < 0.6 and d1.sum_ipa_ita >= 2 then 'Высокопривлекательная'
		when d1.build_density_1km2_ha < 0.6 and d1.sum_ipa_ita < 2 and count(d2.id) > 0 is not null then 'Среднепривлекательная'
		when d1.build_density_1km2_ha < 0.6 and d1.sum_ipa_ita < 2 and count(d2.id) > 0 is null then 'Низкопривлекательная'
		
		when d1.build_density_1km2_ha between 0.6 and 5 and d1.sum_ipa_ita = 3 then 'Высокопривлекательная'
		when d1.build_density_1km2_ha between 0.6 and 5 and d1.sum_ipa_ita = 2 then 'Среднепривлекательная'
		when d1.build_density_1km2_ha between 5.01 and 10 and d1.sum_ipa_ita = 3 then 'Среднепривлекательная'
		else 'Низкопривлекательная'
	end priority
from dens_grid d1
left join dens_grid d2
	on st_dwithin(d1.geom::geography, d2.geom::geography, 420)
		and d2.sum_ipa_ita >= 2
		and d1.id <> d2.id
group by
	d1.id,
	d1.id_gis,
	d1.area_ha,
	d1.build_density_1km2_ha,
	d1.geom,
	d1.build_density_class,
	d1.build_density_type,
	d1.build_density_score,
	d1.ipa,
	d1.ita,
	d1.sum_ipa_ita
;
create index on tmp.tmp_1083_density_grid using gist(geom);
create index on tmp.tmp_1083_density_grid(build_density_1km2_ha);
create index on tmp.tmp_1083_density_grid(build_density_class);
create index on tmp.tmp_1083_density_grid(build_density_type);
create index on tmp.tmp_1083_density_grid(build_density_score);
create index on tmp.tmp_1083_density_grid(ipa);
create index on tmp.tmp_1083_density_grid(ita);
create index on tmp.tmp_1083_density_grid(sum_ipa_ita);
create index on tmp.tmp_1083_density_grid(priority);

--create index on tmp.tmp_1083_ita_ipa using gist(geom);
--alter table tmp.tmp_1083_ita_ipa
--	alter column geom type geometry(multilinestring, 4326) using st_transform(geom, 4326);
