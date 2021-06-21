/* Посадка статистики фоток vk на гексагоны */
-- to do: Добавить статы по МКД-ИЖС и, возможно, этажности и датировке жилых зданий 

/* Временная исходная таблица с гексагональной сеткой на которую посадили id_gis и статы по населению */
-- время выполнения ~ 1 час
drop table if exists tmp.hex_stat_2020_2_1; 
create table tmp.hex_stat_2020_2_1 as 
select h.*, h1.id_gis, h2.pop_count, h2.pop_sum 
from russia.hexgrid_1ha h
left join tmp.hex_stat_2020_1 h1 using(id)
left join tmp.hex_stat_2020_2 h2 using(id);
create index on tmp.hex_stat_2020_2_1(id);
create index on tmp.hex_stat_2020_2_1(id_gis);
create index on tmp.hex_stat_2020_2_1 using gist(geom);

/* Подготовка временной таблицы фоток с атрибутами пользователей */
-- время выполнения с построением индексов ~ 1 час (точно не замерял)
drop table if exists tmp.tmp_vk;
create table tmp.tmp_vk as 
select
	v.id,
--	v.id_gis,
--	u.id_gis uid_gis,
	case when v.id_gis <> u.id_gis then true::bool when v.id_gis = u.id_gis then false else null end tourist, -- турист или местный
	case when v.in_out = 1 then true::bool when v.in_out = 0 then false else null end loc_out, -- in-out
	v.date_time,
--	v.owner_id,
--	u.user_id,
--	u.birth_date,
	case when u.sex = 1 then false::bool when u.sex = 2 then true::bool else null end male, -- пол
	u.age, -- предварительно рассчитанный возраст
	v.geom
from russia.vk_photo_2020 v
left join tmp.vk_user u -- делал отдельно, скрипт не сохранил
	on v.owner_id = u.user_id
--where u.user_id <> 0
--limit 100000
;
create index on tmp.tmp_vk(tourist);
create index on tmp.tmp_vk(loc_out);
create index on tmp.tmp_vk(date_time);
create index on tmp.tmp_vk(male);
create index on tmp.tmp_vk(age);
create index on tmp.tmp_vk using gist(geom);

