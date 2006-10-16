package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;
import java.io.IOException;

public class Config {
	public Config() {
		Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

		logger.setUseParentHandlers(false);

		logger.addHandler(new ConsoleHandler());

		try {
			FileHandler filehandler = new FileHandler();
			filehandler.setFormatter(new SimpleFormatter());
			logger.addHandler(filehandler);
		} catch (IOException ioe) {
			logger.log(Level.WARNING,
					"Unable to create a FileHandler for logging", ioe);
		}

		System.err.println("Using logger " + logger.getName());
	}
}
