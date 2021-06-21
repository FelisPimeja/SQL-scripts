/* Проверки */
/* Сравнение с 2018 годом. */
drop view if exists index2019.comp_i11;
create view index2019.comp_i11 as
select 
	b.id_gis::smallint,
	b.city,
	b.region,
	coalesce(i2.pop::int, 0) populations_2018,
	coalesce(i1.pop, 0) population_2019,
	coalesce(replace(i2.i11, ',','.')::numeric, 0) walkability_2018,
	coalesce(i1.i11, 0) walkability_2019,
	(case 
		when coalesce(i1.i11, 0) > coalesce(replace(i2.i11, ',','.')::numeric, 0)
			then 2019
	 	when coalesce(i1.i11, 0) = coalesce(replace(i2.i11, ',','.')::numeric, 0)
			then null
		else 2018
	end)::smallint higher_value -- в каком году показатель выше
from index2019.data_boundary b
left join index2019.ind_i11 i1 using (id_gis)
left join index2018.i11_walkability i2 on i1.id_gis = i2.id_gis::int
order by id_gis;

/* Комментарии */
comment on view index2019.comp_i11 is 'Сравнение с 2018 годом. 11-й индикатор. Индекс пешеходной доступности.';
comment on column index2019.comp_i11.id_gis is 'Уникальный идентификатор города';
comment on column index2019.comp_i11.city is 'Город';
comment on column index2019.comp_i11.region is 'Субъект РФ';
comment on column index2019.comp_i11.populations_2018 is 'Население города на 2018 г., чел.';
comment on column index2019.comp_i11.populations_2019 is 'Население города на 2019 г., чел.';
comment on column index2019.comp_i11.walkability_2018 is 'Индекс пешеходной доступности на 2018 г.';
comment on column index2019.comp_i11.walkability_2019 is 'Индекс пешеходной доступности на 2019 г.';
comment on column index2019.comp_i11.higher_value is 'В каком году показатель "Индекс пешеходной доступности" выше';