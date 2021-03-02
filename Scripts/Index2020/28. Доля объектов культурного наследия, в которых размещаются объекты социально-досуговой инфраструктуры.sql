
/* 28-� ���������. ���� �������� ����������� ��������, */
/* � ������� ����������� ������� ���������-��������� �������������� */
/* to do: ��������� �� ������������� ������ 2020!!! */
/* ����� ������� ~ 15 ���.  */

/* ������������ ����������� ���������� */
/* ���������� ����������  */
create index on index2020.data_okn(nativename);
drop table if exists okn_filtered;
create temp table okn_filtered as (
	select
		id,
		id_gis,
		nativename,
		geom
	from index2020.data_okn
	where nativename !~* '�����|������| ����+�|�������|��������|����|�������|�����|����|�����|������|����|��������|���������|�����|�����|��������|����|����|������|�������'
		or (nativename ~* '�����|���|�����|�������|�����|��������|������|������|�����|��������|����|�������'
			and nativename !~* '��������|���������|�����|�����|��������|����|����|������|�������')
);
create index on okn_filtered using gist(geom);
create index on okn_filtered using gist((geom::geography));
create index on okn_filtered(id_gis);

/* ������� ���������� � ������ �� OpenStreetMap */
drop table if exists osm_okn;
create temp table osm_okn as (
	select distinct on (o.geom)
		o.id,
		o.nativename,
		o.id_gis,
--		st_collect(o.geom, b.geom), -- ��� ������
		o.geom okn_geom,
		b.geom osm_geom	
	from okn_filtered o
	join lateral (
		select b.geom
		from index2019.data_building b
		where o.id_gis = b.id_gis
			and st_dwithin(o.geom::geography, b.geom::geography, 5)
		order by o.geom::geography <-> b.geom::geography
		limit 1
	) b on true
--	where o.id_gis < 10 -- ��� ������
);
create index on osm_okn using gist(osm_geom);
create index on osm_okn using gist((osm_geom::geography));
create index on osm_okn using gist((st_centroid(osm_geom)::geography));
create index on osm_okn(id_gis);

/* ������� ����������� �������� � ���������-��������� POI �� ������� */
drop table if exists index2020.viz_i28;
create table index2020.viz_i28 as 
select
	o.id,
	o.nativename,
	o.id_gis,
	p.id sdz_id,
	p.name sdz_name,
--	st_collect(st_collect(o.okn_geom, o.osm_geom), p.geom), -- ��� ������
--	o.okn_geom,
--	p.geom sdz_geom,
	o.osm_geom
from osm_okn o
join lateral (
	select p.id, p.name, p.geom
	from index2020.data_poi p
	where o.id_gis = p.id_gis
--		and p.sdz is true -- ��� ����������� ������� ���������� ��� ������ ���� ����������������. �� ��������� �������������� ����������� ��� ���������� ��������������� �����������
		and st_dwithin(o.osm_geom::geography, p.geom::geography, 5)
	order by p.geom::geography <-> (st_centroid(o.osm_geom))::geography
	limit 1
) p on true;


/* �������  */
alter table index2020.viz_i28 add primary key(id);
create index on index2020.viz_i28(id_gis);
--create index on index2020.viz_i28 using gist(okn_geom);
create index on index2020.viz_i28 using gist(osm_geom);
--create index on index2020.viz_i28 using gist(sdz_geom);

/* ����������� */
comment on table index2020.viz_i28 is '���� �������� ����������� ��������, � ������� ����������� ������� ���������-��������� ��������������. 28-� ���������.';
comment on column index2020.viz_i28.id is '���������� ������������� ������� ����������� ��������';
comment on column index2020.viz_i28.nativename is '����������� �������� ������� ����������� ��������';
comment on column index2020.viz_i28.id_gis is '���������� ������������� ������';
comment on column index2020.viz_i28.sdz_id is '���������� ������������� ������� ���������-��������� ��������������';
comment on column index2020.viz_i28.sdz_name is '�������� ������� ���������-��������� ��������������';
--comment on column index2020.viz_i28.okn_geom is '��������� ������� ����������� ��������';
comment on column index2020.viz_i28.osm_geom is '��������� ������ �� OpenStreetMap � ������� ���������������� ��������� ������ ����������� ��������';
--comment on column index2020.viz_i28.sdz_geom is '��������� ������� ���������-��������� ��������������';


/* ������� ����� ���������� � ������ ������ ����� � � �����������  */
drop table  if exists index2020.ind_i28;
create table index2020.ind_i28 as
select
	b.id_gis,
	b.city,
	b.region_name,
	coalesce(o.count, 0) okn_total,
	coalesce(f.count, 0) okn_filtered,
	coalesce(m.count, 0) okn_matching_sdz,
	coalesce(round((m.count * 100 / o.count::numeric), 2), 0) okn_poi_percent_all,
	coalesce(round((m.count * 100 / f.count::numeric), 2), 0) okn_poi_percent_filtered
