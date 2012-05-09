package uk.ac.sanger.arcturus.consistencychecker;

import java.io.BufferedWriter;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.DateFormat;
import java.text.MessageFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Vector;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusEmailer;


	public class CronCheckConsistencyListener implements CheckConsistencyListener {
		protected BufferedWriter outputStream;
		protected ArcturusEmailer emailer;
		
		private String allErrorMessagesForEmail;
		private String thisErrorMessageForEmail;
		private String logIntro;
		private String emailIntro;

		private String dateString;
		private String logName;
		private Date date;
		private boolean testing;

		private String filePath;
		private String instance;
		private String organism;
		
		private String recipient = "";
		private String ccRecipient = "";
		private String sender = "";
		
		public CronCheckConsistencyListener(String instance,  String organism, String logFullPath, Vector<String> emailNames) {
			allErrorMessagesForEmail = "";
			thisErrorMessageForEmail ="";
			if (organism.startsWith("TEST")) testing = true;

			this.instance = instance;
			this.organism = organism;
		
			/* use log_full_path from command line then consistencycheck201111101238.log */
			Locale currentLocale = new Locale("en","UK");
			SimpleDateFormat logNameFormatter = new SimpleDateFormat("yyyyMMddHHmm", currentLocale);
			date = new Date();
			logName = logNameFormatter.format(date);
			
			SimpleDateFormat startTimeFormatter = new SimpleDateFormat("HH:MM dd/MM/yyyy", currentLocale);
			dateString = startTimeFormatter.format(date);
			
			filePath = logFullPath + "consistencycheck" + logName + ".log";
			logIntro = "This is the log for a consistency check run for organism " +
								organism + "\nin database " +
								instance + " on " + 
								dateString + " stored at \n" +
								filePath + "\n";
			
			emailIntro = "The consistency check run for organism " +
			organism + "\nin database " +
			instance + " on " + dateString + "\n has found some inconsistencies.  The full log is stored at \n " +
			filePath + "\nA summary of the problem(s) is given below. \n\n" +
			"A Help Desk ticket has been raised and the problem(s) will be fixed as soon as possible.";
			
			if (testing) System.out.println("About to add the file handler for " + filePath);
		
			try {
					outputStream = new BufferedWriter(new FileWriter(filePath));
			} 
			catch (IOException ioe) {
				System.err.println("Unable to create a FileHandler for logging: " +ioe);
			}
			
			if (testing) System.err.println(logIntro);
			
			int emailNamesSize = emailNames.size();
			String restOfEmailAddress = "@" + Arcturus.getProperty("mailhandler.domain");
			
			// if no user can be found, use the person who is running the consistency check
			// this is usually the case for the test databases
			
			if (testing) {
				this.sender = System.getProperty("user.name") + restOfEmailAddress;
				this.ccRecipient = "none";
				this.recipient = sender;
			}
			else {
				if (emailNamesSize == 0) {
					this.sender = System.getProperty("user.name") + restOfEmailAddress;
					this.ccRecipient = "none";
				} 
				else {
					// first name is the sender of the email
					// others are the cc recipients
					// arcturus-help will be the recipient
					boolean first = true;
					boolean firstcc = false;
					
					for(int i=0;i<emailNamesSize;i++)
		        	{
						if (first) {
							this.sender = emailNames.get(i)  + restOfEmailAddress;
							first = false;
							firstcc = true;
						}
						else {
							if (firstcc) {
								this.ccRecipient = this.ccRecipient + emailNames.get(i) + restOfEmailAddress;
								firstcc = false;
							}
							else {
								this.ccRecipient = this.ccRecipient + "," + emailNames.get(i) + restOfEmailAddress;
							}
						}
		        	}
				}
				this.recipient = "arcturus-help" + restOfEmailAddress;
			}
			//if (testing) 
				System.err.println("IF an email needs to be sent later, it will come from "+ sender + " to "+ recipient + 
						" cc to " + ccRecipient + "\n");
			
			if (ccRecipient == "none")
				emailer = new ArcturusEmailer(recipient, sender);
			else
				emailer = new ArcturusEmailer(recipient, ccRecipient, sender);
		}

		public void report(CheckConsistencyEvent event){
			String message = event.getMessage();
			CheckConsistencyEvent.Type type = event.getType();
			
			switch (type) {
				case START_TEST_RUN:
					try {
						message = logIntro;	
						outputStream.write("If there are any inconsistencies found, an email will be sent to " 
								+ this.recipient + " from " + this.sender + " cc to " + this.ccRecipient + "\n");
						outputStream.write(message);
						setErrorMessagesForEmail(emailIntro);
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case START_TEST:
					try {
						outputStream.write(message + "\n\n");
						setErrorMessagesForEmail(message);
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case TEST_PASSED:
					try {
						outputStream.write(message + "\n");
						setErrorMessagesForEmail(message);
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case TEST_FAILED:
					try {
						outputStream.write(message + "\n");
						setErrorMessagesForEmail(message);
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case INCONSISTENCY:
					try {
						outputStream.write(message + "\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case EXCEPTION:
					try {
						outputStream.write(message + "\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
				case ALL_TESTS_PASSED:
					try {
						outputStream.write(message);
					} catch (IOException e) {
						e.printStackTrace();
					}
					closeLog();
					break;
				case SOME_TESTS_FAILED:
					try {
						outputStream.write(message);
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					sendEmail();
					closeLog();
					break;
				case UNKNOWN:
					try {
						outputStream.write(message);
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
			}
			
		}
			
		public void sendEmail(){

				String message = getAllErrorMessagesForEmail();
				String subject = ("ARCTURUS database " + organism + " has FAILED the consistency check");
				
				try {
					outputStream.write("Here is the message to be emailed:*" + message + "*\n");
				}catch (IOException e) {
					e.printStackTrace();
				}
				
				emailer.send(subject,message);

			}
			
		private String getAllErrorMessagesForEmail() {
			return allErrorMessagesForEmail;
		}

		private String getThisErrorMessageForEmail() {
			return thisErrorMessageForEmail;
		}
		
		private void setErrorMessagesForEmail(
				String thisErrorMessage) {
			allErrorMessagesForEmail = allErrorMessagesForEmail + "\n" + thisErrorMessage;
			thisErrorMessageForEmail = thisErrorMessage;
			
		}
		
		private void closeLog(){
			try {
				outputStream.close();
			}
			catch (IOException e) {
				e.printStackTrace();
			}
		}

		
}