/* Рассчёт статистики */
-- время выполнения с построением индексов ~ 7,5 часов (+ индексы)
drop table if exists tmp.hex_stat_2020_4;
create table tmp.hex_stat_2020_4 as 
select
	h.id,
	h.id_gis,
	h.geom,
	h.pop_count::smallint,
	coalesce(h.pop_sum, 0) pop_sum::smallint,
	-- Все фото
	coalesce(count(v.*), 0) total_photos,
	coalesce(count(v.*) filter (where v.loc_out is true ), 0)::smallint out_photos,
	coalesce(count(v.*) filter (where v.loc_out is false), 0)::smallint in_photos,
	-- Местные и туристы
	coalesce(count(v.*) filter (where v.tourist is false), 0) local_total,
	coalesce(count(v.*) filter (where v.tourist is true ), 0) tourist_total,
	coalesce(count(v.*) filter (where v.tourist is null ), 0) undef_resid_total,	
	-- Зима
	coalesce(count(v.*) filter (where date_part('month', v.date_time) in (1, 2, 12) ), 0)::smallint winter_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is false and date_part('month', v.date_time) in (1, 2, 12)), 0)::smallint winter_in_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (1, 2, 12)), 0)::smallint winter_out_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (1, 2, 12) and v.tourist is true ), 0)::smallint winter_out_photos_tourist,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (1, 2, 12) and v.tourist is false), 0)::smallint winter_out_photos_local,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (1, 2, 12) and v.tourist is null ), 0)::smallint winter_out_photos_undef_resid,
	-- Весна
	coalesce(count(v.*) filter (where date_part('month', v.date_time) in (3, 4, 5) ), 0)::smallint spring_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is false and date_part('month', v.date_time) in (3, 4, 5)), 0)::smallint spring_in_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (3, 4, 5)), 0)::smallint spring_out_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (3, 4, 5) and v.tourist is true ), 0)::smallint spring_out_photos_tourist,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (3, 4, 5) and v.tourist is false), 0)::smallint spring_out_photos_local,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (3, 4, 5) and v.tourist is null ), 0)::smallint spring_out_photos_undef_resid,
	-- Лето
	coalesce(count(v.*) filter (where date_part('month', v.date_time) in (6, 7, 8) ), 0)::smallint summer_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is false and date_part('month', v.date_time) in (6, 7, 8)), 0)::smallint summer_in_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (6, 7, 8)), 0)::smallint summer_out_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (6, 7, 8) and v.tourist is true ), 0)::smallint summer_out_photos_tourist,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (6, 7, 8) and v.tourist is false), 0)::smallint summer_out_photos_local,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (6, 7, 8) and v.tourist is null ), 0)::smallint summer_out_photos_undef_resid,
	-- Осень
	coalesce(count(v.*) filter (where date_part('month', v.date_time) in (9, 10, 11) ), 0)::smallint autumn_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is false and date_part('month', v.date_time) in (9, 10, 11)), 0)::smallint autumn_in_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (9, 10, 11)), 0)::smallint autumn_out_photos_total,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (9, 10, 11) and v.tourist is true ), 0)::smallint autumn_out_photos_tourist,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (9, 10, 11) and v.tourist is false), 0)::smallint autumn_out_photos_local,
	coalesce(count(v.*) filter (where v.loc_out is true  and date_part('month', v.date_time) in (9, 10, 11) and v.tourist is null ), 0)::smallint autumn_out_photos_undef_resid,
	-- Возраст
	-- до 20 лет
	coalesce(count(v.*) filter (where v.age < 20), 0)::smallint under_20_total,
	coalesce(count(v.*) filter (where v.age < 20 and v.male is true ), 0)::smallint under_20_male,
	coalesce(count(v.*) filter (where v.age < 20 and v.male is false), 0)::smallint under_20_female,
	coalesce(count(v.*) filter (where v.age < 20 and v.male is null ), 0)::smallint under_20_sex_undef,
	-- от 20 до 35 лет
	coalesce(count(v.*) filter (where v.age between 20 and 35), 0) between_20_35_total,
	coalesce(count(v.*) filter (where v.age between 20 and 35 and v.male is true ), 0)::smallint between_20_35_male,
	coalesce(count(v.*) filter (where v.age between 20 and 35 and v.male is false), 0)::smallint between_20_35_female,
	coalesce(count(v.*) filter (where v.age between 20 and 35 and v.male is null ), 0)::smallint between_20_35_sex_undef,
	-- от 36 до 50 лет
	coalesce(count(v.*) filter (where v.age between 36 and 50), 0)::smallint between_36_50_total,
	coalesce(count(v.*) filter (where v.age between 36 and 50 and v.male is true ), 0)::smallint between_36_50_male,
	coalesce(count(v.*) filter (where v.age between 36 and 50 and v.male is false), 0)::smallint between_36_50_female,
	coalesce(count(v.*) filter (where v.age between 36 and 50 and v.male is null ), 0)::smallint between_36_50_sex_undef,
	-- старше 50 лет
	coalesce(count(v.*) filter (where v.age > 50), 0)::smallint over_50_total,
	coalesce(count(v.*) filter (where v.age > 50 and v.male is true ), 0)::smallint over_50_male,
	coalesce(count(v.*) filter (where v.age > 50 and v.male is false), 0)::smallint over_50_female,
	coalesce(count(v.*) filter (where v.age > 50 and v.male is null ), 0)::smallint over_50_sex_undef,
	-- возраст неизвестен
	coalesce(count(v.*) filter (where v.age is null and v.male is true ), 0)::smallint age_undef_male,
	coalesce(count(v.*) filter (where v.age is null and v.male is false), 0)::smallint age_undef_female,
	coalesce(count(v.*) filter (where v.age is null and v.male is null ), 0)::smallint age_undef_sex_undef
	--
from tmp.hex_stat_2020_2_1 h
left join tmp.tmp_vk v 
	on st_intersects(h.geom, v.geom)
