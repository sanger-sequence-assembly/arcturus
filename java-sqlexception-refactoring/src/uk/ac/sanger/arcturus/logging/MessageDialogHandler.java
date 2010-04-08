package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;
import javax.swing.*;

public class MessageDialogHandler extends Handler {
	public MessageDialogHandler() {
		setFormatter(new ShortMessageFormatter());
	}
	
	public void close() throws SecurityException {
		// Does nothing
	}

	public void flush() {
		// Does nothing
	}

	public void publish(LogRecord record) {
		if (!isLoggable(record))
			return;
		
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
				message = getFormatter().format(record);
			}
		}

		JOptionPane.showMessageDialog(null, message, title, type);
	}
}
