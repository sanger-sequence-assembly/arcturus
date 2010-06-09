package uk.ac.sanger.arcturus.apps;

import java.io.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.samtools.BAMContigLoader;
import uk.ac.sanger.arcturus.samtools.BAMReadLoader;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
//import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import net.sf.samtools.*;

public class ContigLoader {

	public static void main (String[] args) {
		File file = null;
		String projectname = null;
		String assemblyname = null;
		String instance = null;
		String organism = null; 
		
	    for (int i = 0; i < args.length; i++) {
            if (args[i].equalsIgnoreCase("-in"))
                file = new File(args[++i]);
            else if (args[i].equalsIgnoreCase("-instance"))
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

	    if (file == null || instance == null || organism == null || projectname == null) {
		    showUsage(System.err);
		    System.exit(1);
		}
	    
	    try {
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
 			
 // open SAM file reader and test it

 			SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);			
 			SAMFileReader reader = new SAMFileReader(file);
 	    	if (reader.isBinary() == false || reader.hasIndex() == false)
 	    		throw new IllegalArgumentException("The input file is not indexed: " + file.toString());
 	    	
// set up read loader/tester and process the reads

 	    	BAMReadLoader brl = new BAMReadLoader(adb);
 			brl.processFile(reader);
 			
// set up the contig loader and iterate through the contigs

 			BAMContigLoader bcl = new BAMContigLoader(adb);	        
	        bcl.processFile(reader,project);
	    }
	    catch(Exception e) {
	        System.err.println("Failed to initialise or execute the contig loader" + e);
	    }
	}
	
	public static void showUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-bam\tName of ordered and indexed bam file");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-project\tName of project (default: BIN)");		
		ps.println("\t-lock\tAcquire the lock on the project");		
	}
}
