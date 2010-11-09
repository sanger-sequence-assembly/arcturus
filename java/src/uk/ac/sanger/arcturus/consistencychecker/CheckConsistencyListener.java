package uk.ac.sanger.arcturus.consistencychecker;

public interface CheckConsistencyListener {
	public void report(String message, boolean isError);
	public void sendEmail(String organism);
}