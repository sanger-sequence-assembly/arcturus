package uk.ac.sanger.arcturus.logging;

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
			StringBuffer sb = new StringBuffer();
			
			sb.append("An error has occurred.  Please notify a developer.\n\n");
			
			sb.append(throwable.getClass().getName() + ": " + throwable.getMessage() + "\n");
			
			StackTraceElement[] ste = throwable.getStackTrace();
			
			for (int i = 0; i < ste.length; i++)
				sb.append("      " + ste[i] + "\n");
			
			message = sb.toString();
		}
		
		JOptionPane.showMessageDialog(null, message, title, type);
	}
}
