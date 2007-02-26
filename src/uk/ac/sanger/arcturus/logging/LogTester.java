package uk.ac.sanger.arcturus.logging;

import uk.ac.sanger.arcturus.Arcturus;
import java.util.logging.Level;
import java.util.logging.Logger;

public class LogTester {
	public static void main(String[] args) {
		Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");
		
		Arcturus.logWarning("Starting");

		for (int j = 0; j < 3; j++) {
			try {
				Thread.sleep(3000L);
			} catch (InterruptedException ie) {
				Arcturus.logWarning("Sleep interrupted");
			}

			Arcturus.logWarning("This is a warning");

			try {
				Thread.sleep(3000L);
			} catch (InterruptedException ie) {
				Arcturus.logWarning("Sleep interrupted");
			}

			try {
				doSomething(0);
			} catch (Exception e) {
				Arcturus.log(Level.SEVERE, "exception", e);
			}
		}
	}
	
	public static void doSomething(int i) throws Exception {
		if (i < 5)
			doSomething(i+1);
		else
			throw new Exception("Something bad happened");
	}

}
