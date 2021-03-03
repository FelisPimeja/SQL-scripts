/* 26-� ���������. ������������ ���������-��������� � ���������� �������������� */
/* ����� ������� ~ 5 ���. */
drop table if exists index2020.ind_i26; 
create table index2020.ind_i26 as
with subrubrics_count as (
	 select id_gis, subrubrics,	count(*) poi_count
	 from index2020.data_poi
	 where leisurez is true
--		and id_gis < 100 -- ��� ������
	 group by id_gis, subrubrics
)
select
	b.id_gis,
	b.city,
	b.region,
	coalesce(round(((sum((a.poi_count - avr)^2) / count(a.subr_count))^0.5 / min(avr)::numeric), 4), 0.0000) sport_diversity
from index2020.data_boundary b
join (
	 select 
		 id_gis, 
		 poi_count,
		 sum(poi_count) over (partition by id_gis) subr_count,
		 count(subrubrics) over (partition by id_gis) total_poi,
		 sum(poi_count) over (partition by id_gis)/count(subrubrics) over (partition by id_gis) avr
	 from subrubrics_count) a using(id_gis)
group by b.id_gis, b.city, b.region
order by id_gis;

/* ������� */
alter table index2020.ind_i26 add primary key(id_gis)
;
/* ����������� */
comment on table index2020.ind_i26 is '26-� ���������. ������������ ���������-��������� � ���������� ��������������';
comment on column index2020.ind_i26.id_gis is '���������� ������������� ������';
comment on column index2020.ind_i26.city is '�����';
comment on column index2020.ind_i26.region is '������� ��';
comment on column index2020.ind_i26.sport_diversity is '���������� ������������ ���������-��������� � ���������� ��������������'
;
/* ������� ���������� �� ����������� */
drop table if exists index2020.stat_subrubrics; 
create table index2020.stat_subrubrics as
select 
	b.id_gis,
	b.city,
	b.region,
	subrbr.count "����� ��������� � ������",
    coalesce(sub1.count, 0) "�������� ����",
    coalesce(sub2.count, 0) "������ � ����������",
    coalesce(sub3.count, 0) "������� ������",
    coalesce(sub4.count, 0) "������ �����",
    coalesce(sub5.count, 0) "������ ���������",
    coalesce(sub6.count, 0) "�������� � �������������� �������",
    coalesce(sub7.count, 0) "����",
    coalesce(sub8.count, 0) "���� � �����",
    coalesce(sub9.count, 0) "������ �����",
    coalesce(sub10.count, 0) "���������� ������",
    coalesce(sub11.count, 0) "����� � ��������",
    coalesce(sub12.count, 0) "������ � �����������",
    coalesce(sub13.count, 0) "������������ �������",
    coalesce(sub14.count, 0) "����������� ����������",
    coalesce(sub15.count, 0) "����� � ��������",
    coalesce(sub16.count, 0) "������",
    coalesce(sub17.count, 0) "�����������",
    coalesce(sub18.count, 0) "��������� � ���� ������",
    coalesce(sub19.count, 0) "���������� ����� � ����",
    coalesce(sub20.count, 0) "���������� �����������",
    coalesce(sub21.count, 0) "���������� ����������",
    coalesce(sub22.count, 0) "������",
    coalesce(sub23.count, 0) "���� �� ����������",
    coalesce(sub24.count, 0) "������ � ����",
    coalesce(sub25.count, 0) "������������� �����"
