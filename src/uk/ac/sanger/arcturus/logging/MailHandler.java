package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;
import javax.mail.*;
import javax.mail.internet.*;

import java.util.Properties;

import uk.ac.sanger.arcturus.Arcturus;

public class MailHandler extends Handler {
	protected Authenticator auth = null;
	protected Session session = null;
	protected InternetAddress addrTo = null;
	protected InternetAddress addrFrom = null;
	
	public MailHandler(String recipient) {
		Properties props = Arcturus.getProperties();
		session = Session.getDefaultInstance(props, auth);
		
		if (recipient == null)
			recipient = props.getProperty("mailhandler.to");
		
		try {
			addrTo = new InternetAddress(recipient);
		} catch (AddressException ae) {
			Arcturus.logWarning("Failed to create recipient address", ae);
		}
		
		String domain = props.getProperty("mailhandler.domain");
		String user = System.getProperty("user.name");
		
		try {
			addrFrom = new InternetAddress(user + "@" + domain);
		} catch (AddressException ae) {
			Arcturus.logWarning("Failed to create sender address", ae);
		}
	}

	public void close() throws SecurityException {
		// No-op.
	}

	public void flush() {
		// No-op.
	}

	public void publish(LogRecord record) {
		if (addrFrom == null || addrTo == null || session == null)
			return;
		
		Message msg = new MimeMessage(session);

		try {
			msg.setFrom(addrFrom);

			msg.addRecipient(Message.RecipientType.TO, addrTo);
			
			String subject = record.getMessage();

			msg.setSubject(subject);
			
			StringBuffer sb = new StringBuffer(16384);
			
			sb.append("An Arcturus Java exception has occurred\n\n");
			
			sb.append(subject + "\n\n");
			
			sb.append("The logger is " + record.getLoggerName() + "\n");
			sb.append("The sequence number is " + record.getSequenceNumber() + "\n");
			sb.append("The level is " + record.getLevel().intValue() + "\n");
			sb.append("The source class name is " + record.getSourceClassName() + "\n");
			sb.append("The source method name is " + record.getSourceMethodName() + "\n");
			sb.append("The timestamp is " + record.getMillis() + "\n");
			
			Throwable thrown = record.getThrown();
			
			if (thrown != null) {
				StackTraceElement ste[] = thrown.getStackTrace();

				sb.append("\n" + thrown.getClass().getName() + ": " + thrown.getMessage() + "\n");
		
				sb.append("\nSTACK TRACE:\n\n");
				
				for (int i = 0; i < ste.length; i++)
					sb.append(i + ": " + ste[i].getClassName() + " " +
							ste[i].getMethodName() + " line " + ste[i].getLineNumber() + "\n");
			}
			
			String body = sb.toString();
			
			msg.setText(body);

			msg.setHeader("X-Mailer", getClass().getName());
			msg.setSentDate(new java.util.Date());

			Transport.send(msg);
		} catch (Exception e) {
			
		}

	}

}
