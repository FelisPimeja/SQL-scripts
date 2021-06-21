--alter table russia.hex_stat_2020 rename to hex_stat_2020_old;
/* Время выполнения замерить не удалось из-за подвисания сессии */
drop table if exists russia.hex_stat_2020;
create table russia.hex_stat_2020 as
select
	h1.id,
	h1.id_gis,
	h1.geom,
	h1.pop_count,
	h1.pop_sum,
	h1.total_photos,
	h1.out_photos,
	h1.in_photos,
	h1.local_total,
	h1.tourist_total,
	h1.undef_resid_total,
	h2.winter_photos_total,
	h1.winter_in_photos_total,
	h1.winter_out_photos_total,
	h1.winter_out_photos_tourist,
	h1.winter_out_photos_local,
	h1.winter_out_photos_undef_resid,
	h2.spring_photos_total,
	h1.spring_in_photos_total,
	h1.spring_out_photos_total,
	h1.spring_out_photos_tourist,
	h1.spring_out_photos_local,
	h1.spring_out_photos_undef_resid,
	h2.summer_photos_total,
	h1.summer_in_photos_total,
	h1.summer_out_photos_total,
	h1.summer_out_photos_tourist,
	h1.summer_out_photos_local,
	h1.summer_out_photos_undef_resid,
	h2.autumn_photos_total,
	h1.autumn_in_photos_total,
	h1.autumn_out_photos_total,
	h1.autumn_out_photos_tourist,
	h1.autumn_out_photos_local,
	h1.autumn_out_photos_undef_resid,
	h1.under_20_total,
	h1.under_20_male,
	h1.under_20_female,
	h1.under_20_sex_undef,
	h1.between_20_35_total,
	h1.between_20_35_male,
	h1.between_20_35_female,
	h1.between_20_35_sex_undef,
	h1.between_36_50_total,
	h1.between_36_50_male,
	h1.between_36_50_female,
	h1.between_36_50_sex_undef,
	h1.over_50_total,
	h1.over_50_male,
	h1.over_50_female,
	h1.over_50_sex_undef,
	h1.age_undef_male,
	h1.age_undef_female,
	h1.age_undef_sex_undef,
	h1.walkscore_kind,
	h1.walkscore_schl,
	h1.walkscore_univ,
	h1.walkscore_food,
	h1.walkscore_shop,
	h1.walkscore_heal,
	h1.walkscore_rest,
	h1.walkscore_cafe,
	h1.walkscore_fast,
	h1.walkscore_cine,
	h1.walkscore_entr,
	h1.walkscore_thea,
	h1.walkscore_park,
	h1.walkscore_fitn,
	h1.walkscore_bibl,
	h1.walkscore_r_1,
	h1.walkscore_r_2,
	h1.walkscore_r_3,
	h1.walkscore_r_4,
	h1.walkscore_r_5,
	h1.walkscore_r_all,
	a.build_density_1km2_ha dev_attract_build_density_1km2_ha,
	a.build_density_class dev_attract_build_density_class,
	a.build_density_type dev_attract_build_density_type,
	a.build_density_score dev_attract_build_density_score,
	a.ipa dev_attract_ipa,
	a.ita dev_attract_ita,
	a.sum_ipa_ita dev_attract_sum_ipa_ita,
	a.priority dev_attract_priority,
	a.priority_grade dev_attract_priority_grade
