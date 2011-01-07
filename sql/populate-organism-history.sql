-- populate_organism_history.sql
-- used to populate ORGANISM_HISTORY

-- for all projects in the database

insert into ORGANISM_HISTORY (
organism,
statsdate, 
total_reads,
reads_in_contigs,
free_reads)
select 
'TESTRATTI',
now(),
9999,
sum(C.nreads),
9999
from CONTIG as C,PROJECT as P  
where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now()  and CA.nreads > 1 and CA.length >= 0 and (C2CMAPPING.parent_id is null  or CB.created > now()-1))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id;

-- update the total reads

update ORGANISM_HISTORY 
set total_reads = (select count(*) from READINFO) 
where free_reads = 9999;

-- update the free reads

update ORGANISM_HISTORY 
set free_reads =  total_reads - reads_in_contigs
where free_reads = 9999;

