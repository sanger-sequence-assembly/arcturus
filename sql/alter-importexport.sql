alter table IMPORTEXPORT add column starttime datetime null;
alter table IMPORTEXPORT change date endtime datetime;
update IMPORTEXPORT set starttime = date(endtime);
