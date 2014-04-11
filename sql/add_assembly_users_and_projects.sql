-- Copyright (c) 2001-2014 Genome Research Ltd.
--
-- Authors: David Harper
--          Ed Zuiderwijk
--          Kate Taylor
--
-- This file is part of Arcturus.
--
-- Arcturus is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program. If not, see <http://www.gnu.org/licenses/>.


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

