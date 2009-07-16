alter table ALIGN2SCF
	modify startinseq int not null,
	modify startinscf int not null,
	modify length int not null;

alter table CLONEVEC
	modify cvleft int not null,
	modify cvright int not null;

alter table QUALITYCLIP
	modify qleft int not null,
	modify qright int not null;

alter table READTAG
	modify pstart int not null,
	modify pfinal int not null;

alter table SEGMENT
	modify rstart int not null,
	modify length int not null;

alter table SEQUENCE
	modify sequence mediumblob not null,
	modify quality mediumblob not null,
	modify seqlen int not null;

alter table SEQVEC
	modify svleft int not null,
	modify svright int not null;
