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

package uk.ac.sanger.arcturus.logging;

import java.util.logging.Formatter;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public abstract class AbstractFormatter extends Formatter {	
	protected void displayThrowable(Throwable thrown, StringBuffer sb) {
		StackTraceElement ste[] = thrown.getStackTrace();

		sb.append("\n" + thrown.getClass().getName());

		String message = thrown.getMessage();
		
		if (message != null)
			sb.append(": " + message);
		
		sb.append("\n");
		
		if (thrown instanceof SQLException) {
			SQLException sqle = (SQLException)thrown;
			
			sb.append("\nSQL error code : " + sqle.getErrorCode() + "\n");
			sb.append("SQL state : " + sqle.getSQLState() + "\n");
		}

		sb.append("\nSTACK TRACE:\n\n");
		
		for (int i = 0; i < ste.length; i++)
			sb.append(i + ": " + ste[i].getClassName() + " " +
					ste[i].getMethodName() + " line " + ste[i].getLineNumber() + "\n");
	}

	
	protected Throwable getUnderlyingException(Throwable thrown) {
		if (thrown == null)
			return null;
		
		if (thrown instanceof Exception) {
			Exception e = (Exception)thrown;
			
			return (e instanceof ArcturusDatabaseException && e.getCause() != null) ? e.getCause() : e;
		} else
			return thrown;
	}

}
