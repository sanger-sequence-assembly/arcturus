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

create temporary table currentcontigs (
  contig_id mediumint unsigned not null,
  gap4name binary(32) not null,
  nreads mediumint unsigned not null,
  ncntgs mediumint unsigned not null,
  length mediumint unsigned not null,
  created datetime not null,
  updated datetime not null,
  project_id int unsigned not null,
  primary key (contig_id),
  unique key (gap4name),
  key (project_id)
);

insert into currentcontigs(contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id)
select CONTIG.contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id
  from CONTIG left join C2CMAPPING
  on CONTIG.contig_id = C2CMAPPING.parent_id
  where C2CMAPPING.parent_id is null;

select gap4name,MAPPING.contig_id,readname,cstart,cfinish,direction,PROJECT.name
  from currentcontigs,MAPPING,SEQ2READ,READINFO,PROJECT
  where currentcontigs.contig_id = MAPPING.contig_id
    and MAPPING.seq_id = SEQ2READ.seq_id
    and SEQ2READ.read_id = READINFO.read_id
    and currentcontigs.project_id = PROJECT.project_id
    order by MAPPING.contig_id asc,cstart asc;
