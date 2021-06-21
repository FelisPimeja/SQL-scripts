update vk_user_info_2020
	set birth_date = replace(birth_date, '-02-29', '-02-28')
	where birth_date like '%-02-29';
update vk_user_info_2020
	set birth_date = null
	where birth_date = '0000-00-00';