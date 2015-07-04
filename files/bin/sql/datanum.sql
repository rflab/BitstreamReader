.header on
.mode column
.width 60 10
.open test.db
select name, count(*) from bitstream group by name;

