// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
	
	public ArcturusDatabaseException(String message) {
		this(null, message, null, null);
	}
	
	public Connection getConnection() {
		return connection;
	}
	
	public ArcturusDatabase getArcturusDatabase() {
		return adb;
	}	
}
