create table ONLINE_DATA as
select * from online_data
where id_online in (
  select distinct id_online from tracking.project
  where project_type = 5 or projectname like 'zH%' or projectname like 'zF%'
)