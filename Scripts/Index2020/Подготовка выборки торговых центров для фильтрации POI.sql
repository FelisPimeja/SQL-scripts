/* ���������� ���� � ��������� �������� �� ������ ������� � ��������� ������ �� OpenStreetMap */
/* ����� ���������� ~ 2 ���. */
drop table if exists index2020.data_mall;
create table index2020.data_mall as
select distinct on(b.id) b.*
from russia.poi_yandex_2020 p
join index2020.data_building b
	on st_intersects(b.geom, p.geom)
where p.category_name like '%�������� �����%'
;
/* ������� � ��������� ���� */
alter table index2020.data_mall add primary key(id);
create index on index2020.data_mall(id_gis);
create index on index2020.data_mall using gist(geom);
create index on index2020.data_mall using gist((geom::geography))
;
/* ����������� */
comment on table index2020.data_mall is
'�������� ������ � �������� ������� ��.
��������� -  OpenStreetMap, ������.
������������ - ���� 2021 �.';
