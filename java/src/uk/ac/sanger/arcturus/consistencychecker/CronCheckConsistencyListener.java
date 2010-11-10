package uk.ac.sanger.arcturus.consistencychecker;

import java.io.BufferedWriter;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;


	public class CronCheckConsistencyListener implements CheckConsistencyListener {
		protected BufferedWriter outputStream;
		
		private String allErrorMessagesForEmail;
		private String thisErrorMessageForEmail;
		private String logIntro;

		private String dateString;
		private String logName;
		private Date date;
		private boolean testing;

		private String filePath;
		private String instance;
		private String organism;
		
		public CronCheckConsistencyListener(String instance,  String organism, String logFullPath) {
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
								organism + " in database " +
								instance + " on " + 
								dateString + " stored at " +
								filePath + "\n";
			
			if (testing) System.out.println("About to add the file handler for " + filePath);
		
			try {
					outputStream = new BufferedWriter(new FileWriter(filePath));
			} 
			catch (IOException ioe) {
				System.err.println("Unable to create a FileHandler for logging: " +ioe);
			}
			
			if (testing) System.err.println(logIntro);
		}

		public void report(CheckConsistencyEvent event){
			String message = event.getMessage();
			CheckConsistencyEvent.Type type = event.getType();
			
			switch (type) {
				case START_TEST_RUN:
					try {
						message = logIntro;						
						outputStream.write(message);
						outputStream.write("\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case START_TEST:
					try {
						outputStream.write(message);
						outputStream.write("\n\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
				case TEST_PASSED:
					try {
						outputStream.write(message);
						outputStream.write("\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case TEST_FAILED:
					try {
						outputStream.write(message);
						outputStream.write("\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
				case INCONSISTENCY:
					try {
						outputStream.write(message);
						outputStream.write("\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
				case EXCEPTION:
					try {
						outputStream.write(message);
						outputStream.write("\n");
					} catch (IOException e) {
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
				case ALL_TESTS_PASSED:
					try {
						outputStream.write(message);
						outputStream.close();
					} catch (IOException e) {
						e.printStackTrace();
					}
					break;
				case SOME_TESTS_FAILED:
					try {
						outputStream.write(message);
						outputStream.close();
					} catch (IOException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
				case UNKNOWN:
					try {
						outputStream.write(message);
					} catch (IOException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
					}
					setErrorMessagesForEmail(message);
					break;
			}
			
		}
			
		public void sendEmail(){
				String recipient;
				
				
				String message = getAllErrorMessagesForEmail();
				String subject = ("ARCTURUS database " + organism + " has FAILED the consistency check");
				
				if (testing)
					recipient = "kt6@sanger.ac.uk";
				else
					recipient = "arcturus-help@sanger.ac.uk";
				
				if (testing)
					System.err.println("\n\nabout to email " +subject + message  + " to " + recipient);
				
				/* email call goes here */
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
		
		public int openLog(String filename){
			return 1;
		}
		
		public int writeLog(int fileHandle, String message) {
			return 1;
		}
		
		public int closeLog(int fileHandle) {
			return 1;
		}

}
