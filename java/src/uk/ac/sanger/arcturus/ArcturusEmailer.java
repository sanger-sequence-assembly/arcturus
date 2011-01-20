package uk.ac.sanger.arcturus;

import javax.mail.*;
import javax.mail.internet.*;
import java.util.*;

public class ArcturusEmailer {
	
	protected String smtpServer;
	protected String recipient;
	protected String ccRecipient;
	protected String sender;
	
	public ArcturusEmailer (String recipient, String sender)
	{
		this.smtpServer = Arcturus.getProperty("mail.smtp.host");
		this.recipient = recipient;
		this.sender = sender;
	}
	

	public ArcturusEmailer (String recipient, String ccRecipient, String sender)
	{
		this.smtpServer = Arcturus.getProperty("mail.smtp.host");
		this.recipient = recipient;
		this.ccRecipient = ccRecipient;
		this.sender = sender;
	}
	
	public void send(String subject, String body)
	{
		send(this.smtpServer, this.recipient, this.sender, subject, body);
	}
	
	static void send(String smtpServer, String to, String from, String subject, String body)
	{
		try
		{
			Properties props = System.getProperties();
			// -- Attaching to default Session, or we could start a new one --
			props.put("mail.smtp.host", smtpServer);
			Session session = Session.getDefaultInstance(props, null);
			// -- Create a new message --
			Message msg = new MimeMessage(session);
			// -- Set the FROM and TO fields --
			msg.setFrom(new InternetAddress(from));
			msg.setRecipients(Message.RecipientType.TO,
					InternetAddress.parse(to, false));
			// -- Set the subject and body text --
			msg.setSubject(subject);
			msg.setText(body);
			// -- Set some other header information --
			msg.setHeader("X-Mailer", "LOTONtechEmail");
			msg.setSentDate(new Date());
			// -- Send the message --
			Transport.send(msg);
			System.out.println("Email message to notify inconsistencies sent OK.");
		}
		catch (Exception ex)
		{
			ex.printStackTrace();
		}
	}
	
	static void send(String smtpServer, String to, String from, String cc, String subject, String body)
	{
		try
		{
			Properties props = System.getProperties();
			// -- Attaching to default Session, or we could start a new one --
			props.put("mail.smtp.host", smtpServer);
			Session session = Session.getDefaultInstance(props, null);
			// -- Create a new message --
			Message msg = new MimeMessage(session);
			// -- Set the FROM and TO fields --
			msg.setFrom(new InternetAddress(from));
			msg.setRecipients(Message.RecipientType.TO,
					InternetAddress.parse(to, false));
			// -- Set the cc recipient(s) --
			if (cc != null)
			msg.setRecipients(Message.RecipientType.CC,InternetAddress.parse(cc, false));
			// -- Set the subject and body text --
			msg.setSubject(subject);
			msg.setText(body);
			// -- Set some other header information --
			msg.setHeader("X-Mailer", "LOTONtechEmail");
			msg.setSentDate(new Date());
			// -- Send the message --
			Transport.send(msg);
			System.out.println("Email message to notify inconsistencies sent OK.");
		}
		catch (Exception ex)
		{
			ex.printStackTrace();
		}
	}
	public static void main(String[] args) {

		try
		{
			String smtpServer=args[0];
			String to=args[1];
			String from=args[2];
			String cc=args[3];
			String subject=args[4];
			String body=args[5];
			
			send(smtpServer, to, from, subject, body);
			
			send(smtpServer, to, from, cc, subject, body);
		}
		catch (Exception ex)
		{
			System.out.println("Exception raised from "+ ex.getCause() + " is: \n");
			ex.printStackTrace();
			System.out.println("\nUsage: java uk.ac.sanger.arcturus.consistencychecker.ArcturusEmailer"
					+" smtpServer toAddress fromAddress subjectText bodyText");
		}
		System.exit(0);
	}

}
