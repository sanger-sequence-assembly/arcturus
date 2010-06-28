package uk.ac.sanger.arcturus.apps;

import java.io.IOException;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.util.HashSet;
import java.util.Set;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.samtools.SAMContigExporter;
import uk.ac.sanger.arcturus.samtools.SAMContigExporterEvent;
import uk.ac.sanger.arcturus.samtools.SAMContigExporterEventListener;

public class ContigExporter implements SAMContigExporterEventListener {
	public static void main(String[] args) {
		String instanceName = null;
		String organismName = null;
		String projectName = null;
		String outputFileName = null;
		String assemblyName = null;
		String contigList = null;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instanceName = args[++i];
			else if (args[i].equalsIgnoreCase("-organism"))
				organismName = args[++i];
			else if (args[i].equalsIgnoreCase("-assembly"))
				assemblyName = args[++i];
			else if (args[i].equalsIgnoreCase("-project"))
				projectName = args[++i];
			else if (args[i].equalsIgnoreCase("-contigs"))
				contigList = args[++i];
			else if (args[i].equalsIgnoreCase("-out"))
				outputFileName = args[++i];
		}
		
		if (instanceName == null 
				|| organismName == null 
				|| (projectName == null && contigList == null)
				|| outputFileName == null) {
			printUsage(System.err);
			System.exit(1);
		}
		
		if (projectName != null && contigList != null) {
			System.err.println("You should only specify one of -project and -contigs");
			System.exit(1);
		}
		
	    try { 	
 	        ArcturusInstance ai = ArcturusInstance.getInstance(instanceName);
 			ArcturusDatabase adb = ai.findArcturusDatabase(organismName);
			
			SAMContigExporter exporter = new SAMContigExporter(adb);
			
			PrintWriter pw = new PrintWriter(outputFileName);
			
			ContigExporter ce = new ContigExporter();
		
			if (projectName != null) {
				Assembly assembly = assemblyName == null ? null : adb.getAssemblyByName(assemblyName);
  			
				Project project = adb.getProjectByName(assembly, projectName);
			
				ce.run(exporter, project, pw);
			} else {
				String[] words = contigList.split(",");
				
				Set<Contig> contigSet = new HashSet<Contig>(words.length);
				
				for (String word : words) {
					int contig_id = Integer.parseInt(word);
					
					Contig contig = adb.getContigByID(contig_id, ArcturusDatabase.CONTIG_BASIC_DATA);
					
					contigSet.add(contig);
				}
				
				ce.run(exporter, contigSet, pw);
			}
			
			pw.close();
		}
		catch (IOException ioe) {
			ioe.printStackTrace();
			System.exit(2);
		}
		catch (ArcturusDatabaseException e) {
			e.printStackTrace();
			System.exit(3);
		} catch (NamingException e) {
			e.printStackTrace();
		}
		
		System.exit(0);
	}
	
	public void run(SAMContigExporter exporter, Project project, PrintWriter pw)
		throws ArcturusDatabaseException {		
		exporter.setSAMContigExporterEventListener(this);
		
		exporter.exportContigsForProject(project, pw);
	}
	
	public void run(SAMContigExporter exporter, Set<Contig> contigSet, PrintWriter pw)
		throws ArcturusDatabaseException {		
		exporter.setSAMContigExporterEventListener(this);
		
		exporter.exportContigSet(contigSet, pw);
	}

	private static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS");
		ps.println("\t-instance\tThe name of the instance");
		ps.println("\t-organism\tThe name of the organism");
		ps.println("\t-out\t\tThe name of the SAM file to be written");
		ps.println();
		ps.println("MANDATORY EXCLUSIVE PARAMETERS");
		ps.println("\t-project\tThe name of the project to be exported");
		ps.println("\t-contigs\tA comma-separated list of contig IDs to be exported");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-assembly\tThe name of the assembly, to disambiguate projects");
	}

	public void contigExporterUpdate(SAMContigExporterEvent event) {
		System.err.println(event.getType() + " : " + event.getValue());
	}
}
