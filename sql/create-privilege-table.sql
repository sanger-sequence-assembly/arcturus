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

DROP TABLE IF EXISTS `PRIVILEGE`;

CREATE TABLE `PRIVILEGE` (
  `username` char(8) NOT NULL,
  `privilege` char(32) NOT NULL,
  UNIQUE KEY (`username`,`privilege`),
  KEY (`username`)
);

insert into PRIVILEGE(username,privilege)
   select username,'move_any_contig' from USER where can_move_any_contig = 'Y';

insert into PRIVILEGE(username,privilege)
   select username,'create_project' from USER where can_create_new_project = 'Y';

insert into PRIVILEGE(username,privilege)
   select username,'assign_project' from USER where can_assign_project = 'Y';

insert into PRIVILEGE(username,privilege)
   select username,'grant_privileges' from USER where can_grant_privileges = 'Y';

insert into PRIVILEGE(username,privilege) select distinct(username),'lock_project' from USER;
