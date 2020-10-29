/* Целевые параметры среды */
/* Время расчёта: ~ 2.5 мин для Челябинска */

-- Буферы 800 м. от кварталов (~ 15 сек.)
drop table if exists quater_buffer;
create temp table quater_buffer as
select
	id,
	id_gis,
	geom src_geom, -- исходную геометрию оставляем
	st_multi(st_buffer(geom::geography, 800)::geometry)::geometry(multipolygon, 4326) geom -- буфер 800м (~ пешая досягаемость. Правильнее строить изохроны, но пока считаем так!!!)
--from street_classify.q_1080_v8 q --bak
from russia.city_quater_type q
--where q.id_gis = 1080; --дебаг
where q.id_gis in(
	44,256,288,290,797,812,871,926,927,932,943,952,955,
	960,991,992,1010,1031,1034,1040,1047,1050,1061,
	1065,1071,1075,1080,1082,1096,1099,1101,1104
); --целевые id_gis для 32 городов для проекта Стандарта Мастер плана

create index on quater_buffer(id);
create index on quater_buffer(id_gis);
create index on quater_buffer((st_area(src_geom::geography)));
create index on quater_buffer using gist(geom);
create index on quater_buffer using gist(src_geom);


-- Подсчёт кол-ва аварийных домов в квартале (имеет смысл перенести в классификацию типов сред)
drop table if exists hazardous_dwelling;
create temp table hazardous_dwelling as 
select
	q.id,
	q.id_gis,
	count(h.*) total_hazardous_dwelling
from quater_buffer q
left join russia.dwelling_hazardous h
	on q.id_gis = h.id_gis
		and h.match_level = 'house'
		and st_intersects(q.src_geom, h.geom)
group by q.id, q.id_gis;

create index on hazardous_dwelling(id);
create index on hazardous_dwelling(id_gis);
create index on hazardous_dwelling(total_hazardous_dwelling);


-- Проверка на негативные антропогенные факторы в шаговой доступности
drop table if exists negative_factors;
create temp table negative_factors as 
select
	q.id,
	q.id_gis,
	case when count(p.id) > 0 then true::bool else false::bool end negative_factors
from quater_buffer q
left join index2019.data_poi p
	on q.id_gis = p.id_gis
		and st_intersects(q.geom, p.geom)
		and p.rubrics in (
			'Психоневрологический интернат', 
			'Наркологическая клиника', 
			'Диспансер', 
			'Диагностический центр', 
			'Исправительное учреждение',
			'Приют для животных',
			'НИИ',
			'Автовокзал', 
			'Железнодорожный вокзал'
		)
group by q.id, q.id_gis;

create index on negative_factors(id);
create index on negative_factors(id_gis);
create index on negative_factors(negative_factors);


-- Подсчёт плотности населения
drop table if exists pop_density;
create temp table pop_density as
select
	q.id,
	q.id_gis,
	coalesce(round((sum(p.population) * 10000 / st_area(q.src_geom::geography))::numeric), 0) pop_density
from quater_buffer q
left join index2019.data_pop_altermag p
	on q.id_gis = p.id_gis
		and st_intersects(q.src_geom, p.geom)
group by q.id, q.id_gis, q.src_geom;

create index on pop_density(id);
create index on pop_density(id_gis);
create index on pop_density(pop_density);


-- Проверка на благоустроенного озеленения в шаговой доступности
drop table if exists greenery;
create temp table greenery as
select
	q.id,
	q.id_gis,
	case when count(g.id) > 0 then true::bool else false::bool end greenery_access
from quater_buffer q
left join index2019.data_greenery g
	on q.id_gis = g.id_gis
		and st_intersects(q.geom, g.geom)
group by q.id, q.id_gis;

create index on greenery(id);
create index on greenery(id_gis);
create index on greenery(greenery_access);


-- Проверка наличия остановок общественного транспорта в шаговой доступности (можно было бы проверять отдельно для каждого дома, а потом взвешивать) (~ 22 сек.)
drop table if exists public_transport;
create temp table public_transport as 
select
	q.id,
	q.id_gis,
	case when count(p.id) > 0 then true::bool else false::bool end public_transport_access
from quater_buffer q
left join index2019.data_poi p
	on q.id_gis = p.id_gis
		and p.rubrics = 'Остановка общественного транспорта'
		and st_intersects(q.geom, p.geom)
group by q.id, q.id_gis;

create index on public_transport(id);
create index on public_transport(id_gis);
create index on public_transport(public_transport_access);


