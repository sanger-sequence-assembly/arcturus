DELIMITER $

DROP PROCEDURE IF EXISTS procFreeReads$

CREATE PROCEDURE procFreeReads()
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  create temporary table CURREAD
    (read_id integer not null,
     seq_id integer not null,
     key (read_id))
  as select READINFO.read_id,SEQ2READ.seq_id
  from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS
  where READINFO.read_id = SEQ2READ.read_id
    and SEQ2READ.seq_id = MAPPING.seq_id
    and MAPPING.contig_id = CURRENTCONTIGS.contig_id;

  select READINFO.read_id,readname from READINFO left join CURREAD using(read_id) where seq_id is null;

  drop temporary table CURREAD;
END;$

DELIMITER ;
