
--create a new project you must create some people and an assembly


insert into ASSEMBLY values (1, 'TRICHURIS MURIS', 0, 'The Sanger Institute', 0, 'other', now(), now(), 'arcturus', 'Added for initial data load');
select * from ASSEMBLY;

insert into USER(username, role) values ('kt6',  'administrator');
insert into USER(username, role) values ('sn5',  'administrator');
insert into USER(username, role) values ('rcc',  'team leader');
 
select * from USER;

insert into PROJECT values(1, 1, 'BIN', now(), NULL, NULL, NULL, now(), 'arcturus', 'created via database', 'in shotgun', ':ASSEMBLY:/illumina/split/BIN');
insert into PROJECT values(2, 1, 'PROBLEMS', now(), NULL, NULL, NULL, now(), 'arcturus', 'created via database', 'in shotgun', NULL);

select * from PROJECT;

insert into IMPORTEXPORT values ();
select * from IMPORTEXPORT;

