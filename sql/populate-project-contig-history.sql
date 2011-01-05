-- populate_project_contig_history.sql
-- used to populate PROJECT_CONTIG_HISTORY

-- for all projects in the database

insert into PROJECT_CONTIG_HISTORY (
project_id, 
statsdate, 
total_contigs, 
total_reads,
total_contig_length,
mean_contig_length, 
stddev_contig_length, 
max_contig_length, 
median_contig_length)
select 
P.project_id, 
now(),
count(*) as contigs,
sum(C.nreads),
sum(C.length),
round(avg(C.length)),
round(std(C.length)),
max(C.length), 
'0'
from CONTIG as C,PROJECT as P  where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now()  and CA.nreads > 1 and CA.length >= 0 and (C2CMAPPING.parent_id is null  or CB.created > now()-1))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id;

-- for each project

--select project_id, count(*) as contigs from CONTIG group by project_id;
