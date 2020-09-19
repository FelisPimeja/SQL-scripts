/* Traffic data matching */
-- To do:
-- 1. Добавить потом комментарии к колонкам

alter table traffic.google_initial
	add column road_segment_id int;

alter table traffic.google_initial
	add column dist_to_road_m int;

/* Матчинг */
update traffic.google_initial i
	set
		road_segment_id = r.road_segment_id,
		dist_to_road_m = r.dist_to_road_m 
	from (
		select
			i.id,
			r.id road_segment_id,
			st_distance(i.geom::geography, r.geom::geography)::int dist_to_road_m,
			i.geom
		from traffic.google_initial i
		left join lateral (
			select r.id, r.geom
			from traffic.city_road_rebuild r
			where st_dwithin(i.geom::geography, r.geom::geography, 15)
			order by i.geom::geography <-> r.geom::geography
			limit 1
		) r on true
	) r
;