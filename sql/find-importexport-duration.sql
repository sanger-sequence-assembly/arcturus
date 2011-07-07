--mysql> set @project = 'EMU14.A';  (for export) or .0 for import
--mysql> set @date = '2011-06-24';
--
select file, action, date(starttime) as date, time(starttime) as start, time(endtime) as end, timediff(time(endtime), time(starttime)) as duration 
from IMPORTEXPORT 
where starttime > @date and file like concat('%', @project);