/* Пока не участвует в расчёте - дебажить!!! */
/* -- Транспортная активность
drop table if exists transport_activity;
create temp table transport_activity as 
--explain analyze
select
	sa.id,
	sa.id_gis,
	coalesce(round((sum(i.ita_norm * st_length(i.geom::geography, true)) / nullif(sum(st_length(i.geom::geography, true)), 0))::numeric, 2), 0) ita_avg -- усреднённый индекс транспортной активности
from tmp.chelyabinsk_service_area_subdiv sa
left join tmp.chelyabinsk_ita i
	on sa.id_gis = i.id_gis
		and st_intersects(sa.geom, i.geom)
group by sa.id, sa.id_gis;

--drop table if exists tmp.chelyabinsk_service_area_subdiv;
--create table tmp.chelyabinsk_service_area_subdiv as select (row_number() over())::int fid, * from (select id, id_gis, st_subdivide(geom, 50)::geometry(polygon, 4326) geom from tmp.chelyabinsk_service_area) a;
--create index on tmp.chelyabinsk_service_area_subdiv(id_gis);
--create index on tmp.chelyabinsk_service_area_subdiv using gist(geom);

create index on tmp.chelyabinsk_service_area(id_gis);
*/



--!!! Перезалить таблицу на всю Россию потом !!!
--create table street_classify.ipa as select (row_number() over())::int id, ipa::numeric, id_gis::int2, geom from tmp.ipa_st_geom;
--alter table street_classify.ipa add primary key(id);
--create index on street_classify.ipa(id_gis); 
--create index on street_classify.ipa(ipa); 
--create index on street_classify.ipa using gist(geom); 
--create index on street_classify.ipa ((st_length(geom::geography))); 
--!!!


-- Пешеходная активность (~ 2 мин)
drop table if exists pedestrian_activity;
create temp table pedestrian_activity as 
select
	q.id,
	q.id_gis,
	coalesce(round((sum(i.ipa * st_length(i.geom::geography, true)) / nullif(sum(st_length(i.geom::geography, true)), 0))::numeric, 2), 0) ipa_avg -- усреднённый индекс пешеходной активности
from quater_buffer q
left join street_classify.ipa i
	on q.id_gis = i.id_gis
		and st_intersects(q.geom, i.geom)
group by q.id, q.id_gis;

create index on pedestrian_activity(id);
create index on pedestrian_activity(id_gis);
create index on pedestrian_activity(ipa_avg);


-- Проверка шаговой доступности POI (~ 2 мин.) 
drop table if exists poi;
create temp table poi as 
select
	q.id,
	q.id_gis,
	case
		when count(p.id) filter(where p.rubrics in (
			'Гимназия',
			'Лицей',
			'Общеобразовательная школа',
			'Частная школа'
		)) > 0
			and count(p.id) filter(where p.rubrics in ('Детский сад')) > 0
			then true::bool
		else false::bool
	end school_kindergarden,
	case
		when count(p.id) filter(where p.rubrics in (
			'Амбулатория',
			'Больница для взрослых',
			'Госпиталь',
			'Детская больница',
			'Детская поликлиника',
			'Диагностический центр',
			'Диспансер',
			'Женская консультация',
			'Здравпункт',
			'Клиника',
			'Медпункт',
			'Медцентр',
			'Поликлиника для взрослых',
			'Скорая медицинская помощь',
			'Специализированная больница',
			'Травмпункт'
		)) > 0
			then true::bool
		else false::bool
	end clinic,
	count(distinct p.rubrics) filter(where p.rubrics in (
			'Театр',
			'Музей',
			'Планетарий',
			'Зоопарк',
			'Галлерея'
		)) entertainment, -- число развлекательных объектов
	count(p.id) filter(where p.rubrics in (
			'Магазин продуктов',
			'Продуктовый рынок',
			'Магазин хозтоваров и бытовой техники',
			'Магазин хозтоваров и бытовой химии',
			'Кафе',
			'Ресторан',
			'Салон красоты',
			'Парикмахерская',
			'Ремонт аудиотехники и видеотехники',
			'Ремонт бытовой техники',
			'Ремонт кожи',
			'Ремонт обуви',
			'Ремонт одежды',
			'Ремонт сотовых телефонов',
			'Ремонт сумок и чемоданов'
		)) service, -- число сервисных объектов
	case 
		when count(p.id) filter(where p.mall is true) > 0 then true::bool
		else false::bool
	end mall -- наличие торгового центра в радиусе пешеходной доступности
