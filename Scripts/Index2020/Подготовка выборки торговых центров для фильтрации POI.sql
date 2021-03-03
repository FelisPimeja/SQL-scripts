/* Подготовка слоя с торговыми центрами по точкам Яндекса и полигонам зданий из OpenStreetMap */
/* Время выполнения ~ 2 мин. */
drop table if exists index2020.data_mall;
create table index2020.data_mall as
select distinct on(b.id) b.*
from russia.poi_yandex_2020 p
join index2020.data_building b
	on st_intersects(b.geom, p.geom)
where p.category_name like '%Торговый центр%'
;
/* Индексы и первичный ключ */
alter table index2020.data_mall add primary key(id);
create index on index2020.data_mall(id_gis);
create index on index2020.data_mall using gist(geom);
create index on index2020.data_mall using gist((geom::geography))
;
/* Комментарии */
comment on table index2020.data_mall is
'Торговые центры в границах городов РФ.
Источники -  OpenStreetMap, Яндекс.
Актуальность - март 2021 г.';
