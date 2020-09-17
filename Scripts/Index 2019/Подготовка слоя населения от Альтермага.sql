
/* добавляем колонку с признаком типа дома (многоквартирный/индивидуальный) */
alter table index2019.tmp_pop_altermag_2018 add column "type" varchar(10);
update index2019.tmp_pop_altermag_2018
set "type" = case
		when floor = 0
			then 'house'
		else 'apartments'
	end; 
/* индекс */
create index tmp_pop_altermag_2018_apartments on index2019.tmp_pop_altermag_2018("type");

/* кластеризация по геометрическому индексу */
cluster index2019.data_pop_altermag using data_pop_altermag_geom_idx;
