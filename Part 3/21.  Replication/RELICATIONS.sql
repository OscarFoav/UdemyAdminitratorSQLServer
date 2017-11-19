create database foods
go


use foods
go

create table fruits
(fruitsid int primary key, --<< primary key created for fruits table
fruits varchar(20))

insert into fruits (fruitsid,fruits)
values (1,'apple'),(2,'plum'),(3,'orange'),(4,'bananas'),(5,'melon')

select * from fruits

use foods
go

create table veggies
(                              --<< no primary key created for veggies
veggies varchar(20))                   


insert into veggies (veggies)
values('tomato'),('carrot'),('onion'),('lettuce')

select * from veggies

--insert data into table and view the data

use foods
go

select * from fruits

insert into fruits (fruitsid,fruits)
values (6,'strawberry')


insert into fruits (fruitsid,fruits)
values (9,'blueberry')

--delete from fruits where fruitsid in (6,7)
