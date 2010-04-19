package uk.ac.sanger.arcturus.database;

import java.sql.Connection;

public class ArcturusDatabaseException extends Exception {
	private Connection connection;
	private ArcturusDatabase adb;
	
	public ArcturusDatabaseException(Throwable cause, String message, Connection connection, ArcturusDatabase adb) {
		super(message, cause);
		this.connection = connection;
		this.adb = adb;
	}
	
	public ArcturusDatabaseException(Throwable cause, String message, Connection connection) {
		this(cause, message, connection, null);
	}

	public ArcturusDatabaseException(Throwable cause, Connection connection, ArcturusDatabase adb) {
		this(cause, null, connection, adb);
	}
	
	public ArcturusDatabaseException(Throwable cause, String message) {
		this(cause, message, null, null);
	}
	
	public ArcturusDatabaseException(Throwable cause, Connection connection) {
		this(cause, null, connection, null);
	}
	
	public ArcturusDatabaseException(Throwable cause) {
		this(cause, null, null, null);
	}
	
	public Connection getConnection() {
		return connection;
	}
	
	public ArcturusDatabase getArcturusDatabase() {
		return adb;
	}	
}