where h.id_gis <= 10
group by h.id, h.id_gis, h.geom, h.pop_sum, h.pop_count
;
alter table tmp.hex_stat_2020_4 rename to hex_stat_2020; -- переименование
alter table tmp.hex_stat_2020 set schema russia; -- перенос из временной в домашнюю схему
alter table russia.hex_stat_2020  
	add primary key(id) -- первичный ключ ~ 7 мин.
;
/* Индексы */
-- время построения ~ 4 часов
create index on russia.hex_stat_2020(id_gis);
create index on russia.hex_stat_2020(pop_count);
create index on russia.hex_stat_2020(pop_sum);
create index on russia.hex_stat_2020(total_photos);
create index on russia.hex_stat_2020(out_photos);
create index on russia.hex_stat_2020(in_photos);
create index on russia.hex_stat_2020(local_total);
create index on russia.hex_stat_2020(tourist_total);
create index on russia.hex_stat_2020(undef_resid_total);
create index on russia.hex_stat_2020(winter_photos_total);
create index on russia.hex_stat_2020(winter_in_photos_total);
create index on russia.hex_stat_2020(winter_out_photos_total);
create index on russia.hex_stat_2020(winter_out_photos_tourist);
create index on russia.hex_stat_2020(winter_out_photos_local);
create index on russia.hex_stat_2020(winter_out_photos_undef_resid);
create index on russia.hex_stat_2020(spring_photos_total);
create index on russia.hex_stat_2020(spring_in_photos_total);
create index on russia.hex_stat_2020(spring_out_photos_total);
create index on russia.hex_stat_2020(spring_out_photos_tourist);
create index on russia.hex_stat_2020(spring_out_photos_local);
create index on russia.hex_stat_2020(spring_out_photos_undef_resid);
create index on russia.hex_stat_2020(summer_photos_total);
create index on russia.hex_stat_2020(summer_in_photos_total);
create index on russia.hex_stat_2020(summer_out_photos_total);
create index on russia.hex_stat_2020(summer_out_photos_tourist);
create index on russia.hex_stat_2020(summer_out_photos_local);
create index on russia.hex_stat_2020(summer_out_photos_undef_resid);
create index on russia.hex_stat_2020(autumn_photos_total);
create index on russia.hex_stat_2020(autumn_in_photos_total);
create index on russia.hex_stat_2020(autumn_out_photos_total);
create index on russia.hex_stat_2020(autumn_out_photos_tourist);
create index on russia.hex_stat_2020(autumn_out_photos_local);
create index on russia.hex_stat_2020(autumn_out_photos_undef_resid);
create index on russia.hex_stat_2020(under_20_total);
create index on russia.hex_stat_2020(under_20_male);
create index on russia.hex_stat_2020(under_20_female);
create index on russia.hex_stat_2020(under_20_sex_undef);
create index on russia.hex_stat_2020(between_20_35_total);
create index on russia.hex_stat_2020(between_20_35_male);
create index on russia.hex_stat_2020(between_20_35_female);
create index on russia.hex_stat_2020(between_20_35_sex_undef);
create index on russia.hex_stat_2020(between_36_50_total);
create index on russia.hex_stat_2020(between_36_50_male);
create index on russia.hex_stat_2020(between_36_50_female);
create index on russia.hex_stat_2020(between_36_50_sex_undef);
create index on russia.hex_stat_2020(over_50_total);
create index on russia.hex_stat_2020(over_50_male);
create index on russia.hex_stat_2020(over_50_female);
create index on russia.hex_stat_2020(over_50_sex_undef);
create index on russia.hex_stat_2020(age_undef_male);
create index on russia.hex_stat_2020(age_undef_female);
create index on russia.hex_stat_2020(age_undef_sex_undef);
create index on russia.hex_stat_2020 using gist(geom)
;
/* Комментарии */
comment on table russia.hex_stat_2020 is 'Статистика по населению и фото vk (in-outб местые-туристыб половозрастная пирамида и пр.) на гексагональной сетке 1 га';
comment on column russia.hex_stat_2020.id is 'Первичный ключ';
comment on column russia.hex_stat_2020.id_gis is 'id_gis города';
comment on column russia.hex_stat_2020.pop_count is 'Количество "точек населения" в ячейке (1 точка - это 1 многоквартирный жилой дом или нексколько частных жилых домов)';
comment on column russia.hex_stat_2020.pop_sum is 'Суммарное население в ячейке';
comment on column russia.hex_stat_2020.geom is 'Геометрия';
comment on column russia.hex_stat_2020.total_photos is '';
comment on column russia.hex_stat_2020.out_photos is '';
comment on column russia.hex_stat_2020.in_photos is '';
comment on column russia.hex_stat_2020.local_total is '';
comment on column russia.hex_stat_2020.tourist_total is '';
comment on column russia.hex_stat_2020.undef_resid_total is '';
comment on column russia.hex_stat_2020.winter_photos_total is '';
comment on column russia.hex_stat_2020.winter_in_photos_total is '';
comment on column russia.hex_stat_2020.winter_out_photos_total is '';
comment on column russia.hex_stat_2020.winter_out_photos_tourist is '';
comment on column russia.hex_stat_2020.winter_out_photos_local is '';
comment on column russia.hex_stat_2020.winter_out_photos_undef_resid is '';
comment on column russia.hex_stat_2020.spring_photos_total is '';
comment on column russia.hex_stat_2020.spring_in_photos_total is '';
comment on column russia.hex_stat_2020.spring_out_photos_total is '';
comment on column russia.hex_stat_2020.spring_out_photos_tourist is '';
comment on column russia.hex_stat_2020.spring_out_photos_local is '';
comment on column russia.hex_stat_2020.spring_out_photos_undef_resid is '';
comment on column russia.hex_stat_2020.summer_photos_total is '';
comment on column russia.hex_stat_2020.summer_in_photos_total is '';
comment on column russia.hex_stat_2020.summer_out_photos_total is '';
comment on column russia.hex_stat_2020.summer_out_photos_tourist is '';
comment on column russia.hex_stat_2020.summer_out_photos_local is '';
comment on column russia.hex_stat_2020.summer_out_photos_undef_resid is '';
comment on column russia.hex_stat_2020.autumn_photos_total is '';
comment on column russia.hex_stat_2020.autumn_in_photos_total is '';
comment on column russia.hex_stat_2020.autumn_out_photos_total is '';
comment on column russia.hex_stat_2020.autumn_out_photos_tourist is '';
comment on column russia.hex_stat_2020.autumn_out_photos_local is '';
comment on column russia.hex_stat_2020.autumn_out_photos_undef_resid is '';
comment on column russia.hex_stat_2020.under_20_total is '';
comment on column russia.hex_stat_2020.under_20_male is '';
comment on column russia.hex_stat_2020.under_20_female is '';
comment on column russia.hex_stat_2020.under_20_sex_undef is '';
comment on column russia.hex_stat_2020.between_20_35_total is '';
comment on column russia.hex_stat_2020.between_20_35_male is '';
comment on column russia.hex_stat_2020.between_20_35_female is '';
comment on column russia.hex_stat_2020.between_20_35_sex_undef is '';
comment on column russia.hex_stat_2020.between_36_50_total is '';
comment on column russia.hex_stat_2020.between_36_50_male is '';
comment on column russia.hex_stat_2020.between_36_50_female is '';
comment on column russia.hex_stat_2020.between_36_50_sex_undef is '';
comment on column russia.hex_stat_2020.over_50_total is '';
comment on column russia.hex_stat_2020.over_50_male is '';
comment on column russia.hex_stat_2020.over_50_female is '';
comment on column russia.hex_stat_2020.over_50_sex_undef is '';
comment on column russia.hex_stat_2020.age_undef_male is '';
comment on column russia.hex_stat_2020.age_undef_female is '';
comment on column russia.hex_stat_2020.age_undef_sex_undef is '';


