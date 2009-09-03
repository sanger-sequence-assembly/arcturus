select CA.contig_id,PA.name,CA.nreads,CA.length,CA.created,CB.contig_id,PB.name,CB.nreads,CB.length,CB.created
   from CONTIG as CA left join (C2CMAPPING M,CONTIG as CB, PROJECT PA,PROJECT PB)
   on (CA.contig_id = M.parent_id and M.contig_id = CB.contig_id)
   where CA.created < '2009-08-21'
   and (M.parent_id is null or CB.created > '2009-08-21')
   and CA.project_id=PA.project_id
   and CB.project_id=PB.project_id
   and PA.name like 'BIG2P_'
   order by PA.name asc,CA.length desc,CB.length desc