select READINFO.read_id,asped
  from READINFO left join (SEQ2READ, MAPPING, CURRENTCONTIGS)
  on (READINFO.read_id = SEQ2READ.read_id
  and SEQ2READ.seq_id = MAPPING.seq_id
  and MAPPING.contig_id = CURRENTCONTIGS.contig_id)
  where CURRENTCONTIGS.contig_id is null;