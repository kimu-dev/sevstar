/*
Задание на должность SQL программиста.

Даны таблицы:
Задания. Хранит идентификатор, наименование задания и ссылку на исполнителя.
works (id integer, name text, executor integer)

Исполнители. Идентификатор и имя исполнителя.
executors (id integer, name text)

Состояния заданий. Хранит историю состояний задания. Для каждого задания есть хотя бы
одна запись.
work_statuses (work integer, state integer, datetime timestamp)
state 0 - новое, 1 — принято к исполнению, 2 — выполнено

Статистика выполнения заданий по исполнителям. Хранит начало и конец периода,
количество выполненных заданий, количество принятых к исполнению заданий, количество
новых заданий и метка времени создания записи.
executors_stats (period_start date, period_stop date, done_works integer, current_works integer,
new_works integer, datetime timestamp)

Примечания:
Задание находится в статусе выполнено означает, что последняя запись в таблице
work_statuses для этого задания имеет пометку state == 2 — выполнено. Это же справедливо и
для «новое» и «принято к исполнению».
В неком промежутке времени задание может менять свой статус несколько раз. Т.е. для
некого заданного периода, задание может иметь, а может не иметь смены состояний. И для
получения статуса в заданном периоде нужно получить последнее, но не старше верхней
границы периода.

Задачи:
1) На процедурном SQL написать хранимую функцию, которая для заданного периода
[period_start date, period_stop date] вернёт количество заданий в статусах выполнено,
принято к исполнению и новых. 
2) Сохранить данные полученные от функции в первом задании в таблицу executors_stats.
3) Сделать SQL запросы для отчётов по исполнителю (произвольному):
Вывести все задания в статусе новое или принято к исполнению.
Вывести последние 5 выполненных заданий.
Вывести последнею запись (по datetime) из таблицы executors_stats, дополнительно получить
среднее количество выполненных заданий за один день.
*/

/*
drop table works cascade;
drop table executors cascade;
drop table work_statuses cascade;
drop table executors_stats cascade;

drop sequence "public"."seq_works" cascade;
drop sequence "public"."seq_executors" cascade;
*/

-- Функция для генерации строк(для заполнения таблиц).
create or replace function random_string(num integer, chars text default '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz') returns text as 
$$
declare
res_str text := '';
begin
	if num < 1 then
		raise exception 'invalid length';
 	end if;
 	for __ IN 1..num 
 	loop
		res_str := res_str || substr(chars, floor(random() * length(chars))::int + 1, 1);
 	end loop;
	return res_str;
end;
$$ language plpgsql;


/*
Задания. Хранит идентификатор, наименование задания и ссылку на исполнителя.
works (id integer, name text, executor integer)
 */
create table works (
	id int,
	"name" text,
	executor int not null,
	constraint pk_id_works_pkey primary key (id),
	constraint fk_works_executor foreign key (executor) references executors(id)
);

create sequence "public"."seq_works" increment 1 start 1;
alter table works alter column id set default nextval('"public"."seq_works"');
alter sequence "public"."seq_works" restart with 1;

do $$
declare
name_works varchar(10);
executor_id int;
col bigint := 1;

begin 
	while col <= 30
	loop	
		name_works := random_string(10);
		executor_id := random_string(2, '0123456789');
		if executor_id in (select id from executors) then
			insert into works ("name", executor) values (name_works, executor_id);
			col := col + 1;
		end if;
	end loop;
end;
$$ language plpgsql;

select * from works;
truncate works cascade;

/*
Исполнители. Идентификатор и имя исполнителя.
executors (id integer, name text)
 */
create table executors (
	id int,
	"name" text,
	constraint pk_id_executors primary key (id)
);

create sequence "public"."seq_executors" increment 1 start 1;
alter table executors alter column id set default nextval('"public"."seq_executors"');
alter sequence "public"."seq_executors" restart with 1;

do $$
declare
name_executors varchar(10);
col bigint := 1;

begin 
	while col <= 10
	loop	
		name_executors := random_string(10);
		insert into executors ("name") values (name_executors);
		col := col + 1;
	end loop;
end;
$$ language plpgsql;

select * from executors;
truncate executors cascade;



/*
Состояния заданий. Хранит историю состояний задания. Для каждого задания есть хотя бы
одна запись.
work_statuses (work integer, state integer, datetime timestamp)
state 0 - новое, 1 — принято к исполнению, 2 — выполнено
 */
create table work_statuses (
	"work" int not null,
	state int,
	datetime timestamp default now() not null,
	constraint fk_work_statuses_work foreign key ("work") references works(id)
);

do $$
declare
work_id int;
state_name int;
col bigint := 1;
inter bigint := 1;

begin 
	while col <= 90
	loop	
		work_id := random_string(2, '0123456789');
		state_name := random_string(1, '012');
		if work_id in (select id from works) then
			insert into work_statuses ("work", state, datetime) values (work_id, state_name, date '2022-01-01' + interval '1 hour' * inter);
			col := col + 1;
			inter := inter + 3;
		end if;
	end loop;
end;
$$ language plpgsql;

select * from work_statuses;
truncate work_statuses cascade;

