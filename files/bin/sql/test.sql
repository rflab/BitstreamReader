.header on
.mode column
.width 10 10 10 10
.open test.db

begin;

drop table if exists value_table;
drop table if exists offset_table;
drop table if exists name_table;

create table value_table (
	id        integer primary key,
	name_id   integer,
	value     text);

create table offset_table (
	id        integer primary key,
	byte      integer,
	bit       integer);

create table name_table(
	name_id   integer primary key,
	name      text,
	size      integer);


insert into name_table values(1, "A", 4);
insert into name_table values(2, "B", 8);
insert into name_table values(3, "C", 16);

insert into offset_table values(1, 0, 0);
insert into value_table  values(1, 1, 100);

insert into offset_table values(2, 4, 0);
insert into value_table  values(2, 1, 200);

insert into offset_table values(3, 8, 0);
insert into value_table  values(3, 2, 300);

insert into offset_table values(4, 16, 0);
insert into value_table  values(4, 3, 400);

commit;

select id, n.name, value, n.size
from value_table v
left join name_table n on v.name_id = n.name_id;

create view test_view as select id, name, value, size
from value_table v
left join name_table n on v.name_id = n.name_id;

-- select * from name_table;
-- select * from offset_table;
-- select * from value_table;
select * from test_view;

drop view test_view;

-- select name, count(*) from bitstream group by name;

