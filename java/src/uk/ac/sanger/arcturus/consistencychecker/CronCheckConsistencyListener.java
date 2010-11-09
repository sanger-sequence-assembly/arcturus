package uk.ac.sanger.arcturus.consistencychecker;

	public class CronCheckConsistencyListener implements CheckConsistencyListener {
		
		private String allErrorMessagesForEmail;
		private String thisErrorMessageForEmail;
		private boolean testing = true;

		public CronCheckConsistencyListener() {
			allErrorMessagesForEmail = "";
			thisErrorMessageForEmail ="";
		}

		public void report(CheckConsistencyEvent event) {
			String message = event.getMessage();
			CheckConsistencyEvent.Type type = event.getType();
			
			switch (type) {
				case START_TEST_RUN:
					System.out.println(message);
					break;
				case START_TEST:
					System.out.println(message);
					break;
				case TEST_PASSED:
					System.out.println(message);
					break;
				case TEST_FAILED:
					System.err.println(message);
					setErrorMessagesForEmail(message);
					break;
				case INCONSISTENCY:
					System.err.println(message);
					setErrorMessagesForEmail(message);
					break;
				case EXCEPTION:
					System.err.println(message);
					setErrorMessagesForEmail(message);
					break;
				case ALL_TESTS_PASSED:
					System.out.println(message);
					break;
				case SOME_TESTS_FAILED:
					System.err.println(message);
					setErrorMessagesForEmail(message);
					break;
				case UNKNOWN:
					System.err.println(message);
					setErrorMessagesForEmail(message);
					break;
			}
			
		}
			
		public void sendEmail(String organism){
				String recipient;
				
				if (organism.startsWith("TEST")) testing = true;

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