from quater_buffer q
left join index2019.data_poi p
	on q.id_gis = p.id_gis
		and st_intersects(q.geom, p.geom)
group by q.id, q.id_gis;

create index on poi(id);
create index on poi(id_gis);
create index on poi(school_kindergarden);
create index on poi(clinic);
create index on poi(entertainment);
create index on poi(mall);


-- Расчёт суммарного футпринта и площади застройки + средняя этажность жилых зданий (~ 50 сек.) - Надо бы перенести в расчёт статистики по кварталам!!!
drop table if exists far_gba;
create temp table far_gba as 
select 
	q.id,
	q.id_gis,
	sum(area_m2) far_m2,
	sum(area_m2 * levels) gba_m2,
	percentile_disc(0.5) within group(order by b.levels) filter(where b.building_type != 'other') residential_median_level
from quater_buffer q
left join russia.building_classify b
	on q.id_gis = b.id_gis
		and st_intersects(q.src_geom, b.geom)
group by q.id, q.id_gis;

create index on far_gba(id);
create index on far_gba(id_gis);
create index on far_gba(far_m2);
create index on far_gba(gba_m2);
create index on far_gba(residential_median_level);


-- Вычленяем точки ОДЗ для последующего расчёта суммарной площади (~ 2.5 мин)
drop table if exists odz_points;
create temp table odz_points as 
select distinct on(p.company_id)
	q.id,
	q.id_gis,
	p.rubrics,
	p.geom
from quater_buffer q
left join index2019.data_poi p
	on q.id_gis = p.id_gis
		and p.odz is true
		and st_intersects(q.src_geom, p.geom);

create index on odz_points(id_gis);
create index on odz_points(id);
create index on odz_points(rubrics);
create index on odz_points using gist(geom);

-- Считаем суммарную площадь по референсной таблице площадей и точек из предыдущего шага
drop table if exists odz_area;
create temp table odz_area as 
select 
	p.id,
	p.id_gis,
	sum(a.gba) odz_area_m2
from odz_points p
left join street_classify.buisness_avg_area a using(rubrics)
group by p.id, p.id_gis;

create index on odz_area(id);
create index on odz_area(id_gis);
create index on odz_area(odz_area_m2);

