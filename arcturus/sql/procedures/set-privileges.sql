DELIMITER $

DROP PROCEDURE IF EXISTS grantBasicPermissions$

CREATE PROCEDURE grantBasicPermissions(IN databaseName VARCHAR(30), IN user VARCHAR(30))
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE
	ON databaseName.* TO user;
END;$

DROP PROCEDURE IF EXISTS grantTableChangePermissions$

CREATE PROCEDURE grantTableChangePermissions(IN databaseName VARCHAR(30), IN user VARCHAR(30))
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  GRANT CREATE, DROP, INDEX, ALTER ON databaseName.* TO user;
END;$

DROP PROCEDURE IF EXISTS grantViewPermissions$

CREATE PROCEDURE grantViewPermissions(IN databaseName VARCHAR(30), IN user VARCHAR(30))
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  GRANT CREATE VIEW, SHOW VIEW ON databaseName.* TO user;
END;$

DROP PROCEDURE IF EXISTS grantProcedurePermissions$

CREATE PROCEDURE grantProcedurePermissions(IN databaseName VARCHAR(30), IN user VARCHAR(30))
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  GRANT CREATE ROUTINE, ALTER ROUTINE ON databaseName.* TO user;
END;$

DROP PROCEDURE IF EXISTS procSetPrivileges$

CREATE PROCEDURE procSetPrivileges(IN databaseName VARCHAR(30))
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  call grantBasicPermissions(databaseName,       'arcturus');

  call grantBasicPermissions(databaseName,       'arcturus_dba');
  call grantTableChangePermissions(databaseName, 'arcturus_dba');
  call grantViewPermissions(databaseName,        'arcturus_dba');
  call grantProcedurePermissions(databaseName,   'arcturus_dba');
END;$

DELIMITER ;
