package uk.ac.sanger.arcturus.database;

import java.sql.*;
import javax.sql.*;

public class ArcturusDatabase {
    public static final int MYSQL = 1;
    public static final int ORACLE = 2;

    protected DataSource ds;
    protected String description;
    protected String name;

    /**
     * Creates a new ArcturusDatabase object from a DataSource, a description
     * and a name.
     *
     * @param ds the DataSource which will be used to obtain JDBC Connection
     * objects.
     *
     * @param description a text description of the species which this database
     * contains.
     *
     * @param name the short name for this database.
     */

    public ArcturusDatabase(DataSource ds, String description, String name) 
	throws SQLException {
	this.ds = ds;
	this.description = description;
	this.name = name;

	createManagers();
    }

    /**
     * Returns the DataSource which was used to create this object.
     *
     * @return the DataSource which was used to create this object.
     */

    public DataSource getDataSource() { return ds; }

    /**
     * Returns the description which was used to create this object.
     *
     * @return the description which was used to create this object.
     */

    public String getDescription() { return description; }

    /**
     * Returns the name which was used to create this object.
     *
     * @return the name which was used to create this object.
     */

    public String getName() { return name; }

    /**
     * Establishes a JDBC connection to a database, using the parameters stored in
     * this object's DataSource, and the specified username and password.
     *
     * @return a java.sql.Connection which can be used to communicate with the database.
     *
     * @throws SQLException in the event of an error when establishing a connection with
     * the database.
     */

    public Connection getConnection() throws SQLException {
	return  (ds == null) ? null : ds.getConnection();
    }

    /**
     * Establishes a JDBC connection to a database, using the parameters stored in
     * this object's DataSource.
     *
     * @param username the username which should be used to connect to the database.
     * This overrides the username, if any, in the DataSource object.
     *
     * @param password the pasword  which should be used to connect to the database.
     * This overrides the password, if any, in the DataSource object.
     *
     * @return a java.sql.Connection which can be used to communicate with the database.
     *
     * @throws SQLException in the event of an error when establishing a connection with
     * the database.
     */

    public Connection getConnection(String username, String password) throws SQLException {
	return (ds == null) ? null : ds.getConnection(username, password);
    }

    /**
     * Creates a DataSource object which represents a connection to a MySQL database.
     *
     * @param hostname the hostname of the MySQL instance.
     *
     * @param port the port number on which the MySQL instance is listening for TCP/IP
     * connections.
     *
     * @param database the name of the MySQL database.
     *
     * @param username the default username.
     *
     * @param password the default password.
     *
     * @return a DataSource object which can be used to establish a connection to the
     * MySQL database.
     *
     * @throws SQLException in the event of an error.
     */

    public static DataSource createMysqlDataSource(String hostname, int port, String database,
						   String username, String password)
	throws SQLException {
	com.mysql.jdbc.jdbc2.optional.MysqlDataSource mysqlds =
	    new com.mysql.jdbc.jdbc2.optional.MysqlDataSource();

	mysqlds.setServerName(hostname);
	mysqlds.setDatabaseName(database);
	mysqlds.setPort(port);
	mysqlds.setUser(username);
	mysqlds.setPassword(password);

	return (DataSource)mysqlds;
    }

    /**
     * Creates a DataSource object which represents a connection to a Oracle database.
     *
     * @param hostname the hostname of the Oracle instance.
     *
     * @param port the port number on which the Oracle instance is listening for TCP/IP
     * connections.
     *
     * @param database the name of the Oracle database.
     *
     * @param username the default username.
     *
     * @param password the default password.
     *
     * @return a DataSource object which can be used to establish a connection to the
     * Oracle database.
     *
     * @throws SQLException in the event of an error.
     */

    public static DataSource createOracleDataSource(String hostname, int port, String database,
						    String username, String password)
	throws SQLException {
	oracle.jdbc.pool.OracleDataSource oracleds =
	    new oracle.jdbc.pool.OracleDataSource();

	oracleds.setServerName(hostname);
	oracleds.setDatabaseName(database);
	oracleds.setPortNumber(port);
	oracleds.setUser(username);
	oracleds.setPassword(password);
	oracleds.setDriverType("thin");

	return (DataSource)oracleds;
    }

    /**
     * Creates a DataSource object which represents a connection to a database.
     *
     * @param hostname the hostname of the database instance.
     *
     * @param port the port number on which the database instance is listening for TCP/IP
     * connections.
     *
     * @param database the name of the database.
     *
     * @param username the default username.
     *
     * @param password the default password.
     *
     * @param type specifies the type of database server. It should be one of MYSQL or
     * ORACLE.
     *
     * @return a DataSource object which can be used to establish a connection to the
     * database.
     *
     * @throws SQLException in the event of an error.
     */

    public static DataSource createDataSource(String hostname, int port, String database,
					      String username, String password, int type)
	throws SQLException {
	switch (type) {
	case MYSQL:
	    return createMysqlDataSource(hostname, port, database, username, password);

	case ORACLE:
	    return createOracleDataSource(hostname, port, database, username, password);

	default:
	    return null;
	}
    }

    /*
     * This section of code is concerned with the manager objects which
     * provide services to the ArcturusDatabase.
     */

    protected CloneManager cloneManager;
    protected LigationManager ligationManager;
    protected TemplateManager templateManager;
    protected ReadManager readManager;
    protected SequenceManager sequenceManager;

    private void createManagers() throws SQLException {
	cloneManager = new CloneManager(this);
	ligationManager = new LigationManager(this);
	templateManager = new TemplateManager(this);
	readManager = new ReadManager(this);
	sequenceManager = new SequenceManager(this);
    }

    /**
     * Returns the CloneManager belonging to this ArcturusDatabase.
     *
     * @return the CloneManager belonging to this ArcturusDatabase.
     */

    public CloneManager getCloneManager() { return cloneManager; }

    /**
     * Returns the LigationManager belonging to this ArcturusDatabase.
     *
     * @return the LigationManager belonging to this ArcturusDatabase.
     */

    public LigationManager getLigationManager() { return ligationManager; }

    /**
     * Returns the TemplateManager belonging to this ArcturusDatabase.
     *
     * @return the TemplateManager belonging to this ArcturusDatabase.
     */

    public TemplateManager getTemplateManager() { return templateManager; }

    /**
     * Returns the ReadManager belonging to this ArcturusDatabase.
     *
     * @return the ReadManager belonging to this ArcturusDatabase.
     */

    public ReadManager getReadManager() { return readManager; }

    /**
     * Returns the SequenceManager belonging to this ArcturusDatabase.
     *
     * @return the SequenceManager belonging to this ArcturusDatabase.
     */

    public SequenceManager getSequenceManager() { return sequenceManager; }

    /**
     * Returns a text representation of this object.
     *
     * @return a text representation of this object.
     */

    public String toString() {
	String text = "ArcturusDatabase[name=" + name;

	if (description != null)
	    text += ", description=" + description;

	text += "]";

	return text;
    }
}
