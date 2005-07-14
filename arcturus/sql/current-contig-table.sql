create temporary table currentcontigs as
select CONTIG.contig_id,nreads,ncntgs,length,created,updated,project_id
  from CONTIG left join C2CMAPPING
  on CONTIG.contig_id = C2CMAPPING.parent_id
  where C2CMAPPING.parent_id is null;
