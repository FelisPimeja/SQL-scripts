alter table traffic.google_initial
	drop column "path";

update traffic.google_initial
	set layer = substring(layer, 4, length(layer))

select layer, substring(layer, 4, length(layer)) from traffic.google_initial limit 100

create index on traffic.google_initial using gist(geom);
create index on traffic.google_initial using gist((geom::geography));

create temp table tmp as select * from traffic.google_initial limit 100;
update tmp
	set layer = substring(layer, 4, length(layer));

select * from tmp;