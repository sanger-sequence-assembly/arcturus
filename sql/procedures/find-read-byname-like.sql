DELIMITER $

DROP PROCEDURE IF EXISTS procFindReadByNameLike$

CREATE PROCEDURE procFindReadByNameLike(IN namelike VARCHAR(30))
  READS SQL DATA
  SQL SECURITY INVOKER
BEGIN
  select readname,READINFO.read_id,
    CURRENTCONTIGS.contig_id,gap4name,nreads,length,CURRENTCONTIGS.created,CURRENTCONTIGS.updated,
    PROJECT.name as projectname,
    MAPPING.seq_id,mapping_id,cstart,cfinish,direction
  from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS,PROJECT
  where READINFO.readname like namelike
    and READINFO.read_id = SEQ2READ.read_id
    and SEQ2READ.seq_id = MAPPING.seq_id
    and MAPPING.contig_id = CURRENTCONTIGS.contig_id
    and CURRENTCONTIGS.project_id = PROJECT.project_id;
END;$

DELIMITER ;
