-- Обработка первых "сырых" точек google traffic после загрузки в базу

alter table traffic.google_initial
	drop column "path";

update traffic.google_initial
	set layer = substring(layer, 4, length(layer));

alter table traffic.google_initial
	alter column layer type smallint;

alter table traffic.google_initial
	rename column layer to cell_id;
	
create index on traffic.google_initial using gist(geom);
create index on traffic.google_initial using gist((geom::geography));

alter table traffic.google_initial
	rename column "VALUE" to "value";

create index on traffic.google_initial(value);

alter table russia.rect_grid_tmp
	set schema traffic;

alter table traffic.rect_grid_tmp rename to grid_russia;

alter table russia.rect_grid
	set schema traffic;

alter table traffic.rect_grid rename to grid_russia_city;

alter table traffic.grid_russia_city
	add column google_traffic bool default false;

update traffic.grid_russia_city
	set google_traffic = true 
	where id in (select distinct cell_id from traffic.google_initial);

select count(*) from traffic.grid_russia_city --where google_traffic is true