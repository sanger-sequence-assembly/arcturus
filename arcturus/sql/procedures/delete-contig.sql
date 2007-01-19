DELIMITER $

DROP PROCEDURE IF EXISTS procDeleteContig$

CREATE PROCEDURE procDeleteContig(IN contigId INT)
  MODIFIES SQL DATA
BEGIN
  DECLARE intContigExists INT DEFAULT 0;

  select count(*) into intContigExists from CURRENTCONTIGS where contig_id = contigId;

  IF (intContigExists = 1) THEN
    delete from TAG2CONTIG where contig_id = contigId;
    delete from CONTIGTRANSFERREQUEST where contig_id = contigId;
    delete from CONSENSUS where contig_id = contigId;

    delete from MAPPING,SEGMENT using MAPPING left join SEGMENT using(mapping_id) where contig_id = contigId;
    delete from C2CMAPPING,C2CSEGMENT using C2CMAPPING left join C2CSEGMENT using(mapping_id) where contig_id = contigId;

    delete from CONTIG where contig_id = contigId;
  END IF;
END;$

DELIMITER ;