from russia.hex_stat_2020_old h1 
left join tmp.hex_stat_2020_4 h2 using(id)
left join russia.development_attractivness a using(id)
--where h1.id_gis <= 10
;
/* Индексы */
alter table russia.hex_stat_2020 add primary key(id);
create index on russia.hex_stat_2020(id_gis);
create index on russia.hex_stat_2020 using gist(geom);
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
create index on russia.hex_stat_2020(walkscore_kind);
create index on russia.hex_stat_2020(walkscore_schl);
create index on russia.hex_stat_2020(walkscore_univ);
create index on russia.hex_stat_2020(walkscore_food);
create index on russia.hex_stat_2020(walkscore_shop);
create index on russia.hex_stat_2020(walkscore_heal);
create index on russia.hex_stat_2020(walkscore_rest);
create index on russia.hex_stat_2020(walkscore_cafe);
create index on russia.hex_stat_2020(walkscore_fast);
create index on russia.hex_stat_2020(walkscore_cine);
create index on russia.hex_stat_2020(walkscore_entr);
create index on russia.hex_stat_2020(walkscore_thea);
create index on russia.hex_stat_2020(walkscore_park);
create index on russia.hex_stat_2020(walkscore_fitn);
create index on russia.hex_stat_2020(walkscore_bibl);
create index on russia.hex_stat_2020(walkscore_r_1);
create index on russia.hex_stat_2020(walkscore_r_2);
create index on russia.hex_stat_2020(walkscore_r_3);
create index on russia.hex_stat_2020(walkscore_r_4);
create index on russia.hex_stat_2020(walkscore_r_5);
create index on russia.hex_stat_2020(walkscore_r_all);
create index on russia.hex_stat_2020(dev_attract_build_density_1km2_ha);
create index on russia.hex_stat_2020(dev_attract_build_density_class);
create index on russia.hex_stat_2020(dev_attract_build_density_type);
create index on russia.hex_stat_2020(dev_attract_build_density_score);
create index on russia.hex_stat_2020(dev_attract_ipa);
create index on russia.hex_stat_2020(dev_attract_ita);
create index on russia.hex_stat_2020(dev_attract_sum_ipa_ita);
create index on russia.hex_stat_2020(dev_attract_priority);
create index on russia.hex_stat_2020(dev_attract_priority_grade);
/* Комментарии */
comment on table russia.hex_stat_2020 is 'Статистика по населению и фото vk (in-outб местые-туристыб половозрастная пирамида и пр.) на гексагональной сетке 1 га';
comment on column russia.hex_stat_2020.id is 'Первичный ключ (сквозной id для всех производных гексагональных сеток)';
comment on column russia.hex_stat_2020.id_gis is 'id_gis города (для ячеек в границах города)';
comment on column russia.hex_stat_2020.geom is 'Геометрия';
comment on column russia.hex_stat_2020.pop_count is 'Количество "точек населения" в ячейке (на основе сетки Альтермага - датасет из состава Индекса качества городской среды 2020, где 1 точка - это 1 многоквартирный жилой дом или точка сетки ИЖС с экстраполированным населением)';
comment on column russia.hex_stat_2020.pop_sum is 'Суммарное население в ячейке (на основе данных Альтермага - датасет из состава Индекса качества городской среды 2020)';
comment on column russia.hex_stat_2020.total_photos is 'Всего фото Vk в ячейке';
comment on column russia.hex_stat_2020.out_photos is 'Всего фото Vk в ячейке, сделанных на улице (классифицировано командой DC)';
comment on column russia.hex_stat_2020.in_photos is 'Всего фото Vk в ячейке, сделанных в помещении (классифицировано командой DC)';
comment on column russia.hex_stat_2020.local_total is 'Всего фото Vk в ячейке, сделанных местными жителями (город в котором сделано фото совпадает с городом проживания человека - на основе заполненных профилей пользователей загрузивших фото)';
comment on column russia.hex_stat_2020.tourist_total is 'Всего фото Vk в ячейке, сделанных туристами (город в котором сделано фото не соответствует городу проживания человека - на основе заполненных профилей пользователей загрузивших фото)';
comment on column russia.hex_stat_2020.undef_resid_total is 'Всего фото Vk в ячейке, для которых не получилось определить сделаны ли они местными жителями или туристами (в профиле Vk не указан город проживания человека - на основе заполненных профилей пользователей загрузивших фото)';
comment on column russia.hex_stat_2020.winter_photos_total is 'Всего фото Vk в ячейке, сделанных зимой (по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.winter_in_photos_total is 'Всего фото Vk в ячейке, сделанных зимой в помещении (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.winter_out_photos_total is 'Всего фото Vk в ячейке, сделанных зимой на улице (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.winter_out_photos_tourist is 'Всего фото Vk в ячейке, сделанных зимой на улице туристами (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.winter_out_photos_local is 'Всего фото Vk в ячейке, сделанных зимой на улице местными жителями (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.winter_out_photos_undef_resid is 'Всего фото Vk в ячейке, сделанных зимой, но не известно местным жителем или туристом (классификация in-out командой DC + в профиле Vk пользователя отсутствует информация о городе проживания + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.spring_photos_total is 'Всего фото Vk в ячейке, сделанных весной (по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.spring_in_photos_total is 'Всего фото Vk в ячейке, сделанных весной в помещении (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.spring_out_photos_total is 'Всего фото Vk в ячейке, сделанных весной на улице (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.spring_out_photos_tourist is 'Всего фото Vk в ячейке, сделанных весной на улице туристами (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.spring_out_photos_local is 'Всего фото Vk в ячейке, сделанных весной на улице местными жителями (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.spring_out_photos_undef_resid is 'Всего фото Vk в ячейке, сделанных весной, но не известно местным жителем или туристом (классификация in-out командой DC + в профиле Vk пользователя отсутствует информация о городе проживания + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.summer_photos_total is 'Всего фото Vk в ячейке, сделанных летом (по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.summer_in_photos_total is 'Всего фото Vk в ячейке, сделанных летом в помещении (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.summer_out_photos_total is 'Всего фото Vk в ячейке, сделанных летом на улице (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.summer_out_photos_tourist is 'Всего фото Vk в ячейке, сделанных летом на улице туристами (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.summer_out_photos_local is 'Всего фото Vk в ячейке, сделанных летом на улице местными жителями (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.summer_out_photos_undef_resid is 'Всего фото Vk в ячейке, сделанных летом, но не известно местным жителем или туристом (классификация in-out командой DC + в профиле Vk пользователя отсутствует информация о городе проживания + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.autumn_photos_total is 'Всего фото Vk в ячейке, сделанных осенью (по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.autumn_in_photos_total is 'Всего фото Vk в ячейке, сделанных осенью в помещении (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.autumn_out_photos_total is 'Всего фото Vk в ячейке, сделанных осенью на улице (классификация in-out командой DC + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.autumn_out_photos_tourist is 'Всего фото Vk в ячейке, сделанных осенью на улице туристами (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.autumn_out_photos_local is 'Всего фото Vk в ячейке, сделанных осенью на улице местными жителями (классификация in-out командой DC + информация о городе проживания пользователя из профиля Vk + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.autumn_out_photos_undef_resid is 'Всего фото Vk в ячейке, сделанных осенью, но не известно местным жителем или туристом (классификация in-out командой DC + в профиле Vk пользователя отсутствует информация о городе проживания + месяц съёмки по данным даты загрузки фото в Vk)';
comment on column russia.hex_stat_2020.under_20_total is 'Всего фото Vk в ячейке, сделанных пользователями младше 20 лет (по данным о дате рождения пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.under_20_male is 'Всего фото Vk в ячейке, сделанных мужчинами младше 20 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.under_20_female is 'Всего фото Vk в ячейке, сделанных женщинами младше 20 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.under_20_sex_undef is 'Всего фото Vk в ячейке, сделанных пользователями младше 20 лет, пол которых неизвестен (по данным о дате рождения пользователя из профиля Vk у которых не указан пол)';
comment on column russia.hex_stat_2020.between_20_35_total is 'Всего фото Vk в ячейке, сделанных пользователями от 20 до 35 лет (по данным о дате рождения пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.between_20_35_male is 'Всего фото Vk в ячейке, сделанных мужчинами от 20 до 35 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.between_20_35_female is 'Всего фото Vk в ячейке, сделанных женщинами от 20 до 35 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.between_20_35_sex_undef is 'Всего фото Vk в ячейке, сделанных пользователями от 20 до 35 лет, пол которых неизвестен (по данным о дате рождения пользователя из профиля Vk у которых не указан пол)';
comment on column russia.hex_stat_2020.between_36_50_total is 'Всего фото Vk в ячейке, сделанных пользователями от 36 до 50 лет (по данным о дате рождения пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.between_36_50_male is 'Всего фото Vk в ячейке, сделанных мужчинами от 36 до 50 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.between_36_50_female is 'Всего фото Vk в ячейке, сделанных женщинами от 36 до 50 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.between_36_50_sex_undef is 'Всего фото Vk в ячейке, сделанных пользователями от 36 до 50 лет, пол которых неизвестен (по данным о дате рождения пользователя из профиля Vk у которых не указан пол)';
comment on column russia.hex_stat_2020.over_50_total is 'Всего фото Vk в ячейке, сделанных пользователями старше 50 лет (по данным о дате рождения пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.over_50_male is 'Всего фото Vk в ячейке, сделанных мужчинами старше 50 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.over_50_female is 'Всего фото Vk в ячейке, сделанных женщинами старше 50 лет (по данным о дате рождения и поле пользователя из профиля Vk)';
comment on column russia.hex_stat_2020.over_50_sex_undef is 'Всего фото Vk в ячейке, сделанных пользователями старше 50 лет, пол которых неизвестен (по данным о дате рождения пользователя из профиля Vk у которых не указан пол)';
comment on column russia.hex_stat_2020.age_undef_male is 'Всего фото Vk в ячейке, сделанных мужчинами возраст которых не известен (по данным о поле пользователя из профиля Vk с не указанной датой рождения)';
comment on column russia.hex_stat_2020.age_undef_female is 'Всего фото Vk в ячейке, сделанных женщинами возраст которых не известен (по данным о поле пользователя из профиля Vk с не указанной датой рождения)';
comment on column russia.hex_stat_2020.age_undef_sex_undef is 'Всего фото Vk в ячейке, сделанных пользователями пол и возраст которых не известен (по данным из незаполненного профиля Vk пользователя)';
comment on column russia.hex_stat_2020.walkscore_kind is 'Уровень доступности детских садов в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_schl is 'Уровень доступности школ в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_univ is 'Уровень доступности высших учебных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_food is 'Уровень доступности продуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_shop is 'Уровень доступности непродуктовых магазинов в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_heal is 'Уровень доступности учреждений здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_fast is 'Уровень доступности предприятий быстрого питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_cafe is 'Уровень доступности кафе в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_rest is 'Уровень доступности ресторанов в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_cine is 'Уровень доступности кинотеатров в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_thea is 'Уровень доступности театров в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_entr is 'Уровень доступности развлекательных заведений в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_park is 'Уровень доступности парков и других зелёных зон в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_bibl is 'Уровень доступности библиотек в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_fitn is 'Уровень доступности фитнес центров и спортивных учреждений в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_r_1 is 'Средневзвешенный уровень доступности образования в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_r_2 is 'Средневзвешенный уровень доступности магазинов и здравоохранения в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_r_3 is 'Средневзвешенный уровень доступности общественного питания в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_r_4 is 'Средневзвешенный уровень доступности досуга и развлечений в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_r_5 is 'Средневзвешенный уровень доступности спорта и рекреации в баллах (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.walkscore_r_all is 'Средневзвешенный уровень пешеходной доступности в баллах - итоговый WalkScore (больше - лучше, максимум 100 баллов)';
comment on column russia.hex_stat_2020.dev_attract_build_density_1km2_ha is 'Плотность застройки по футпринтам зданий, км2/га';
comment on column russia.hex_stat_2020.dev_attract_build_density_class is 'Класс территории по плотности застройки (Свободный/Низкая плотность/Высокая плотность)';
comment on column russia.hex_stat_2020.dev_attract_build_density_type is 'Средневзвешенный тип среды для ячейки (
1 Дачная городская среда
2 Сельская городская среда
3 Историческая индивидуальная городская среда
4 Современная индивидуальная городская среда
5 Советская малоэтажная разреженная городская среда
6 Современная блокированная городская среда
7 Советская малоэтажная периметральная городская среда
8 Историческая разреженная городская среда
9 Советская среднеэтажная микрорайонная городская среда
10 Современная малоэтажная городская среда
11 Историческая периметральная городская среда
12 Советская малоэтажная микрорайонная городская среда
13 Советская среднеэтажная периметральная городская среда
14 Современная многоэтажная городская среда)';
comment on column russia.hex_stat_2020.dev_attract_build_density_score is 'Уровень застроенности по шкале от 0 до 3';
comment on column russia.hex_stat_2020.dev_attract_ipa is 'Максимальный индекс пешеходной активности в ячейке (на основе данных ipa-ita,  рассчитанных Сергеем Тюпановым)';
comment on column russia.hex_stat_2020.dev_attract_ita is 'Максимальный индекс транспортной активности в ячейке (на основе данных ipa-ita,  рассчитанных Сергеем Тюпановым)';
comment on column russia.hex_stat_2020.dev_attract_sum_ipa_ita is 'Средневзвешенная пешеходно-транспортная активность в ячейке (если плотность застройки < 0.6, то соотношение веса 0.7/0.3 в пользу транспортной активности. При более высокой плотности соотношение пешеходной и транспортной активности 0.5/0.5)';
comment on column russia.hex_stat_2020.dev_attract_priority is 'Базовый класс привлекательности территории (Низкопривлекательная/Среднепривлекательная/Высокопривлекательная)';
comment on column russia.hex_stat_2020.dev_attract_priority_grade is 'Взвешенная привлекательности территории (базовая привлекательность территории взвешенная на итоговом индексе WalkScore по трём классам:
- < 40
- 40 - 80
- > 80
Итоговое ранжирование (больше -> привлекательнее):
Низкопривлекательные
- 11
- 12
- 13
Среднепривлекательные
- 21
- 22
- 23
Высокопривлекательные
- 31
- 32
- 33
)';