select 
	max(pop_count) pop_sum,
	max(pop_sum) pop_sum,
	max(total_photos) total_photos,
	max(out_photos) out_photos,
	max(in_photos) in_photos,
	max(local_total) local_total,
	max(tourist_total) tourist_total,
	max(undef_resid_total) undef_resid_total,
	max(winter_photos_total) winter_photos_total,
	max(winter_in_photos_total) winter_in_photos_total,
	max(winter_out_photos_total) winter_out_photos_total,
	max(winter_out_photos_tourist) winter_out_photos_tourist,
	max(winter_out_photos_local) winter_out_photos_local,
	max(winter_out_photos_undef_resid) winter_out_photos_undef_resid,
	max(spring_photos_total) spring_photos_total,
	max(spring_in_photos_total) spring_in_photos_total,
	max(spring_out_photos_total) spring_out_photos_total,
	max(spring_out_photos_tourist) spring_out_photos_tourist,
	max(spring_out_photos_local) spring_out_photos_local,
	max(spring_out_photos_undef_resid) spring_out_photos_undef_resid,
	max(summer_photos_total) summer_photos_total,
	max(summer_in_photos_total) summer_in_photos_total,
	max(summer_out_photos_total) summer_out_photos_total,
	max(summer_out_photos_tourist) summer_out_photos_tourist,
	max(summer_out_photos_local) summer_out_photos_local,
	max(summer_out_photos_undef_resid) summer_out_photos_undef_resid,
	max(autumn_photos_total) autumn_photos_total,
	max(autumn_in_photos_total) autumn_in_photos_total,
	max(autumn_out_photos_total) autumn_out_photos_total,
	max(autumn_out_photos_tourist) autumn_out_photos_tourist,
	max(autumn_out_photos_local) autumn_out_photos_local,
	max(autumn_out_photos_undef_resid) autumn_out_photos_undef_resid,
	max(under_20_total) under_20_total,
	max(under_20_male) under_20_male,
	max(under_20_female) under_20_female,
	max(under_20_sex_undef) under_20_sex_undef,
	max(between_20_35_total) between_20_35_total,
	max(between_20_35_male) between_20_35_male,
	max(between_20_35_female) between_20_35_female,
	max(between_20_35_sex_undef) between_20_35_sex_undef,
	max(between_36_50_total) between_36_50_total,
	max(between_36_50_male) between_36_50_male,
	max(between_36_50_female) between_36_50_female,
	max(between_36_50_sex_undef) between_36_50_sex_undef,
	max(over_50_total) over_50_total,
	max(over_50_male) over_50_male,
	max(over_50_female) over_50_female,
	max(over_50_sex_undef) over_50_sex_undef,
	max(age_undef_male) age_undef_male,
	max(age_undef_female) age_undef_female,
	max(age_undef_sex_undef) age_undef_sex_undef