from index2020.data_boundary b 
left join (select id_gis, count(distinct subrubrics) count from index2020.data_poi where subrubrics = any('{�������� ����,������ � ����������,������� ������,������ �����,������ ���������,�������� � �������������� �������,����,���� � �����,������ �����,���������� ������,����� � ��������,������ � �����������,������������ �������,����������� ����������,����� � ��������,������,�����������,��������� � ���� ������,���������� ����� � ����,���������� �����������,���������� ����������,������,���� �� ����������,������ � ����,������������� �����}')  group by id_gis) subrbr using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '�������� ����' group by id_gis) sub1 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������ � ����������' group by id_gis) sub2 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������� ������' group by id_gis) sub3 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������ �����' group by id_gis) sub4 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������ ���������' group by id_gis) sub5 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '�������� � �������������� �������' group by id_gis) sub6 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '����' group by id_gis) sub7 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '���� � �����' group by id_gis) sub8 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������ �����' group by id_gis) sub9 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '���������� ������' group by id_gis) sub10 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '����� � ��������' group by id_gis) sub11 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������ � �����������' group by id_gis) sub12 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������������ �������' group by id_gis) sub13 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '����������� ����������' group by id_gis) sub14 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '����� � ��������' group by id_gis) sub15 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������' group by id_gis) sub16 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '�����������' group by id_gis) sub17 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '��������� � ���� ������' group by id_gis) sub18 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '���������� ����� � ����' group by id_gis) sub19 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '���������� �����������' group by id_gis) sub20 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '���������� ����������' group by id_gis) sub21 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������' group by id_gis) sub22 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '���� �� ����������' group by id_gis) sub23 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������ � ����' group by id_gis) sub24 using(id_gis)
left join (select id_gis, count(*) count from index2020.data_poi where subrubrics = '������������� �����' group by id_gis) sub25 using(id_gis)
order by id_gis
;
/* ������� */
alter table index2020.stat_subrubrics add primary key(id_gis)
;
/* ����������� */
comment on table index2020.stat_subrubrics is '26-� ���������. ������� ���������� �� �����������';
comment on column index2020.stat_subrubrics.id_gis is '���������� ������������� ������';
comment on column index2020.stat_subrubrics.city is '�����';
comment on column index2020.stat_subrubrics.region is '������� ��';
comment on column index2020.stat_subrubrics."�������� ����" is '�������� ����';
comment on column index2020.stat_subrubrics."������ � ����������" is '������ � ����������';
comment on column index2020.stat_subrubrics."������� ������" is '������� ������';
comment on column index2020.stat_subrubrics."������ �����" is '������ �����';
comment on column index2020.stat_subrubrics."������ ���������" is '������ ���������';
comment on column index2020.stat_subrubrics."�������� � �������������� �������" is '�������� � �������������� �������';
comment on column index2020.stat_subrubrics."����" is '����';
comment on column index2020.stat_subrubrics."���� � �����" is '���� � �����';
comment on column index2020.stat_subrubrics."������ �����" is '������ �����';
comment on column index2020.stat_subrubrics."���������� ������" is '���������� ������';
comment on column index2020.stat_subrubrics."����� � ��������" is '����� � ��������';
comment on column index2020.stat_subrubrics."������ � �����������" is '������ � �����������';
comment on column index2020.stat_subrubrics."������������ �������" is '������������ �������';
comment on column index2020.stat_subrubrics."����������� ����������" is '����������� ����������';
comment on column index2020.stat_subrubrics."����� � ��������" is '����� � ��������';
comment on column index2020.stat_subrubrics."������" is '������';
comment on column index2020.stat_subrubrics."�����������" is '�����������';
comment on column index2020.stat_subrubrics."��������� � ���� ������" is '��������� � ���� ������';
comment on column index2020.stat_subrubrics."���������� ����� � ����" is '���������� ����� � ����';
comment on column index2020.stat_subrubrics."���������� �����������" is '���������� �����������';
comment on column index2020.stat_subrubrics."���������� ����������" is '���������� ����������';
comment on column index2020.stat_subrubrics."������" is '������';
comment on column index2020.stat_subrubrics."���� �� ����������" is '���� �� ����������';
comment on column index2020.stat_subrubrics."������ � ����" is '������ � ����';
comment on column index2020.stat_subrubrics."������������� �����" is '������������� �����'
;
/* �������� */
/* ��������� � 2019 �����. */
drop table if exists index2020.comp_i26;
create table index2020.comp_i26 as
select 
	i1.id_gis::smallint,
	i1.city,
	i1.region,
	coalesce(i2.sport_divercity, 0) sport_divercity_2019,
	coalesce(i1.sport_diversity, 0) sport_divercity_2020,
	(case 
		when coalesce(i1.sport_diversity, 0) > coalesce(round(i2.sport_divercity::numeric, 4), 0)
			then 2020
	 	when coalesce(i1.sport_diversity, 0) = coalesce(round(i2.sport_divercity::numeric, 4), 0)
			then null
		else 2019
	end)::smallint higher_value, -- � ����� ���� ���������� ����
	coalesce(i3."����� ��������� � ������", 0)::smallint "����� ��������� � ������_2019",
	coalesce(i4."����� ��������� � ������", 0)::smallint "����� ��������� � ������_2020",
	coalesce(i3."�������� ����", 0)::smallint "�������� ����_2019",
	coalesce(i4."�������� ����", 0)::smallint "�������� ����_2020",
	coalesce(i3."������ � ����������", 0)::smallint "������ � ����������_2019",
	coalesce(i4."������ � ����������", 0)::smallint "������ � ����������_2020",
	coalesce(i3."������� ������", 0)::smallint "������� ������_2019",
	coalesce(i4."������� ������", 0)::smallint "������� ������_2020",
	coalesce(i3."������ �����", 0)::smallint "������ �����_2019",
	coalesce(i4."������ �����", 0)::smallint "������ �����_2020",
	coalesce(i3."������ ���������", 0)::smallint "������ ���������_2019",
	coalesce(i4."������ ���������", 0)::smallint "������ ���������_2020",
	coalesce(i3."�������� � �������������� �������", 0)::smallint "�������� � �����. �������_2019",
	coalesce(i4."�������� � �������������� �������", 0)::smallint "�������� � �����. �������_2020",
	coalesce(i3."����", 0)::smallint "����_2019",
	coalesce(i4."����", 0)::smallint "����_2020",
	coalesce(i3."���� � �����", 0)::smallint "���� � �����_2019",
	coalesce(i4."���� � �����", 0)::smallint "���� � �����_2020",
	coalesce(i3."������ �����", 0)::smallint "������ �����_2019",
	coalesce(i4."������ �����", 0)::smallint "������ �����_2020",
	coalesce(i3."���������� ������", 0)::smallint "���������� ������_2019",
	coalesce(i4."���������� ������", 0)::smallint "���������� ������_2020",
	coalesce(i3."����� � ��������", 0)::smallint "����� � ��������_2019",
	coalesce(i4."����� � ��������", 0)::smallint "����� � ��������_2020",
	coalesce(i3."������ � �����������", 0)::smallint "������ � �����������_2019",
	coalesce(i4."������ � �����������", 0)::smallint "������ � �����������_2020",
	coalesce(i3."������������ �������", 0)::smallint "������������ �������_2019",
	coalesce(i4."������������ �������", 0)::smallint "������������ �������_2020",
	coalesce(i3."����������� ����������", 0)::smallint "����������� ����������_2019",
	coalesce(i4."����������� ����������", 0)::smallint "����������� ����������_2020",
	coalesce(i3."����� � ��������", 0)::smallint "����� � ��������_2019",
	coalesce(i4."����� � ��������", 0)::smallint "����� � ��������_2020",
	coalesce(i3."������", 0)::smallint "������_2019",
	coalesce(i4."������", 0)::smallint "������_2020",
	coalesce(i3."�����������", 0)::smallint "�����������_2019",
	coalesce(i4."�����������", 0)::smallint "�����������_2020",
	coalesce(i3."��������� � ���� ������", 0)::smallint "��������� � ���� ������_2019",
	coalesce(i4."��������� � ���� ������", 0)::smallint "��������� � ���� ������_2020",
	coalesce(i3."���������� ����� � ����", 0)::smallint "���������� ����� � ����_2019",
	coalesce(i4."���������� ����� � ����", 0)::smallint "���������� ����� � ����_2020",
	coalesce(i3."���������� �����������", 0)::smallint "���������� �����������_2019",
	coalesce(i4."���������� �����������", 0)::smallint "���������� �����������_2020",
	coalesce(i3."���������� ����������", 0)::smallint "���������� ����������_2019",
	coalesce(i4."���������� ����������", 0)::smallint "���������� ����������_2020",
	coalesce(i3."������", 0)::smallint "������_2019",
	coalesce(i4."������", 0)::smallint "������_2020",
	coalesce(i3."���� �� ����������", 0)::int "���� �� ����������_2019",
	coalesce(i4."���� �� ����������", 0)::int "���� �� ����������_2020",
	coalesce(i3."������ � ����", 0)::smallint "������ � ����_2019",
	coalesce(i4."������ � ����", 0)::smallint "������ � ����_2020",
	coalesce(i3."������������� �����", 0)::smallint "������������� �����_2019",
	coalesce(i4."������������� �����", 0)::smallint "������������� �����_2020"
