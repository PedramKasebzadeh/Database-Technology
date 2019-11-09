create table test2(id int);
show tables;
show table status;
desc jbemployee;
show tables;
-- show company_schema.sql;
desc jbdept;
-- first question 
select * from jbemployee;
-- second assignment 
Select name from jbdept order by name;-- ** distinct removes duplicates** 
-- question 3
show tables;
desc jbparts;
select name from jbparts where qoh=0;
-- 4
desc jbemployee;
select name from jbemployee where  salary between 9000 and 10000;
-- 5 
desc jbemployee;
select name,startyear-birthyear from jbemployee;
-- 6 
select name from jbemployee where SUBSTRING_INDEX(name,',',1) like 'son ';
-- 7 
select name from jbitem where supplier in (select id from jbsupplier where name = 'Fisher-Price');
-- 8 
select jbitem.name from jbitem join jbsupplier on jbitem.supplier=jbsupplier.id where jbsupplier.name= 'Fisher-Price';

-- 9 
select name from jbcity where id in (select city from jbsupplier);

-- 10 

select name,color from jbparts where weight > (select weight from jbparts where name = 'card reader');
-- 11

select E.name,E.color from jbparts E inner join jbparts S on
 E.weight>S.weight where S.name = 'card reader'; 
 
 






