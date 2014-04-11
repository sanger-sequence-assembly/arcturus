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

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Date;
import java.util.logging.LogRecord;

import uk.ac.sanger.arcturus.Arcturus;

public class LongMessageFormatter extends AbstractFormatter {
	private final String SEPARATOR = "\n\n########################################################################\n\n";
	
	public String format(LogRecord record) {
		StringBuffer sb = new StringBuffer(16384);
		
		String hostname = null;
		
		try {
			hostname = InetAddress.getLocalHost().getHostName();
		} catch (UnknownHostException e) {
			hostname = "[InetAddress.getLocalHost().getHostName() failed : " + e.getMessage() + "]";
		}
		
		if (record.getThrown() != null)
			formatForException(sb, record, hostname);
		else
			formatForMessage(sb, record, hostname);
				
		sb.append(SEPARATOR);

		return sb.toString();
	}

	private void formatForException(StringBuffer sb, LogRecord record, String hostname) {
		sb.append("An Arcturus Java exception has occurred\n\n");
		
		sb.append("Hostname: " + hostname + "\n\n");
		
		String revision = Arcturus.getProperty(Arcturus.BUILD_VERSION_KEY, "[NOT KNOWN]");
		sb.append("Revision: " + revision + "\n\n");
		
		sb.append(record.getMessage() + "\n\n");
		
		sb.append("The logger is " + record.getLoggerName() + "\n");
		sb.append("The sequence number is " + record.getSequenceNumber() + "\n");
		sb.append("The level is " + record.getLevel().intValue() + "\n");
		sb.append("The source class name is " + record.getSourceClassName() + "\n");
		sb.append("The source method name is " + record.getSourceMethodName() + "\n");
		
		Date timestamp = new Date(record.getMillis());
		
		sb.append("The timestamp is " + timestamp + "\n");
		
		Throwable thrown = getUnderlyingException(record.getThrown());
				
		if (thrown != null) {
			sb.append("\n----- PRIMARY EXCEPTION -----\n");
			
			displayThrowable(thrown, sb);
			
			Throwable cause = thrown.getCause();
			
			while (cause != null) {
				sb.append("\n----- CHAINED EXCEPTION -----\n");
				displayThrowable(cause, sb);
				
				cause = cause.getCause();
			}
		}		
	}

	private void formatForMessage(StringBuffer sb, LogRecord record, String hostname) {
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
}
