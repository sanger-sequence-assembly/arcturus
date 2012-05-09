select CONTIG.contig_id,nreads,length,updated,project_id
  from CONTIG left join C2CMAPPING
  on CONTIG.contig_id = C2CMAPPING.parent_id
  where C2CMAPPING.parent_id is null
  order by length asc;
