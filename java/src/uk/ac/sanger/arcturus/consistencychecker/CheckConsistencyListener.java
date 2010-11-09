package uk.ac.sanger.arcturus.consistencychecker;

public interface CheckConsistencyListener {
	public void report(CheckConsistencyEvent event);
	public void sendEmail(String organism);
}