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
