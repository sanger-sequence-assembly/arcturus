package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;

public class Config {
    public Config() {
	Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");
	logger.setUseParentHandlers(false);
	logger.addHandler(new ConsoleHandler());
	System.err.println("Using logger " + logger.getName());
    }
}