/*
Статистика выполнения заданий по исполнителям. Хранит начало и конец периода,
количество выполненных заданий, количество принятых к исполнению заданий, количество
новых заданий и метка времени создания записи.
executors_stats (period_start date, period_stop date, done_works integer, current_works integer,
new_works integer, datetime timestamp)
 */
create table public.executors_stats (
	period_start date,
	period_stop date,
	done_works int4 not null,
	current_works int4 not null,
	new_works int4 not null,
	datetime timestamp default now() not null,
	constraint fk_executors_stats_current_works foreign key (current_works) references works(id),
	constraint fk_executors_stats_done_works foreign key (done_works) references works(id),
	constraint fk_executors_stats_new_works foreign key (new_works) references works(id)
);

-- На процедурном SQL написать хранимую функцию, которая для заданного периода [period_start date, period_stop date] вернёт количество заданий в статусах выполнено, принято к исполнению и новых. 
create or replace function return_works_count(period_start date, period_stop date) returns refcursor as 
$$
declare 
ref_cursor refcursor := 'ref_cursor';
begin
	open ref_cursor for
		with cte as (select *, row_number() over(partition by work order by datetime) as rows_work from work_statuses where datetime between period_start and period_stop),
	 		 cte1 as (select count(rows_work) as count_w, work from cte group by work),
	 		 cte2 as (select count(cte.work) as count_n from cte, cte1 where cte1.count_w = cte.rows_work and cte1.work = cte.work and cte.state = 0),
	 		 cte3 as (select count(cte.work) as count_c from cte, cte1 where cte1.count_w = cte.rows_work and cte1.work = cte.work and cte.state = 1),
	 		 cte4 as (select count(cte.work) as count_d from cte, cte1 where cte1.count_w = cte.rows_work and cte1.work = cte.work and cte.state = 2)
		select period_start, period_stop, count_n, count_c, count_d from cte2, cte3, cte4;
	return ref_cursor;	
end;
$$ language plpgsql;

-- Выводим результат работы функции:
begin transaction;
select return_works_count('2022-01-03', '2022-01-11'); 
fetch all in ref_cursor;
commit transaction;

-- Сохранить данные полученные от функции в первом задании в таблицу executors_stats.
do $$
declare
p_refcursor refcursor;
p_start date;
p_stop date;
c_nw int;
c_cw int;
c_dw int;
begin
	select return_works_count('2022-01-03', '2022-01-06') into p_refcursor;
	fetch from p_refcursor into p_start, p_stop, c_nw, c_cw, c_dw;
--	raise notice 'проверка: %', p_start||' '||p_stop||' '||c_nw||' '||c_cw||' '||c_dw; 
	insert into executors_stats (period_start, period_stop, done_works, current_works, new_works) values (p_start, p_stop, c_nw, c_cw, c_dw);
end;
$$ language plpgsql;

select * from executors_stats;

-- Вывести все задания в статусе новое или принято к исполнению.
with cte as (select e.id as id_executor, e.name as name_executor, w.id as id_work, w.name as name_work, ws.state as state_work, ws.work, ws.datetime as dt, 
row_number() over(partition by work order by ws.datetime) as rows_work from work_statuses ws
inner join works w on w.id = ws.work
inner join executors e on e.id = w.executor 
where e.name ilike '7rQd76vI8c'),
	 cte1 as (select count(rows_work) as count_w, id_work from cte group by id_work)
select cte.name_work from cte, cte1 where cte1.count_w = cte.rows_work and cte1.id_work = cte.id_work and cte.state_work in (0, 1);

-- Вывести последние 5 выполненных заданий.
with cte as (select e.id as id_executor, e.name as name_executor, w.id as id_work, w.name as name_work, ws.state as state_work, ws.work, ws.datetime as dt, 
row_number() over(partition by work order by ws.datetime) as rows_work from work_statuses ws
inner join works w on w.id = ws.work
inner join executors e on e.id = w.executor 
where e.name ilike '7rQd76vI8c'),
	 cte1 as (select count(rows_work) as count_w, id_work from cte group by id_work)
select cte.name_work from cte, cte1 where cte1.count_w = cte.rows_work and cte1.id_work = cte.id_work and cte.state_work = 2 order by cte.dt desc limit 5;

-- Вывести последнею запись (по datetime) из таблицы executors_stats, дополнительно получить среднее количество выполненных заданий за один день. 
-- Вариант 1:
with cte as (select (date_trunc('day', period_stop) - date_trunc('day', period_start)) as count_day, * from executors_stats 
order by datetime desc
limit 1)
select round((done_works / (extract(epoch from count_day)/86400))::int) as avg_done_for_day, period_start, period_stop, done_works, current_works, new_works from cte; -- простое округление

with cte as (select (date_trunc('day', period_stop) - date_trunc('day', period_start)) as count_day, * from executors_stats 
order by datetime desc
limit 1)
select round((done_works / (extract(epoch from count_day)/86400))::numeric) as avg_done_for_day, period_start, period_stop, done_works, current_works, new_works from cte; -- математическое округление

-- Вариант 2:
select round(done_works / (period_stop - period_start)::int) as avg_done_for_day, * from executors_stats 
order by datetime desc
limit 1; -- простое округление

select round(done_works / (period_stop - period_start)::numeric) as avg_done_for_day, * from executors_stats 
order by datetime desc
limit 1; -- математическое округление





