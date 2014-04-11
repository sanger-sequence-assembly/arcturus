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

-- populate_organism_history.sql
-- used to populate ORGANISM_HISTORY

-- for all projects in the database

insert into ORGANISM_HISTORY (
organism,
statsdate, 
total_reads,
reads_in_contigs,
free_reads,
asped_reads,
next_gen_reads)
select 
'TESTRATTI',
date(now())-1,
9999,
sum(C.nreads),
9999,
9999,
9999
from CONTIG as C,PROJECT as P  
where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where date(CA.created) < date(now())-1  and CA.nreads > 1 and CA.length >= 0 and (C2CMAPPING.parent_id is null  or date(CB.created) > date(now())-2))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id;

-- update the total reads

update ORGANISM_HISTORY 
set total_reads = (select count(*) from READINFO )
where statsdate = date(now())-1;

-- update the free reads

update ORGANISM_HISTORY 
set free_reads =  total_reads - reads_in_contigs
where statsdate = date(now())-1;

-- update the asped_reads

update ORGANISM_HISTORY 
set asped_reads =  (select count(*) from READINFO where asped is not null )
where statsdate = date(now())-1;

-- update the next_gen_reads

update ORGANISM_HISTORY 
set next_gen_reads = total_reads - asped_reads 
where statsdate = date(now())-1;