-- Свод статистики из предыдущих шагов
drop table if exists stat;
create temp table stat as 
	select
	/* Числовые характеристики */
	q.id, -- уникальный id квартала
	q.id_gis,
	q.quater_class,
	q.area_ha, -- Площадь квартала (га)
	pd.pop_density, -- Плотнность населения (чел./ га)
	coalesce(round((f.gba_m2 / (area_ha * 1000))::numeric) , 0)  built_density, -- Плотность застройки квартала (тыс. м2/га)
	f.residential_median_level, -- Этажность застройки ( надземных этажа)
	-- Ширина улиц районного значения (м)
	-- Ширина второстепенных улиц (м)
	-- Ширина местных улиц (м)

	/* Уровень связанности территории */						
	pt.public_transport_access, -- Доступность на общественном транспорте/уровень обеспеченности территории/объекта общественным транспортом - пешеходная доступность остановок ОТ, 2 и более видов транспорта в пешеходной доступности.  
	case 
		when ita.ita_avg >= 1 then 'Высокая (3)'::varchar
		when ita.ita_avg >= 0.1 and ita.ita_avg <= 1 then 'Средняя (2)'::varchar
		else 'Низкая (1)'::varchar
	end ita, -- Уровень связанности территории/объекта по улично-дорожной сети с другими районами города - Средний уровень интенсивности использования дорог в 10 минутах езды на машине
	case 
		when ipa.ipa_avg >= 1 then 'Высокая (3)'::varchar
		when ipa.ipa_avg >= 0.1 and ipa.ipa_avg <= 1 then 'Средняя (2)'::varchar
		else 'Низкая (1)'::varchar
	end ipa, -- Уровень пешеходной связанности территории/объекта с прилегающими территориями - Средний уровень интенсивности использования пешеходных путей в радиусе пешеходной досупности

	/* Обеспеченность сервисами */					
	case
		when p.school_kindergarden is true and p.clinic is true 
			then 'Высокая (3)'::varchar
		when p.school_kindergarden is true and p.clinic is false
			then 'Средняя (2)'::varchar
		else 'Низкая (1)'::varchar
	end social_access,	-- Обеспеченность социальными объектами в пешеходной доступности - берем отдельно все объекты этой группы и смотрим пешеходную доступность: школы, детские сады, поликлиники, больницы.
		--	Высокая - когда все вышеперечисленное есть.
		--	Средняя - когда есть школа и детский сад
		--	Низкая - когда нет ничего или только поликлиника/больница
	case
		when p.entertainment >= 3 then 'Высокая (3)'::varchar
		when p.entertainment = 2 then 'Средняя (2)'::varchar
		else 'Низкая (1)'::varchar
	end entertainment_access,	-- Обеспеченность досуговыми и объектами культуры в пешеходной доступности - берем отдельно все объекты этой группы и смотрим пешеходную доступность: театры, музеи, галлереи, планитарий, зоопарк, итд.
		--	Высокая - когда есть 3 и более вида досуговых объектов в пешеходной доступности.
		--	Средняя - когда есть 3 вида досуговых объектов в пешеходной доступности
		--	Низкая - когда есть 1 вид досуговых объектов или они отсутствуют в пешеходной доступности
	case
		when p.mall is true then 'Высокая (3)'::varchar
		when p.service >= 5 then 'Средняя (2)'::varchar
		else 'Низкая (1)'::varchar
	end service_access,	-- Обеспеченность объектами сервисной инфраструктуры - берем объекты ритейла.
		--	Высокая - ТЦ в пешеходной доступности, высокое разнообразие сервисов.
		--	Средняя - Наличие базовых профилей ритейла в пешеходной доступности (продукты, хозяйственные, кафе, рестораны, салоны красоты, парикмахерские, ремонтные мастерские).
		--	Низкая - отсутствие объектов в пешеходной доступности, наличие только продуктовых магазинов.
	g.greenery_access, -- Обеспеченность озелененными объектами в пешеходной доступности.
	-- Доля помещений объектов общественно-деловой инфраструктуры от общей площади площади застройки территории. Считается как количество объектов общественных функций, каждый из которых, в зависимости от типа, умножен на среднюю площадь таких объектов (список, где типы объектов соотнесены с площадью будет позднее) деленный на общую площадь застройки. 

	/* Качественные характеристики территории */						
	n.negative_factors,-- Близость негативных антропогенных факторов. (в пешеходной доступности)
	case 
		when h.total_hazardous_dwelling > 0 then true::bool
		else false::bool
	end hazardous_dwelling, -- Наличие аварийного жилья

	/* Пока на рассмотрении */
    coalesce(f.far_m2, 0) far,-- Плотность застройки по футпринту здания (FAR)
    coalesce(o.odz_area_m2, 0),
    round(coalesce(o.odz_area_m2 * 100 / nullif(f.gba_m2, 0), 0)::numeric, 2) odz_area_percent,

    geom
from russia.city_quater_type q
left join hazardous_dwelling h using(id)
left join negative_factors n using(id)
left join greenery g using(id)
left join public_transport pt using(id)
left join transport_activity ita using(id)
left join pedestrian_activity ipa using(id)
left join poi p using(id)
left join far_gba f using(id)
left join odz_area o using(id)
left join pop_density pd using(id)
where q.id_gis in(
	44,256,288,290,797,812,871,926,927,932,943,952,955,
	960,991,992,1010,1031,1034,1040,1047,1050,1061,
	1065,1071,1075,1080,1082,1096,1099,1101,1104
);
	