from index2020.data_boundary b
left join (select id_gis, count(*) from index2020.data_okn group by id_gis) o using(id_gis)
left join (select id_gis, count(*) from okn_filtered group by id_gis) f using(id_gis)
left join (select id_gis, count(*) from index2020.viz_i28 group by id_gis) m using(id_gis);

/* �������  */
alter table index2020.ind_i28 add primary key(id_gis);


/* ����������� */
comment on table index2020.ind_i28 is '���� �������� ����������� ��������. 28-� ���������? � ������� ����������� ������� ���������-��������� ��������������.';
comment on column index2020.ind_i28.id_gis is '���������� ������������� ������';
comment on column index2020.ind_i28.city is '�����';
comment on column index2020.ind_i28.region_name is '������� ��';
comment on column index2020.ind_i28.okn_total is '����� �������� ����������� �������� � ������';
comment on column index2020.ind_i28.okn_filtered is '����� �������� ����������� �������� � ������ ����� ���������� �� �������� "�� ������"';
comment on column index2020.ind_i28.okn_matching_sdz is '����� �������� ����������� �������� � ������� ����������� ������� ���������-��������� ��������������';
comment on column index2020.ind_i28.okn_poi_percent_all is
'������� �������� ����������� �������� � ������� ����������� ������� ���������-��������� �������������� �� ������ ����� �������� ����������� �������� � ������';
comment on column index2020.ind_i28.okn_poi_percent_filtered is
'������� �������� ����������� �������� � ������� ����������� ������� ���������-��������� �������������� �� ������ ����� �������� ����������� �������� � ������ ����� ����������';


/* �������� */
/* ��������� � 2019 �����. */
drop table if exists index2020.comp_i28;
create table index2020.comp_i28 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region_name,
	coalesce(i2.okn_matching_sdz, 0) okn_matching_sdz_2019,
	coalesce(i1.okn_matching_sdz, 0) okn_matching_sdz_2020,
	coalesce(i2.okn_total, 0) okn_total_2019,
	coalesce(i1.okn_total, 0) okn_total_2020,
	coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0) okn_poi_percent_all_2019,
	coalesce(i1.okn_poi_percent_all, 0) okn_poi_percent_all_2020,
	(case 
		when coalesce(i1.okn_poi_percent_all, 0) > coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0)
			then 2020
	 	when coalesce(i1.okn_poi_percent_all, 0) = coalesce(round((i2.okn_poi_percent_all)::numeric, 2), 0)
			then null
		else 2019
	end)::smallint higher_value -- � ����� ���� ���������� ����
from index2020.ind_i28 i1
left join index2019.ind_i28_v2 i2 using(id_gis)
order by id_gis;

/* ����������� */
comment on table index2020.comp_i28 is '��������� � 2018 �����. 28-� ���������. ���� �������� ����������� ��������, � ������� ����������� ������� ���������-��������� ��������������.';
comment on column index2020.comp_i28.id_gis is '���������� ������������� ������';
comment on column index2020.comp_i28.city is '�����';
comment on column index2020.comp_i28.region_name is '������� ��';
comment on column index2020.comp_i28.okn_matching_sdz_2020 is '������� ����������� ��������, � ������� ����������� ������� ���������-��������� �������������� � 2020 �., ��.';
comment on column index2020.comp_i28.okn_matching_sdz_2019 is '������� ����������� ��������, � ������� ����������� ������� ���������-��������� �������������� � 2019 �., ��.';
comment on column index2020.comp_i28.okn_total_2020 is '����������� �������� ����������� �������� � ������ � 2020 �., ��.';
comment on column index2020.comp_i28.okn_total_2019 is '����������� �������� ����������� �������� � ������ � 2019 �., ��.';
comment on column index2020.comp_i28.okn_poi_percent_all_2020 is '���� �������� ����������� ��������, � ������� ����������� ������� ���������-��������� �������������� � 2020 �.';
comment on column index2020.comp_i28.okn_poi_percent_all_2019 is '���� �������� ����������� ��������, � ������� ����������� ������� ���������-��������� �������������� � 2019 �.';
comment on column index2020.comp_i28.higher_value is '� ����� ���� ���������� "���� �������� ����������� ��������, � ������� ����������� ������� ���������-��������� ��������������" ����';



/* ����� � Excel */
select 
	id_gis "id_gis ������",
	city "�����",
	region_name "������� ��",
	okn_matching_sdz_2019 "��� + ��� 2019",
	okn_matching_sdz_2020 "��� + ��� 2020",
	okn_total_2019 "����� ��� 2019",
	okn_total_2020 "����� ��� 2020",
	okn_poi_percent_all_2019 "% ��� + ��� 2019",
	okn_poi_percent_all_2020 "% ��� + ��� 2020",
	case when higher_value is null then '�������' else higher_value::text end "� ����� ���� ������"
from index2020.comp_i28;