from russia.hex_stat_2020_2


drop index russia.hex_stat_2020_age_undef_female_idx;
drop index russia.hex_stat_2020_age_undef_male_idx;
drop index russia.hex_stat_2020_age_undef_sex_undef_idx;
drop index russia.hex_stat_2020_autumn_in_photos_total_idx;
drop index russia.hex_stat_2020_autumn_out_photos_local_idx;
drop index russia.hex_stat_2020_autumn_out_photos_total_idx;
drop index russia.hex_stat_2020_autumn_out_photos_tourist_idx;
drop index russia.hex_stat_2020_autumn_out_photos_undef_resid_idx;
drop index russia.hex_stat_2020_autumn_photos_total_idx;
drop index russia.hex_stat_2020_between_20_35_female_idx;
drop index russia.hex_stat_2020_between_20_35_male_idx;
drop index russia.hex_stat_2020_between_20_35_sex_undef_idx;
drop index russia.hex_stat_2020_between_20_35_total_idx;
drop index russia.hex_stat_2020_between_36_50_female_idx;
drop index russia.hex_stat_2020_between_36_50_male_idx;
drop index russia.hex_stat_2020_between_36_50_sex_undef_idx;
drop index russia.hex_stat_2020_between_36_50_sex_undef_idx1;
drop index russia.hex_stat_2020_between_36_50_total_idx;
drop index russia.hex_stat_2020_geom_idx;
drop index russia.hex_stat_2020_id_gis_idx;
drop index russia.hex_stat_2020_in_photos_idx;
drop index russia.hex_stat_2020_local_total_idx;
drop index russia.hex_stat_2020_out_photos_idx;
drop index russia.hex_stat_2020_over_50_female_idx;
drop index russia.hex_stat_2020_over_50_male_idx;
drop index russia.hex_stat_2020_over_50_sex_undef_idx;
drop index russia.hex_stat_2020_over_50_total_idx;
drop index russia.hex_stat_2020_pkey;
drop index russia.hex_stat_2020_pop_count_idx;
drop index russia.hex_stat_2020_pop_sum_idx;
drop index russia.hex_stat_2020_spring_in_photos_total_idx;
drop index russia.hex_stat_2020_spring_out_photos_local_idx;
drop index russia.hex_stat_2020_spring_out_photos_total_idx;
drop index russia.hex_stat_2020_spring_out_photos_tourist_idx;
drop index russia.hex_stat_2020_spring_out_photos_undef_resid_idx;
drop index russia.hex_stat_2020_spring_photos_total_idx;
drop index russia.hex_stat_2020_summer_in_photos_total_idx;
drop index russia.hex_stat_2020_summer_out_photos_local_idx;
drop index russia.hex_stat_2020_summer_out_photos_total_idx;
drop index russia.hex_stat_2020_summer_out_photos_tourist_idx;
drop index russia.hex_stat_2020_summer_out_photos_undef_resid_idx;
drop index russia.hex_stat_2020_summer_photos_total_idx;
drop index russia.hex_stat_2020_total_photos_idx;
drop index russia.hex_stat_2020_tourist_total_idx;
drop index russia.hex_stat_2020_undef_resid_total_idx;
drop index russia.hex_stat_2020_under_20_female_idx;
drop index russia.hex_stat_2020_under_20_male_idx;
drop index russia.hex_stat_2020_under_20_sex_undef_idx;
drop index russia.hex_stat_2020_under_20_total_idx;
drop index russia.hex_stat_2020_winter_in_photos_total_idx;
drop index russia.hex_stat_2020_winter_out_photos_local_idx;
drop index russia.hex_stat_2020_winter_out_photos_total_idx;
drop index russia.hex_stat_2020_winter_out_photos_tourist_idx;
drop index russia.hex_stat_2020_winter_out_photos_undef_resid_idx;
drop index russia.hex_stat_2020_winter_photos_total_idx;








