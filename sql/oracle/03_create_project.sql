create table PROJECT as
select * from tracking.project
where id_online in (select distinct id_online from ONLINE_DATA)