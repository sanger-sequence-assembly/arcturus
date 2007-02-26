DROP TABLE IF EXISTS `PRIVILEGE`;

CREATE TABLE `PRIVILEGE` (
  `username` char(8) NOT NULL,
  `privilege` char(32) NOT NULL,
  UNIQUE KEY (`username`,`privilege`),
  KEY (`username`)
);

insert into PRIVILEGE(username,privilege)
   select username,'move_any_contig' from USER where can_move_any_contig = 'Y';

insert into PRIVILEGE(username,privilege)
   select username,'create_project' from USER where can_create_new_project = 'Y';

insert into PRIVILEGE(username,privilege)
   select username,'assign_project' from USER where can_assign_project = 'Y';

insert into PRIVILEGE(username,privilege)
   select username,'grant_privileges' from USER where can_grant_privileges = 'Y';

insert into PRIVILEGE(username,privilege) select distinct(username),'lock_project' from USER;
