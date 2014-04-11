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

create temporary table oldc2cmapping (
	contig_id mediumint unsigned not null,
	parent_id mediumint unsigned not null,
	 index (parent_id),
	 index (contig_id));

insert into oldc2cmapping(parent_id,contig_id)
	 select C2CMAPPING.contig_id,parent_id
	 from C2CMAPPING left join CONTIG using(contig_id)
	 where created < @cutoff;

create temporary table oldcontigs as
select CONTIG.contig_id,nreads,ncntgs,length,created,updated,project_id
  from CONTIG left join oldc2cmapping
  on CONTIG.contig_id = oldc2cmapping.parent_id
  where oldc2cmapping.parent_id is null and created < @cutoff;