create table russia.hex_stat_2020 as 
select 
	id,
	id_gis::smallint,
	geom,
	pop_count::smallint,
	pop_sum::int,
	total_photos::int,
	out_photos::int,
	in_photos::int,
	local_total::int,
	tourist_total::int,
	undef_resid_total::int,
	winter_photos_total::smallint,
	winter_in_photos_total::smallint,
	winter_out_photos_total::smallint,
	winter_out_photos_tourist::smallint,
	winter_out_photos_local::smallint,
	winter_out_photos_undef_resid::smallint,
	spring_photos_total::smallint,
	spring_in_photos_total::smallint,
	spring_out_photos_total::smallint,
	spring_out_photos_tourist::smallint,
	spring_out_photos_local::smallint,
	spring_out_photos_undef_resid::smallint,
	summer_photos_total::smallint,
	summer_in_photos_total::smallint,
	summer_out_photos_total::smallint,
	summer_out_photos_tourist::smallint,
	summer_out_photos_local::smallint,
	summer_out_photos_undef_resid::smallint,
	autumn_photos_total::smallint,
	autumn_in_photos_total::smallint,
	autumn_out_photos_total::smallint,
	autumn_out_photos_tourist::smallint,
	autumn_out_photos_local::smallint,
	autumn_out_photos_undef_resid::smallint,
	under_20_total::smallint,
	under_20_male::smallint,
	under_20_female::smallint,
	under_20_sex_undef::smallint,
	between_20_35_total::int,
	between_20_35_male::smallint,
	between_20_35_female::smallint,
	between_20_35_sex_undef::smallint,
	between_36_50_total::smallint,
	between_36_50_male::smallint,
	between_36_50_female::smallint,
	between_36_50_sex_undef::smallint,
	over_50_total::smallint,
	over_50_male::smallint,
	over_50_female::smallint,
	over_50_sex_undef::smallint,
	age_undef_male::smallint,
	age_undef_female::smallint,
	age_undef_sex_undef::smallint
