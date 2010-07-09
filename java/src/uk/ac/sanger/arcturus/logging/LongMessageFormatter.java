package uk.ac.sanger.arcturus.logging;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Date;
import java.util.logging.LogRecord;

import uk.ac.sanger.arcturus.Arcturus;

public class LongMessageFormatter extends AbstractFormatter {
	private final String SEPARATOR = "\n\n########################################################################\n\n";
	
	public String format(LogRecord record) {
		Date timestamp = new Date(record.getMillis());
		
		if (record.getThrown() != null) {
			StringBuffer sb = new StringBuffer(16384);

			sb.append("An Arcturus Java exception has occurred\n\n");

			String hostname = null;

			try {
				hostname = InetAddress.getLocalHost().getHostName();
			} catch (UnknownHostException e) {
				hostname = "[InetAddress.getLocalHost().getHostName() failed : "
						+ e.getMessage() + "]";
			}

			sb.append("Hostname: " + hostname + "\n\n");

			String revision = Arcturus.getProperty(Arcturus.BUILD_VERSION_KEY,
					"[NOT KNOWN]");
			sb.append("Revision: " + revision + "\n\n");

			sb.append(record.getMessage() + "\n\n");

			sb.append("The logger is " + record.getLoggerName() + "\n");
			sb.append("The sequence number is " + record.getSequenceNumber()
					+ "\n");
			sb.append("The level is " + record.getLevel().getName() + "\n");
			sb.append("The source class name is " + record.getSourceClassName()
					+ "\n");
			sb.append("The source method name is "
					+ record.getSourceMethodName() + "\n");

			sb.append("The timestamp is " + formatDate(timestamp) + "\n");

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

			sb.append(SEPARATOR);
			return sb.toString();
		} else
			return record.getLevel().getName() + " : " + formatDate(timestamp) + " " + record.getMessage() + "\n\n";
	}

}
