CREATE
  SQL SECURITY INVOKER
  VIEW CURRENTCONTIGS
  AS SELECT CONTIG.contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id
  FROM CONTIG LEFT JOIN C2CMAPPING
  ON CONTIG.contig_id = C2CMAPPING.parent_id
  WHERE C2CMAPPING.parent_id IS NULL;
