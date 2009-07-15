select distinct CA.contig_id,CA.gap4name,CA.nreads,CA.ncntgs,CA.length,CA.created,CA.updated
   from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
   on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
   where CA.created < @cutoff
     and (C2CMAPPING.parent_id is null or CB.created > @cutoff)
