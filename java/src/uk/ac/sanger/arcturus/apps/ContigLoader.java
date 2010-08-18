package uk.ac.sanger.arcturus.apps;

import java.io.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.samtools.BAMContigLoader;
import uk.ac.sanger.arcturus.samtools.BAMReadLoader;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.fasta.FastqFileReader;
import uk.ac.sanger.arcturus.fasta.SequenceProcessor;

import net.sf.samtools.*;

public class ContigLoader extends AbstractLoader {
	public static void main (String[] args) {
		ContigLoader loader = new ContigLoader();
		
		int rc = loader.run(args);
		
		System.exit(rc);
	}
	
	public int run(String[] args) {
		File bamFile = null;
		String projectName = null;
		String assemblyName = null;
		String instance = null;
		String organism = null;
		boolean preloadReads = false;
		String contigName = null;
		File consensusFile = null;
		
	    for (int i = 0; i < args.length; i++) {
            if (args[i].equalsIgnoreCase("-in"))
                bamFile = new File(args[++i]);
            else if (args[i].equalsIgnoreCase("-instance"))
                instance = args[++i];
            else if (args[i].equalsIgnoreCase("-organism"))
                organism = args[++i];
            else if (args[i].equalsIgnoreCase("-project"))
                projectName = args[++i];
            else if (args[i].equalsIgnoreCase("-assembly"))
                assemblyName = args[++i];
            else if (args[i].equalsIgnoreCase("-contig"))
            	contigName = args[++i];
            else if (args[i].equalsIgnoreCase("-preloadreads"))
                preloadReads = true;
            else if (args[i].equalsIgnoreCase("-consensus"))
            	consensusFile = new File(args[++i]);
            else {
            	System.err.println("Invalid parameter " + args[i]);
    		    showUsage(System.err);
    		    return 1;
            }
 	    }

	    if (instance == null || organism == null || (bamFile == null && consensusFile == null)) {
		    showUsage(System.err);
		    return 1;
		}
	    
	    try {	    	
 	        ArcturusInstance ai = ArcturusInstance.getInstance(instance);
 			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
			
 			Project project = null;
 			
 			if (projectName != null) {
 				Assembly assembly = null;
 				
 				if (assemblyName != null)
 				    assembly = adb.getAssemblyByName(assemblyName);
 				
  			    project = adb.getProjectByName(assembly,projectName);
 			}

 
 			if (bamFile != null) {
				SAMFileReader
						.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);

				SAMFileReader reader = new SAMFileReader(bamFile);

				if (reader.isBinary() == false || reader.hasIndex() == false)
					throw new IllegalArgumentException(
							"The input file is not indexed: " + bamFile);

				BAMReadLoader brl = createBAMReadLoader(adb);

				if (preloadReads)
					brl.processFile(reader);

				BAMContigLoader bcl = new BAMContigLoader(adb, brl);

				bcl.processFile(reader, project, contigName);
 			}
 			
 			if (consensusFile != null) {
 				if (consensusFile.exists() && consensusFile.canRead()) {
					ConsensusFileProcessor processor = new ConsensusFileProcessor(adb);

					FastqFileReader reader = new FastqFileReader();
					
					System.out.println("PROCESSING CONTIG CONSENSUS SEQUENCES");

					reader.processFile(consensusFile, processor);
 				} else
 					Arcturus.logWarning("The consensus file " + consensusFile + " does not exist or cannot be read");
 			}
	    }
	    catch(Exception e) {
	    	Arcturus.logWarning("Failed to initialise or execute the contig loader", e);
	    	return 1;
	    }
	    
    	return 0;
	}
	
	class ConsensusFileProcessor implements SequenceProcessor {
		private ArcturusDatabase adb;
		
		public ConsensusFileProcessor(ArcturusDatabase adb) {
			this.adb = adb;
		}
		
		public void processSequence(String name, byte[] dna, byte[] quality) {
			if (dna == null)
				return;
			
			System.out.println("\nContig " + name + " : consensus length is " + dna.length + " bp");
			
			try {
				Contig contig = adb.getContigByName(name);
				
				if (contig == null) {
					System.out.println("\tIGNORED consensus, because no matching contig was found in the database.");
				} else {
					contig.setConsensus(dna, quality);
					
					adb.putContigConsensus(contig);
					
					System.out.println("\tSTORED consensus for contig " + name +
							" (Arcturus ID " + contig.getID() + ")");
					
					contig.setConsensus(null, null);
				}
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to store consensus for contig with name \"" + name + "\"", e);
			}
		}		
	}
	
	public void showUsage(PrintStream ps) {
		ps.println("Invalid or missing input parameters");
		ps.println();
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("AT LEAST ONE INPUT FILE MUST BE SPECIFIED:");
		ps.println("\t-in\t\tName of ordered and indexed BAM file to be imported");
		ps.println("\t-consensus\tName of FASTQ file containing the contig consensus sequences");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-project\tName of project");		
		ps.println("\t-assembly\tName of project assembly");		
		ps.println("\t-contig\t\tName of a specific reference sequence");		
		ps.println("\t-preloadreads\tDo a read import first");		
	}
}
