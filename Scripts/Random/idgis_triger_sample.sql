--create table delivery.velo_infrastructure (
--	id int primary key generated always as identity,
--	name text,
--	comment text,
--	geom geometry(multilinestring, 4326) not null
--);

--alter table delivery.velo_infrastructure 
--	add column id_gis smallint,
--	add constraint fk_id_gis
--	foreign key(id_gis)
--	references russia.city(id_gis);

/* Функция вставляет id_gis города при записи в таблицу */
create or replace function insert_idgis()
	returns trigger as
		$$
			begin 
				new.id_gis = (
					select c.id_gis
					from russia.city c
					where st_intersects(new.geom, c.geom)
				);
			return new;
			end;
		$$
	language 'plpgsql'
;

drop trigger if exists insert_idgis_trigger
	on delivery.velo_infrastructure;

create trigger insert_idgis_trigger
before insert or update on delivery.velo_infrastructure
	for each row
		execute procedure insert_idgis();