from russia.hex_stat_2020_2;
alter table russia.hex_stat_2020  
	add primary key(id) -- первичный ключ ~ 7 мин.
;
/* Индексы */
-- время построения ~ 4 часов
create index on russia.hex_stat_2020(id_gis);
create index on russia.hex_stat_2020(pop_count) where id_gis is not null;
create index on russia.hex_stat_2020(pop_sum) where id_gis is not null;
create index on russia.hex_stat_2020(total_photos) where id_gis is not null;
create index on russia.hex_stat_2020(out_photos) where id_gis is not null;
create index on russia.hex_stat_2020(in_photos) where id_gis is not null;
create index on russia.hex_stat_2020(local_total) where id_gis is not null;
create index on russia.hex_stat_2020(tourist_total) where id_gis is not null;
create index on russia.hex_stat_2020(undef_resid_total) where id_gis is not null;
create index on russia.hex_stat_2020(winter_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(winter_in_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(winter_out_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(winter_out_photos_tourist) where id_gis is not null;
create index on russia.hex_stat_2020(winter_out_photos_local) where id_gis is not null;
create index on russia.hex_stat_2020(winter_out_photos_undef_resid) where id_gis is not null;
create index on russia.hex_stat_2020(spring_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(spring_in_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(spring_out_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(spring_out_photos_tourist) where id_gis is not null;
create index on russia.hex_stat_2020(spring_out_photos_local) where id_gis is not null;
create index on russia.hex_stat_2020(spring_out_photos_undef_resid) where id_gis is not null;
create index on russia.hex_stat_2020(summer_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(summer_in_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(summer_out_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(summer_out_photos_tourist) where id_gis is not null;
create index on russia.hex_stat_2020(summer_out_photos_local) where id_gis is not null;
create index on russia.hex_stat_2020(summer_out_photos_undef_resid) where id_gis is not null;
create index on russia.hex_stat_2020(autumn_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(autumn_in_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(autumn_out_photos_total) where id_gis is not null;
create index on russia.hex_stat_2020(autumn_out_photos_tourist) where id_gis is not null;
create index on russia.hex_stat_2020(autumn_out_photos_local) where id_gis is not null;
create index on russia.hex_stat_2020(autumn_out_photos_undef_resid) where id_gis is not null;
create index on russia.hex_stat_2020(under_20_total) where id_gis is not null;
create index on russia.hex_stat_2020(under_20_male) where id_gis is not null;
create index on russia.hex_stat_2020(under_20_female) where id_gis is not null;
create index on russia.hex_stat_2020(under_20_sex_undef) where id_gis is not null;
create index on russia.hex_stat_2020(between_20_35_total) where id_gis is not null;
create index on russia.hex_stat_2020(between_20_35_male) where id_gis is not null;
create index on russia.hex_stat_2020(between_20_35_female) where id_gis is not null;
create index on russia.hex_stat_2020(between_20_35_sex_undef) where id_gis is not null;
create index on russia.hex_stat_2020(between_36_50_total) where id_gis is not null;
create index on russia.hex_stat_2020(between_36_50_male) where id_gis is not null;
create index on russia.hex_stat_2020(between_36_50_female) where id_gis is not null;
create index on russia.hex_stat_2020(between_36_50_sex_undef) where id_gis is not null;
create index on russia.hex_stat_2020(over_50_total) where id_gis is not null;
create index on russia.hex_stat_2020(over_50_male) where id_gis is not null;
create index on russia.hex_stat_2020(over_50_female) where id_gis is not null;
create index on russia.hex_stat_2020(over_50_sex_undef) where id_gis is not null;
create index on russia.hex_stat_2020(age_undef_male) where id_gis is not null;
create index on russia.hex_stat_2020(age_undef_female) where id_gis is not null;
create index on russia.hex_stat_2020(age_undef_sex_undef) where id_gis is not null;
create index on russia.hex_stat_2020 using gist(geom)
;




