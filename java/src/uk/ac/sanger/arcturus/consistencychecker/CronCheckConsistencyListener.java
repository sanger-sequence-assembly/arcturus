package uk.ac.sanger.arcturus.consistencychecker;

	public class CronCheckConsistencyListener implements CheckConsistencyListener {
		/* uncomment me when I am no longer a neseted class public enum MessageType {LOG, EMAIL, BOTH}
*/
		private String allErrorMessagesForEmail;
		private String thisErrorMessageForEmail;
		private boolean testing;

		public CronCheckConsistencyListener() {
			allErrorMessagesForEmail = "";
			thisErrorMessageForEmail ="";
		}

		public void report(String message, boolean isError) {
				if (!isError)
					System.out.println(message);
				else {
					System.err.println(message);
					setErrorMessagesForEmail(message);
				}
		}
			
		public void sendEmail(String organism){
				String recipient;

				String message = getAllErrorMessagesForEmail();
				
				if (testing)
					recipient = "kt6@sanger.ac.uk";
				else
					recipient = "arcturus-help@sanger.ac.uk";
				
				if (testing)
					System.err.println("about to email " + message  + " to " + recipient);
				
				/* email call goes here */
				String subject = ("ARCTURUS database" + organism + " has FAILED the consistency check");
				
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
