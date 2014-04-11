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
import java.util.logging.*;
import javax.swing.*;

public class MessageDialogHandler extends Handler {
	public void close() throws SecurityException {
		// Does nothing
	}

	public void flush() {
		// Does nothing
	}

	public void publish(LogRecord record) {
		Level level = record.getLevel();

		int type = JOptionPane.INFORMATION_MESSAGE;

		if (level.equals(Level.WARNING))
			type = JOptionPane.WARNING_MESSAGE;
		else if (level.equals(Level.SEVERE))
			type = JOptionPane.ERROR_MESSAGE;

		String title = level.getLocalizedName() + " : " + record.getMessage();

		String message = title;

		Throwable throwable = record.getThrown();

		if (throwable != null) {
			if (throwable instanceof javax.naming.ServiceUnavailableException ||
					throwable instanceof javax.naming.CommunicationException) {
				title = "There is a problem with the LDAP server";
				
				message = "Minerva cannot connect to the LDAP server.\n" +
				"Please try again later.\n" +
				"If the problem persists, please submit a helpdesk ticket.";
			} else if (throwable instanceof ClassNotFoundException) {
				title = "The application is not correctly installed";
				
				message = "Please submit a helpdesk ticket, quoting this message:\n" +
				"Your application may not be correctly installed.\n" +				
				"Minerva cannot find a required Java class: " + throwable.getMessage() + "\n" +
				record.getMessage();
			} else {
				StringBuffer sb = new StringBuffer();

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

				message = sb.toString();
			}
		}

		JOptionPane.showMessageDialog(null, message, title, type);
	}
}
