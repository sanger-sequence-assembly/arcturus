package test.importer;

import java.io.*;

import uk.ac.sanger.arcturus.data.*;
//import uk.ac.sanger.arcturus.samtools.BAMContigLoader;
import uk.ac.sanger.arcturus.samtools.BAMReadLoader;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import net.sf.samtools.*;

public class BAMContigLoaderTest {

	public static void main (String[] args) {
		File file = null;
		String projectName = null;
		String assemblyName = null;
		String instance = null;
		String organism = null;
		boolean preloadReads = false;
		String contigName = null;
		
	    for (int i = 0; i < args.length; i++) {
            if (args[i].equalsIgnoreCase("-in"))
                file = new File(args[++i]);
            else if (args[i].equalsIgnoreCase("-instance"))
                instance = args[++i];
            else if (args[i].equalsIgnoreCase("-organism"))
                organism = args[++i];
            else if (args[i].equalsIgnoreCase("-projectname"))
                projectName = args[++i];
            else if (args[i].equalsIgnoreCase("-assemblyname"))
                assemblyName = args[++i];
            else if (args[i].equalsIgnoreCase("-contigname"))
            	contigName = args[++i];
            else if (args[i].equalsIgnoreCase("-preload"))
                preloadReads = true;
            else {
            	System.err.println("Invalid parameter " + args[i]);
    		    showUsage(System.err);
    		    System.exit(1);
            }
 	    }

	    if (file == null || instance == null || organism == null) {
		    showUsage(System.err);
		    System.exit(1);
		}
	    
	    try {
System.out.println("Trying to get DB handle"); 	    	
 	        ArcturusInstance ai = ArcturusInstance.getInstance(instance);
 			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
if (adb != null)
	System.out.println("DB opened");
 			
 // get the project, if specified
 			
 			Project project = null;
 			if (projectName != null) {
 				Assembly assembly = null;
 				if (assemblyName != null)
 				    assembly = adb.getAssemblyByName(assemblyName);
  			    project = adb.getProjectByName(assembly,projectName);
 			}
 			
 // open SAM file reader and test it
 			
 System.out.println("Try to open BAM file " + file); 	    	

 			SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);			
 			SAMFileReader reader = new SAMFileReader(file);
 	    	if (reader.isBinary() == false || reader.hasIndex() == false)
 	    		throw new IllegalArgumentException("The input file is not indexed: " + file);
 	    	
// set up read loader/tester and process the reads

 	    	BAMReadLoader brl = new BAMReadLoader(adb);
// in preload mode, load (missing) reads first, then iterate through contigs
 	    	if (preloadReads)
  			    brl.processFile(reader);
  			    
			BAMContigLoaderWrapper bcl = new BAMContigLoaderWrapper(adb,brl);	        
	        bcl.processFile(reader, project, contigName);
	    }
	    catch(Exception e) {
	    	Arcturus.logWarning("Failed to initialise or execute the contig loader", e);
	    	System.exit(1);
	    }
    	System.exit(0);
	}
	
	public static void showUsage(PrintStream ps) {
		ps.println("Invalid or missing input parameters");
		ps.println();
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-in\t\tName of ordered and indexed bam file");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-projectname\tName of project");		
		ps.println("\t-preload\tDo a read import first");		
	}
}