from index2020.ind_i26 i1
left join index2019.ind_i26 i2 using(id_gis)
left join index2019.stat_subrubrics i3 using(id_gis)
left join index2020.stat_subrubrics i4 using(id_gis)
order by id_gis
;
/* ����������� */
comment on table index2020.comp_i26 is '��������� � 2019 �����. 26-� ���������. ������������ ���������-��������� � ���������� ��������������.';
comment on column index2020.comp_i26.id_gis is '���������� ������������� ������';
comment on column index2020.comp_i26.city is '�����';
comment on column index2020.comp_i26.region is '������� ��';
comment on column index2020.comp_i26.sport_divercity_2019 is '������������ ���������� �������������� �� 2019 ���';
comment on column index2020.comp_i26.sport_divercity_2020 is '������������ ���������� �������������� �� 2020 ���';
comment on column index2020.comp_i26.higher_value is '� ����� ���� ���������� "������������ ���������� ��������������" ����';
comment on column index2020.comp_i26."����� ��������� � ������_2019" is '���� ��������� � ������ �� 2019 ���';
comment on column index2020.comp_i26."����� ��������� � ������_2020" is '����� ��������� � ������ �� 2020 ���';
comment on column index2020.comp_i26."�������� ����_2019" is '�������� ���� �� 2019 ���';
comment on column index2020.comp_i26."�������� ����_2020" is '�������� ���� �� 2020 ���';
comment on column index2020.comp_i26."������ � ����������_2019" is '������ � ���������� �� 2019 ���';
comment on column index2020.comp_i26."������ � ����������_2020" is '������ � ���������� �� 2020 ���';
comment on column index2020.comp_i26."������� ������_2019" is '������� ������ �� 2019 ���';
comment on column index2020.comp_i26."������� ������_2020" is '������� ������ �� 2020 ���';
comment on column index2020.comp_i26."������ �����_2019" is '������ ����� �� 2019 ���';
comment on column index2020.comp_i26."������ �����_2020" is '������ ����� �� 2020 ���';
comment on column index2020.comp_i26."������ ���������_2019" is '������ ��������� �� 2019 ���';
comment on column index2020.comp_i26."������ ���������_2020" is '������ ��������� �� 2020 ���';
comment on column index2020.comp_i26."�������� � �����. �������_2019" is '�������� � �������������� ������� �� 2019 ���';
comment on column index2020.comp_i26."�������� � �����. �������_2020" is '�������� � �������������� ������� �� 2020 ���';
comment on column index2020.comp_i26."����_2019" is '���� �� 2019 ���';
comment on column index2020.comp_i26."����_2020" is '���� �� 2020 ���';
comment on column index2020.comp_i26."���� � �����_2019" is '���� � ����� �� 2019 ���';
comment on column index2020.comp_i26."���� � �����_2020" is '���� � ����� �� 2020 ���';
comment on column index2020.comp_i26."������ �����_2019" is '������ ����� �� 2019 ���';
comment on column index2020.comp_i26."������ �����_2020" is '������ ����� �� 2020 ���';
comment on column index2020.comp_i26."���������� ������_2019" is '���������� ������ �� 2019 ���';
comment on column index2020.comp_i26."���������� ������_2020" is '���������� ������ �� 2020 ���';
comment on column index2020.comp_i26."����� � ��������_2019" is '����� � �������� �� 2019 ���';
comment on column index2020.comp_i26."����� � ��������_2020" is '����� � �������� �� 2020 ���';
comment on column index2020.comp_i26."������ � �����������_2019" is '������ � ����������� �� 2019 ���';
comment on column index2020.comp_i26."������ � �����������_2020" is '������ � ����������� �� 2020 ���';
comment on column index2020.comp_i26."������������ �������_2019" is '������������ ������� �� 2019 ���';
comment on column index2020.comp_i26."������������ �������_2020" is '������������ ������� �� 2020 ���';
comment on column index2020.comp_i26."����������� ����������_2019" is '����������� ���������� �� 2019 ���';
comment on column index2020.comp_i26."����������� ����������_2020" is '����������� ���������� �� 2020 ���';
comment on column index2020.comp_i26."����� � ��������_2019" is '����� � �������� �� 2019 ���';
comment on column index2020.comp_i26."����� � ��������_2020" is '����� � �������� �� 2020 ���';
comment on column index2020.comp_i26."������_2019" is '������ �� 2019 ���';
comment on column index2020.comp_i26."������_2020" is '������ �� 2020 ���';
comment on column index2020.comp_i26."�����������_2019" is '����������� �� 2019 ���';
comment on column index2020.comp_i26."�����������_2020" is '����������� �� 2020 ���';
comment on column index2020.comp_i26."��������� � ���� ������_2019" is '��������� � ���� ������ �� 2019 ���';
comment on column index2020.comp_i26."��������� � ���� ������_2020" is '��������� � ���� ������ �� 2020 ���';
comment on column index2020.comp_i26."���������� ����� � ����_2019" is '���������� ����� � ���� �� 2019 ���';
comment on column index2020.comp_i26."���������� ����� � ����_2020" is '���������� ����� � ���� �� 2020 ���';
comment on column index2020.comp_i26."���������� �����������_2019" is '���������� ����������� �� 2019 ���';
comment on column index2020.comp_i26."���������� �����������_2020" is '���������� ����������� �� 2020 ���';
comment on column index2020.comp_i26."���������� ����������_2019" is '���������� ���������� �� 2019 ���';
comment on column index2020.comp_i26."���������� ����������_2020" is '���������� ���������� �� 2020 ���';
comment on column index2020.comp_i26."������_2019" is '������ �� 2019 ���';
comment on column index2020.comp_i26."������_2020" is '������ �� 2020 ���';
comment on column index2020.comp_i26."���� �� ����������_2019" is '���� �� ���������� �� 2019 ���';
comment on column index2020.comp_i26."���� �� ����������_2020" is '���� �� ���������� �� 2020 ���';
comment on column index2020.comp_i26."������ � ����_2019" is '������ � ���� �� 2019 ���';
comment on column index2020.comp_i26."������ � ����_2020" is '������ � ���� �� 2020 ���';
comment on column index2020.comp_i26."������������� �����_2019" is '������������� ����� �� 2019 ���';
comment on column index2020.comp_i26."������������� �����_2020" is '������������� ����� �� 2020 ���';