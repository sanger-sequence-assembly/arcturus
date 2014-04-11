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

alter table ALIGN2SCF
	modify startinseq int not null,
	modify startinscf int not null,
	modify length int not null;

alter table CLONEVEC
	modify cvleft int not null,
	modify cvright int not null;

alter table QUALITYCLIP
	modify qleft int not null,
	modify qright int not null;

alter table READTAG
	modify pstart int not null,
	modify pfinal int not null;

alter table SEGMENT
	modify rstart int not null,
	modify length int not null;

alter table SEQUENCE
	modify sequence mediumblob not null,
	modify quality mediumblob not null,
	modify seqlen int not null;

alter table SEQVEC
	modify svleft int not null,
	modify svright int not null;
