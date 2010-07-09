package uk.ac.sanger.arcturus.logging;

import java.sql.SQLException;
import java.util.Date;
import java.util.logging.Formatter;
import java.util.logging.LogRecord;

public class ShortMessageFormatter extends Formatter {
	public String format(LogRecord record) {
		Date timestamp = new Date(record.getMillis());
		
		if (record.getThrown() != null) {
			StringBuffer sb = new StringBuffer();

			Throwable throwable = record.getThrown();

			sb.append("An error has occurred.  Please notify a developer.\n\n");
			
			sb.append("Timestamp : " + timestamp + "\n\n");

			sb.append(throwable.getClass().getName() + ": "
					+ throwable.getMessage() + "\n");

			if (throwable instanceof SQLException) {
				SQLException sqle = (SQLException) throwable;

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
				sb.append("\n\nCAUSE: " + cause.getClass().getName() + " : "
						+ cause.getMessage() + "\n");

				ste = cause.getStackTrace();

				for (int i = 0; i < ste.length; i++)
					if (ste[i].getClassName().startsWith(
							"uk.ac.sanger.arcturus"))
						sb.append("  [" + i + "]: " + ste[i] + "\n");
			}

			return sb.toString();
		} else
			return timestamp + " : " + record.getMessage() + "\n\n";
		
	}

}
