package uk.ac.sanger.arcturus.logging;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.sql.SQLException;
import java.util.logging.Handler;
import java.util.logging.LogRecord;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public abstract class AbstractHandler extends Handler {	
	protected String formatLongMessage(LogRecord record) {
		StringBuffer sb = new StringBuffer(16384);
		
		sb.append("An Arcturus Java exception has occurred\n\n");
		
		String hostname = null;
		
		try {
			hostname = InetAddress.getLocalHost().getHostName();
		} catch (UnknownHostException e) {
			hostname = "[InetAddress.getLocalHost().getHostName() failed : " + e.getMessage() + "]";
		}
		
		sb.append("Hostname: " + hostname + "\n\n");
		
		String revision = Arcturus.getProperty(Arcturus.BUILD_VERSION_KEY, "[NOT KNOWN]");
		sb.append("Revision: " + revision + "\n\n");
		
		sb.append(record.getMessage() + "\n\n");
		
		sb.append("The logger is " + record.getLoggerName() + "\n");
		sb.append("The sequence number is " + record.getSequenceNumber() + "\n");
		sb.append("The level is " + record.getLevel().intValue() + "\n");
		sb.append("The source class name is " + record.getSourceClassName() + "\n");
		sb.append("The source method name is " + record.getSourceMethodName() + "\n");
		sb.append("The timestamp is " + record.getMillis() + "\n");
		
		Throwable thrown = getUnderlyingException(record.getThrown());
				
		if (thrown != null) {
			sb.append("\n----- PRIMARY EXCEPTION -----\n");
			
			displayThrowable(thrown, sb);
			
			Throwable cause = thrown == null ? null : thrown.getCause();
			
			while (cause != null) {
				sb.append("\n----- CHAINED EXCEPTION -----\n");
				displayThrowable(cause, sb);
				
				cause = cause.getCause();
			}
		}

		return sb.toString();
	}
	
	protected String formatShortMessage(LogRecord record) {
		StringBuffer sb = new StringBuffer();
		
		Throwable throwable = getUnderlyingException(record.getThrown());
		
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

		return sb.toString();
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
	
	protected void displayThrowable(Throwable thrown, StringBuffer sb) {
		StackTraceElement ste[] = thrown.getStackTrace();

		sb.append("\n" + thrown.getClass().getName());

		String message = thrown.getMessage();
		if (message != null)
			sb.append(": " + thrown.getMessage());
		
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
}
