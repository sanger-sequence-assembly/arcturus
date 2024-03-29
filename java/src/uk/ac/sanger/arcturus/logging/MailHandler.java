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
		setFormatter(new LongMessageFormatter());
		
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
		if (!isLoggable(record))
			return;
		
		if (addrFrom == null || addrTo == null || session == null)
			return;
		
		Message msg = new MimeMessage(session);

		try {
			msg.setFrom(addrFrom);

			msg.addRecipient(Message.RecipientType.TO, addrTo);
			
			String subject = record.getMessage();

			msg.setSubject(subject);
						
			String body = getFormatter().format(record);
			
			msg.setText(body);

			msg.setHeader("X-Mailer", getClass().getName());
			msg.setSentDate(new java.util.Date());

			Transport.send(msg);
		} catch (MessagingException e) {
			// Ignore this
		}

	}
	
	public static void main(String[] args) {
		if (args.length == 0) {
			System.err.println("Please provide a recipient email address when running this test");
			System.exit(0);
		}
		
		Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

		logger.setUseParentHandlers(false);

		MailHandler mailhandler = new MailHandler(args[0]);
		
		mailhandler.setLevel(Level.WARNING);
		
		logger.addHandler(mailhandler);

		try {
			throw new Exception("Something bad happened");
		}
		catch (Exception e) {
			logger.log(Level.WARNING, e.getMessage(), e);
		}
		
		System.exit(0);
	}
}
