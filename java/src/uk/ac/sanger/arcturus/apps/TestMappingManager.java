package uk.ac.sanger.arcturus.apps;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.jdbc.*;

public class TestMappingManager {

	public static void main(String[] args) {

		String projectname = null;
		String assemblyname = null;
		String instance = null;
		String organism = null; 
	    
		
	    for (int i = 0; i < args.length; i++) {
            if (args[i].equalsIgnoreCase("-instance"))
                instance = args[++i];
            else if (args[i].equalsIgnoreCase("-organism"))
                organism = args[++i];
            else if (args[i].equalsIgnoreCase("-projectname"))
                projectname = args[++i];
            else if (args[i].equalsIgnoreCase("-assemblyname"))
                assemblyname = args[++i];
            else {
            	System.err.println("Invalid parameter " + args[i]);
    		    showUsage(System.err);
    		    System.exit(1);
           }
 	    }

	    if (instance == null || organism == null) {
		    showUsage(System.err);
		    System.exit(1);
		}
	    
	    try {
	    	TestMappingManager tm = new TestMappingManager();
	    	
 	        ArcturusInstance ai = ArcturusInstance.getInstance(instance);
 		    ArcturusDatabase adb = ai.findArcturusDatabase(organism);
 			
 // get the project, if specified
 	
 		    Project project = null;
			if (projectname != null) {
 				Assembly assembly = null;
 				if (assemblyname != null)
 				    assembly = adb.getAssemblyByName(assemblyname);
  			    project = adb.getProjectByName(assembly,projectname);
 			}

 			tm.process(adb, project);
	  			
	    }
	    catch(Exception e) {
	        System.err.println("Failed to initialise or execute the mapping manager tester" + e);
		    System.exit(1);
	    }

	    System.exit(0);
	}
	
	public void process(ArcturusDatabase adb, Project project) throws ArcturusDatabaseException {
	       
	    if (project != null) {
	    	System.out.println("loading for project " + project.getName());
	        adb.prepareToLoadProject(project);
	    	System.out.println("DONE");	        
	    }  
	    else {
	    	System.out.println("loading for all projects");
	        adb.prepareToLoadAllProjects();
	    	System.out.println("DONE");
	    }
	    
	    if (adb instanceof ArcturusDatabaseImpl) {
	        ArcturusDatabaseImpl adbi = (ArcturusDatabaseImpl)adb;
	        LinkManager lm = (LinkManager)adbi.getManager(ArcturusDatabaseImpl.LINK);
	        System.out.println("Size of cache : " + lm.getCacheStatistics());
	        
	        Set<String> keys = lm.getCacheKeys();
	        Iterator<String> iterator = keys.iterator();
	        int size = keys.size();
	        String[] readnames = new String[size];
	        int index = 0;
	        while (iterator.hasNext()) {
	            readnames[index++] = (String)iterator.next();
	        }
	        
	        lm.clearCache();
	        System.out.println("Size of cache : " + lm.getCacheStatistics());
	    	System.out.println("Re-loading one by one " + size + " readnames");
	    	for (int i=0 ; i < readnames.length ; i++) {
	    	    int contig_id = adb.getCurrentContigIDForReadName(readnames[i]);
	    	}
	    	System.out.println("DONE");	        
	        System.out.println("Size of cache : " + lm.getCacheStatistics());	        
	    }
	}
	
	public static void showUsage(PrintStream ps) {
		ps.println("Invalid or missing input parameters");
		ps.println();
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-project\tName of project");		
	}

}