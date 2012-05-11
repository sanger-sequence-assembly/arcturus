DROP VIEW IF EXISTS FREEREADS;

CREATE
  SQL SECURITY INVOKER
  VIEW FREEREADS
  AS select READINFO.read_id,readname,status
  from READINFO left join (SEQ2READ, MAPPING, CURRENTCONTIGS)
  on (READINFO.read_id = SEQ2READ.read_id
  and SEQ2READ.seq_id = MAPPING.seq_id
  and MAPPING.contig_id = CURRENTCONTIGS.contig_id)
  where CURRENTCONTIGS.contig_id is null;