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

create temporary table currentcontigs as
	select CONTIG.contig_id,nreads,ncntgs,length,created,updated,project_id
	from CONTIG left join C2CMAPPING
	on CONTIG.contig_id = C2CMAPPING.parent_id
	where C2CMAPPING.parent_id is null;

create temporary table curseqs (
	seq_id mediumint unsigned not null,
	contig_id mediumint unsigned not null,
	index(contig_id),
	index(seq_id));

insert into curseqs(seq_id,contig_id)
	select seq_id,MAPPING.contig_id from currentcontigs left join MAPPING using(contig_id);

create temporary table curreads (
	read_id mediumint unsigned not null,
	seq_id mediumint unsigned not null,
	contig_id mediumint unsigned not null,
	index(read_id));

insert into curreads(read_id,seq_id,contig_id)
	select read_id,SEQ2READ.seq_id,contig_id from curseqs left join SEQ2READ using(seq_id);

create temporary table badreads as
	select read_id,count(*) as hits from curreads group by read_id having hits > 1;

select * from badreads;
