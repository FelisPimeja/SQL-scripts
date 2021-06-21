/* Минимальная статистика по границам городов */
drop table if exists index2020.stat_boundary;
create table index2020.stat_boundary as 
	select
		b1.id_gis,
		b1.city,
		b1.region,
		coalesce(round(st_area(b2.geom::geography, true)::numeric / 10000, 2), 0) area_2019_ha,
		round(st_area(b1.geom::geography, true)::numeric / 10000, 2) area_2020_ha,
		coalesce(round(100 - ((st_area(b1.geom::geography, true)::numeric / 10000) / (st_area(b2.geom::geography)::numeric / 10000)::numeric * 100)::numeric, 2), 100) area_dif_perc,
		coalesce(round(st_perimeter(b2.geom::geography, true)::numeric / 1000, 2), 0) perimeter_2019_km,
		round(st_perimeter(b1.geom::geography, true)::numeric / 1000, 2) perimeter_2020_km,
		coalesce(round(100 - ((st_perimeter(b1.geom::geography, true)::numeric) / (st_perimeter(b2.geom::geography)::numeric)::numeric * 100)::numeric, 2), 100) perimeter_dif_perc
	from index2020.data_boundary b1
	left join index2019.data_boundary b2 using(id_gis)
;

alter table index2020.stat_boundary add primary key(id_gis);

/* Комментарии */
comment on table index2020.stat_boundary is 'Минимальная статистика по границам городов.';
comment on column index2020.stat_boundary.id_gis is 'id_gis города';
comment on column index2020.stat_boundary.city is 'Город';
comment on column index2020.stat_boundary.region is 'Субъект РФ';
comment on column index2020.stat_boundary.area_2019_ha is 'Площадь города в границах на 2019 г., га';
comment on column index2020.stat_boundary.area_2020_ha is 'Площадь города в границах на 2020 г., га';
comment on column index2020.stat_boundary.area_dif_perc is 'Разница площадей 2019-2020 гг., %';
comment on column index2020.stat_boundary.perimeter_2019_km is 'Периметр границы города на 2019 г., км';
comment on column index2020.stat_boundary.perimeter_2020_km is 'Периметр границы города на 2020 г., км';
comment on column index2020.stat_boundary.perimeter_dif_perc is 'Разница периметров 2019-2020 гг., %';