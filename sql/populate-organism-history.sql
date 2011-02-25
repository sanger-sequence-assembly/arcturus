-- populate_organism_history.sql
-- used to populate ORGANISM_HISTORY

-- for all projects in the database

select sum(nreads) as reads_in_contigs
from CONTIG C
where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where date(CA.created) < date(now())-1 and (C2CMAPPING.parent_id is null  or date(CB.created) > date(now())-1));

-- update the total reads

select count(*) as total_reads from READINFO;

-- update the free reads


-- update the asped_reads

select count(*) as asped_reads from READINFO where asped is not null )
where statsdate = date(now())-1;

-- update the next_gen_reads


