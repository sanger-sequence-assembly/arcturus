DROP TABLE CONSENSUS;

CREATE TABLE `CONSENSUS` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `sequence` longblob,
  `quality` longblob,
  PRIMARY KEY  (`contig_id`)
) TYPE=MyISAM;
