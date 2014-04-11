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

import java.sql.SQLException;
import java.util.Date;
import java.util.logging.Formatter;
import java.util.logging.LogRecord;

public class ShortMessageFormatter extends Formatter {
	public String format(LogRecord record) {
		StringBuffer sb = new StringBuffer();
		
		if (record.getThrown() != null)
			formatForException(sb, record);
		else
			formatForMessage(sb, record);
		
		return sb.toString();
	}

	private void formatForMessage(StringBuffer sb, LogRecord record) {
		Date timestamp = new Date(record.getMillis());
		
		sb.append(timestamp);
		sb.append(" : ");
		sb.append(record.getSourceClassName());
		sb.append(" : ");
		sb.append(record.getSourceMethodName());
		sb.append("\n");
		
		sb.append(record.getLevel());
		sb.append(" : ");
		sb.append(record.getMessage());
		sb.append("\n");
	}

	private void formatForException(StringBuffer sb, LogRecord record) {
		Throwable throwable = record.getThrown();

		sb.append("An error has occurred.  Please notify a developer.\n\n");

		sb.append(throwable.getClass().getName() + ": "
				+ throwable.getMessage() + "\n");
		
		if (throwable instanceof SQLException) {
			SQLException sqle = (SQLException)throwable;
			
			sb.append("\nSQL error code : " + sqle.getErrorCode() + "\n");
			sb.append("SQL state : " + sqle.getSQLState() + "\n");
		}

		StackTraceElement[] ste = throwable.getStackTrace();

		boolean showAll = ste.length <= 10;

		for (int i = 0; i < ste.length; i++)
			if (showAll
					|| ste[i].getClassName().startsWith(
							"uk.ac.sanger.arcturus"))
				sb.append("  [" + i + "]: " + ste[i] + "\n");
		
		Throwable cause = throwable.getCause();
		
		if (cause != null) {
			sb.append("\n\nCAUSE: " + cause.getClass().getName() + " : " + cause.getMessage() + "\n");
			
			ste = cause.getStackTrace();
			
			for (int i = 0; i < ste.length; i++)
				if (ste[i].getClassName().startsWith(
								"uk.ac.sanger.arcturus"))
					sb.append("  [" + i + "]: " + ste[i] + "\n");
		}
	}

}
