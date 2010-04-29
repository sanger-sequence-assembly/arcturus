package uk.ac.sanger.arcturus.test;

import java.util.*;
import javax.naming.*;


import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
// import uk.ac.sanger.arcturus.data.*;

public abstract class TestRun {
	
    public void run(String[] args) {

//		System.out.println("Invoking super class constructor method");

		Properties props = buildProperties(args);
		
        String instance = props.getProperty("instance");
        if (instance == null) instance = props.getProperty("i");
 
        String organism = props.getProperty("organism");
        if (organism == null) organism = props.getProperty("o");
        
        if (instance == null || organism == null) {
        	// print usage
        	System.exit(1);
        }
        

        ArcturusInstance ai = null;
        
        try {
            ai = ArcturusInstance.getInstance(instance);
        }
        catch (NamingException e) {
        	System.err.println ("Can't locate database instance " + instance);
            System.exit(1);
        }
 
        ArcturusDatabase adb = null;
       
        try {
            adb = ai.findArcturusDatabase(organism);
        }
        catch (ArcturusDatabaseException e) {
           	System.err.println ("Can't access database " + organism + ": " + e);
            System.exit(1);
        }
        
		dotest(adb, props);
	}
	
	private Properties buildProperties (String[] args) {
	    Properties props = new Properties();
	    for (int i = 0; i < args.length ; i++) {
	    	if (args[i].startsWith("-")) { // and length > 1 ? and not numerical
    			String key = args[i].substring(1).toLowerCase(); // remove leading -
	    		int j = i + 1;
	    		if (j >= args.length) // last entry
	    			props.setProperty(key, "true");
	    		else if (isNumerical(args[j])) 
	                props.setProperty(key, args[++i]);    		
  	    	    else if ( args[j].startsWith("-") )
  	    	        props.setProperty(key, "true");     	    	
	    		else // args[j] is a value or string
                    props.setProperty(key, args[++i]);	    		
	    	}
	    }
	    return props;
	}
	
	private boolean isNumerical (String argument) {
		
		try {
 		    if ( Integer.valueOf(argument).toString().equals(argument) ) return true;
		}
		catch (NumberFormatException e) {} // ignore here
		try {
		    if ( Float.valueOf(argument).toString().equals(argument) ) return true;
		}
		catch (NumberFormatException e) {} // ignore here
		
		return false;
	}

	public abstract void dotest (ArcturusDatabase adb, Properties props);
}