-- Второй свод статистики (прописываем целевые показатели и считаем дельту)
drop table if exists stat2;
create temp table stat2 as
select
	id,
	id_gis,
	quater_class,
	area_ha,
	case
		when quater_class in ('Индивидуальная жилая городская среда', 'Историческая смешанная городская среда')
			then case
				when area_ha <= 4 then 0
				else round((4 - area_ha)::numeric, 2)
			end
		when quater_class = 'Cоветская периметральная городская среда'
			then case
				when area_ha <= 7 then 0
				else round((7 - area_ha)::numeric, 2)
			end
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then case
				when area_ha <= 5 then 0
				else round((5 - area_ha)::numeric, 2)
			end
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then case
				when area_ha <= 24 then 0
				else round((24 - area_ha)::numeric, 2)
			end
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then case
				when area_ha <= 27 then 0
				else round((27 - area_ha)::numeric, 2)
			end
		when quater_class = 'Не классифицировано'
			then 0
	end area_ha_delta,
	pop_density,
	(case
		when quater_class = 'Индивидуальная жилая городская среда'
			then case
				when pop_density < 30
					then round((30 - pop_density)::numeric, 2)
				when pop_density > 35
					then round((35 - pop_density)::numeric, 2)
				else 0
			end
		when quater_class = 'Историческая смешанная городская среда'
			then case
				when pop_density < 200
					then round((200 - pop_density)::numeric, 2)
				when pop_density > 300
					then round((300 - pop_density)::numeric, 2)
				else 0
			end
		when quater_class = 'Cоветская периметральная городская среда'
			then case
				when pop_density < 250
					then round((250 - pop_density)::numeric, 2)
				when pop_density > 350
					then round((350 - pop_density)::numeric, 2)
				else 0
			end
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then case
				when pop_density < 50
					then round((50 - pop_density)::numeric, 2)
				when pop_density > 80
					then round((80 - pop_density)::numeric, 2)
				else 0
			end
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then case
				when pop_density < 200
					then round((200 - pop_density)::numeric)
				when pop_density > 250
					then round((250 - pop_density)::numeric)
				else 0::smallint
			end
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then case
				when pop_density < 450
					then round((450 - pop_density)::numeric)
				when pop_density > 500
					then round((500 - pop_density)::numeric)
				else 0
			end
		when quater_class = 'Не классифицировано'
			then 0::smallint
	end)::smallint pop_density_delta,
	built_density,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then case
				when built_density < 0.5
					then round((0.5 - built_density)::numeric, 2)
				when built_density > 5
					then round((5 - built_density)::numeric, 2)
				else 0
			end
		when quater_class = 'Историческая смешанная городская среда'
			then case
				when built_density < 8
					then round((8 - built_density)::numeric, 2)
				when built_density > 24
					then round((24 - built_density)::numeric, 2)
				else 0
			end
		when quater_class = 'Cоветская периметральная городская среда'
			then case
				when built_density < 5
					then round((5 - built_density)::numeric, 2)
				when built_density > 18
					then round((18 - built_density)::numeric, 2)
				else 0
			end
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then case
				when built_density < 4
					then round((4 - built_density)::numeric, 2)
				when built_density > 8
					then round((8 - built_density)::numeric, 2)
				else 0
			end
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then case
				when built_density = 8
					then 0
				else round((8 - built_density)::numeric, 2)
			end
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then case
				when built_density = 14
					then 0
				else round((14 - built_density)::numeric, 2)
			end
		when quater_class = 'Не классифицировано'
			then 0
	end built_density_delta,
	residential_median_level,
	0::smallint residential_median_level_delta, 
	public_transport_access,
	case
		when public_transport_access is true
			then 0::smallint
		else -1::smallint
	end public_transport_access_delta, 
	ipa,
	case
		when ipa = 'Высокая (3)'
			then 0::smallint
		when ipa = 'Средняя (2)'
			then -1::smallint
		when ipa = 'Низкая (1)'
			then -2::smallint
	end ipa_delta,
	ita,
	case
		when ita = 'Высокая (3)'
			then 0::smallint
		when ita = 'Средняя (2)'
			then -1::smallint
		when ita = 'Низкая (1)'
			then -2::smallint
	end ita_delta,
	social_access,
	case 
		when quater_class in ('Индивидуальная жилая городская среда', 'Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда') 
			then case
				when social_access in ('Высокая (3)', 'Средняя (2)')
					then 0::smallint
				when social_access = 'Низкая (1)'
					then -1::smallint
			end
		else case
			when social_access = 'Высокая (3)'
				then 0::smallint
			when social_access = 'Средняя (2)'
				then -1::smallint
			when social_access = 'Низкая (1)'
				then -2::smallint
		end
	end	 social_access_delta,
	entertainment_access,
	case 
		when quater_class in ('Индивидуальная жилая городская среда', 'Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then case
				when entertainment_access in ('Высокая (3)', 'Средняя (2)')
					then 0::smallint
				when entertainment_access = 'Низкая (1)'
					then -1::smallint
			end
		else case
			when entertainment_access = 'Высокая (3)'
				then 0::smallint
			when entertainment_access = 'Средняя (2)'
				then -1::smallint
			when entertainment_access = 'Низкая (1)'
				then -2::smallint
		end
	end entertainment_access_delta,
	service_access,
	case 
		when quater_class in ('Индивидуальная жилая городская среда', 'Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then case
				when service_access in ('Высокая (3)', 'Средняя (2)')
					then 0::smallint
				when service_access = 'Низкая (1)'
					then -1::smallint
			end
		else case
			when service_access = 'Высокая (3)'
				then 0::smallint
			when service_access = 'Средняя (2)'
				then -1::smallint
			when service_access = 'Низкая (1)'
				then -2::smallint
		end
	end service_access_delta,
	greenery_access,
	case 
		when greenery_access is true
			then 0::smallint
		else -1::smallint
	end  greenery_access_delta,
	odz_area_percent,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then 7 - odz_area_percent
		when quater_class = 'Историческая смешанная городская среда'
			then 34 - odz_area_percent
		when quater_class = 'Cоветская периметральная городская среда'
			then 29 - odz_area_percent
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then 20 - odz_area_percent
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then 20 - odz_area_percent
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then 16 - odz_area_percent
	end odz_area_percent_delta,	
	hazardous_dwelling,
	case
		when hazardous_dwelling is false
			then 0::smallint
		else -1::smallint
	end hazardous_dwelling_delta,
	negative_factors,
	case
		when negative_factors is false
			then 0::smallint
		else -1::smallint
	end negative_factors_delta,
	far,
	geom
from stat
order by id_gis, id;


-- Итоговая статистика (не слить ли с предыдущим шагом?)
drop table if exists street_classify.quater_stat_verify;
create table street_classify.quater_stat_verify as
select
	id,
	id_gis,
	quater_class,
	area_ha,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then 4::smallint
		when quater_class = 'Историческая смешанная городская среда'
			then 4::smallint
		when quater_class = 'Cоветская периметральная городская среда'
			then 7::smallint
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then 5::smallint
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then 24::smallint
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then 27::smallint
	end area_ha_reference,
	area_ha_delta,
	pop_density,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then '30-35'::text
		when quater_class = 'Историческая смешанная городская среда'
			then '200-300'::text
		when quater_class = 'Cоветская периметральная городская среда'
			then '250-350'::text
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then '50-80'::text
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then '200-250'::text
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then '450-500'::text
	end pop_density_reference,
	pop_density_delta,
	built_density,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then '0.5-5'::text
		when quater_class = 'Историческая смешанная городская среда'
			then '8-24'::text
		when quater_class = 'Cоветская периметральная городская среда'
			then '5-18'::text
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then '4-8'::text
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then '8'::text
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then '14'::text
	end built_density_reference,
	built_density_delta,
	residential_median_level,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then '1-3'::text
		when quater_class = 'Историческая смешанная городская среда'
			then '3-8'::text
		when quater_class = 'Cоветская периметральная городская среда'
			then '5-8'::text
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then '1-4'::text
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then '5-9'::text
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then '10-18'::text
	end residential_median_level_reference,
	residential_median_level_delta,
	public_transport_access,
	'Высокий (3)'::text public_transport_access_reference,
	public_transport_access_delta,
	ipa,
	'Высокий (3)'::text ipa_reference,
	ipa_delta,
	ita,
	'Высокий (3)'::text ita_reference,
	ita_delta,
	social_access,
	case
		when quater_class in ('Индивидуальная жилая городская среда', 'Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then 'Средняя и выше (2+)'::text
		else 'Высокая (3)'::text
	end social_access_reference,
	social_access_delta,
	entertainment_access,
	case
		when quater_class in ('Индивидуальная жилая городская среда', 'Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then 'Средняя и выше (2+)'::text
		else 'Высокая (3)'::text
	end entertainment_access_reference,
	entertainment_access_delta,
	service_access,
	case
		when quater_class in ('Индивидуальная жилая городская среда', 'Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then 'Средняя и выше (2+)'::text
		else 'Высокая (3)'::text 
	end service_access_reference,
	service_access_delta,
	greenery_access,
	'Должны быть благоустроенные рекреационные природные зоны в пешеходной доступности'::text greenery_access_reference,
	greenery_access_delta,
	odz_area_percent,
	case
		when quater_class = 'Индивидуальная жилая городская среда'
			then '7'::text
		when quater_class = 'Историческая смешанная городская среда'
			then '34'::text
		when quater_class = 'Cоветская периметральная городская среда'
			then '29'::text
		when quater_class in ('Советская малоэтажная разреженная городская среда', 'Современная малоэтажная разреженная городская среда', 'Позднесоветская малоэтажная разреженная городская среда')
			then '10-20'::text
		when quater_class = 'Среднеэтажная микрорайонная городская среда'
			then '20'::text
		when quater_class = 'Многоэтажная микрорайонная городская среда'
			then '16'::text
	end  odz_area_percent_reference,	
	odz_area_percent_delta,
	hazardous_dwelling,
	'отсутствует аварийное жилье'::text hazardous_dwelling_reference,
	hazardous_dwelling_delta,
	negative_factors,
	'отсутствует в пешеходной доступности'::text negative_factors_reference,
	negative_factors_delta,
	far,
	(
		(case when area_ha_delta <> 0 then -1 else 0 end) +
		(case when pop_density_delta <> 0 then -1 else 0 end) + 
		(case when built_density_delta <> 0 then -1 else 0 end) +
		(case when residential_median_level_delta <> 0 then -1 else 0 end) +
		public_transport_access_delta + ipa_delta + ita_delta +
		social_access_delta + entertainment_access_delta +
		service_access_delta + greenery_access_delta + 
		hazardous_dwelling_delta + negative_factors_delta + odz_area_percent_delta + 15
	)::smallint sum_delta, -- суммарная итоговая дельта (от 0 до 15. Больше - лучше)
	geom
from stat2
;

alter table street_classify.quater_stat_verify add primary key(id);
create index on street_classify.quater_stat_verify(id_gis);
create index on street_classify.quater_stat_verify using gist(geom);

comment on table street_classify.quater_stat_verify is 'Целевые параметры сред для id_gis = 1080. Сравнение поквартальных показателей с эталонными
Методика: https://docs.google.com/spreadsheets/d/14Xn4kg7C4M7fj0S57rGpMqY5Ou690lFY-lU3O4A2F1w/edit#gid=871860173';
comment on column street_classify.quater_stat_verify.id is 'Первичный ключ - уникальный id квартала';
comment on column street_classify.quater_stat_verify.id_gis is 'id_gis города';
comment on column street_classify.quater_stat_verify.quater_class is 'Тип городской в квартале';
comment on column street_classify.quater_stat_verify.area_ha is 'Площадь, га';
comment on column street_classify.quater_stat_verify.area_ha_delta is 'Дельта площади (превышение относительно эталонной)';
comment on column street_classify.quater_stat_verify.pop_density is 'Плотность населения, чел./га';
comment on column street_classify.quater_stat_verify.pop_density_delta is 'Дельта плотности населения (превышение относительно эталонной)';
comment on column street_classify.quater_stat_verify.built_density is 'Плотность застройки';
comment on column street_classify.quater_stat_verify.built_density_delta is 'Дельта плотности застройки';
comment on column street_classify.quater_stat_verify.residential_median_level is 'Средняя этажность';
comment on column street_classify.quater_stat_verify.residential_median_level_delta is 'Дельта по средней этажности';
comment on column street_classify.quater_stat_verify.public_transport_access is 'Доступность общественного транспорта';
comment on column street_classify.quater_stat_verify.public_transport_access_delta is 'Дельта доступности общественного транспорта';
comment on column street_classify.quater_stat_verify.ipa is 'Уровень пешеходной связности прилегающей территории';
comment on column street_classify.quater_stat_verify.ipa_delta is 'Дельта уровня пешеходной связности прилегающей территории';
comment on column street_classify.quater_stat_verify.ita is 'Уровень транспортной связности прилегающей территории';
comment on column street_classify.quater_stat_verify.ita_delta is 'Дельта уровня транспортной связности прилегающей территории';
comment on column street_classify.quater_stat_verify.social_access is 'Обеспеченность социальными объектами в пешей доступности';
comment on column street_classify.quater_stat_verify.social_access_delta is 'Дельта обеспеченности социальными объектами в пешей доступности';
comment on column street_classify.quater_stat_verify.entertainment_access is 'Обеспеченность досуговыми объектами в пешей доступности';
comment on column street_classify.quater_stat_verify.entertainment_access_delta is 'Дельта обеспеченности досуговыми объектами в пешей доступности';
comment on column street_classify.quater_stat_verify.service_access is 'Обеспеченность сервисной инфраструктурой в пешей доступности';
comment on column street_classify.quater_stat_verify.service_access_delta is 'Дельта обеспеченности сервисной инфраструктурой в пешей доступности';
comment on column street_classify.quater_stat_verify.greenery_access is 'Обеспеченность озеленёнными территориями в пешей доступности';
comment on column street_classify.quater_stat_verify.greenery_access_delta is 'Дельта обеспеченности озеленёнными территориями в пешей доступности';
comment on column street_classify.quater_stat_verify.hazardous_dwelling is 'Наличие аварийного жилья в квартале';
comment on column street_classify.quater_stat_verify.hazardous_dwelling_delta is 'Дельта от наличия аварийного жилья в квартале';
comment on column street_classify.quater_stat_verify.negative_factors is 'Присутствие негативных антропогенных факторов в пешей доступности';
comment on column street_classify.quater_stat_verify.negative_factors_delta is 'Дельта от присутствия негативных антропогенных факторов в пешей доступности';
--comment on column street_classify.quater_stat_verify.far is 'FAR';
comment on column street_classify.quater_stat_verify.sum_delta is 'Суммарная дельта по всем показателям  (от 0 до 15. Больше - лучше)';
comment on column street_classify.quater_stat_verify.geom is 'Геометрия';


--select * from russia.city where id_gis = 1080



-- Вытаскиваем в excel в удобочитаемом виде
--select
--	id,
--	id_gis "id_gis города",
--	quater_class "Типология кварт.",
--	area_ha "Площадь, га",
--	area_ha_reference "Площадь-целев., га",
--	area_ha_delta "Площадь-дельта, га",
--	pop_density "Плотн. населения, чел./га",
--	pop_density_reference "Плотн. населения-целев., чел./га",
--	pop_density_delta "Плотн. населения-дельта, чел./га",
--	built_density "Плотн. застр. кварт., тыс. м2/га",
--	built_density_reference "Плотн. застр. кварт.-целев., тыс. м2/га",
--	built_density_delta "Плотн. застр. кварт.-дельта, тыс. м2/га",
--	residential_median_level "Ср. этажн. застр., эт.",
--	residential_median_level_reference "Ср. этажн. застр.-целев., эт.",
--	residential_median_level_delta "Ср. этажн. застр.-дельта, эт.",
--	public_transport_access "Ур. доступн. на общ.м трансп.",
--	public_transport_access_reference "Ур. доступн. на общ.м трансп.-целевой",
--	public_transport_access_delta "Ур. доступн. на общ.м трансп.-дельта",
--	ipa "Ур. пешей связн. с прилег. терр.",
--	ipa_reference "Ур. пешей связн. с прилег. терр.-целевой",
--	ipa_delta "Ур. пешей связн. с прилег. терр.- дельта",
--	ita "Ур. трансп. связн. с прилег. терр.",
--	ita_reference "Ур. трансп. связн. с прилег. терр.-целевой",
--	ita_delta "Ур. трансп. связн. с прилег. терр.-дельта",
--	social_access "Обеспеч. соц. объект. в пешей доступн.",
--	social_access_reference "Обеспеч. соц. объект. в пешей доступн.-целев.",
--	social_access_delta "Обеспеч. соц. объект. в пешей доступн.-дельта",
--	entertainment_access "Обеспеч. досуг. объект. в пешей доступн.",
--	entertainment_access_reference "Обеспеч. досуг. объект. в пешей доступн.-целев.",
--	entertainment_access_delta "Обеспеч. досуг. объект. в пешей доступн.-дельта",
--	service_access "Обеспеч. сервис. объект. в пешей доступн.",
--	service_access_reference "Обеспеч. сервис. объект. в пешей доступн.-целев.",
--	service_access_delta "Обеспеч. сервис. объект. в пешей доступн.-дельта",
--	greenery_access "Обеспеч. доступ. к озелен. терр.",
--	greenery_access_reference "Обеспеч. доступ. к озелен. терр.-целев.",
--	greenery_access_delta "Обеспеч. доступ. к озелен. терр.-дельта",
--	odz_area_percent "Доля помещ. общ.-делов. инфрастр.",
--	odz_area_percent_reference "Доля помещ. общ.-делов. инфрастр.-целев.",
--	odz_area_percent_delta "Доля помещ. общ.-делов. инфрастр.-дельта",
--	hazardous_dwelling "Налич. аварийн. жилья",
--	hazardous_dwelling_reference "Налич. аварийн. жилья-целевое",
--	hazardous_dwelling_delta "Налич. аварийн. жилья-дельта",
--	negative_factors "Негативн. антропоген. фактор. в пешей доступн.",
--	negative_factors_reference "Негативн. антропоген. фактор. в пешей доступн.-целевое",
--	negative_factors_delta "Негативн. антропоген. фактор. в пешей доступн.-дельта",
--	far "FAR-суммарная площадь футпринта",
--	sum_delta "Суммарная дельта по всем показателям (от -14 до 0, больше-лучше)"
--from street_classify.quater_stat_verify

