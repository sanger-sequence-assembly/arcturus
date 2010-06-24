package uk.ac.sanger.arcturus.apps;

import java.io.File;
import java.io.IOException;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.util.HashSet;
import java.util.Set;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.samtools.SAMContigExporter;

public class ContigExporter {
	public static void main(String[] args) {
		String instanceName = null;
		String organismName = null;
		String projectName = null;
		String outputFileName = null;
		String assemblyName = null;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instanceName = args[++i];
			else if (args[i].equalsIgnoreCase("-organism"))
				organismName = args[++i];
			else if (args[i].equalsIgnoreCase("-assembly"))
				assemblyName = args[++i];
			else if (args[i].equalsIgnoreCase("-project"))
				projectName = args[++i];
			else if (args[i].equalsIgnoreCase("-out"))
				outputFileName = args[++i];
		}
		
		if (instanceName == null || organismName == null || projectName == null || outputFileName == null) {
			printUsage(System.err);
			System.exit(1);
		}
		
	    try { 	
 	        ArcturusInstance ai = ArcturusInstance.getInstance(instanceName);
 			ArcturusDatabase adb = ai.findArcturusDatabase(organismName);
 			
  			Assembly assembly = assemblyName == null ? null : adb.getAssemblyByName(assemblyName);
  			
  			Project project = adb.getProjectByName(assembly,projectName);
			
			PrintWriter pw = new PrintWriter(outputFileName);
			
			SAMContigExporter exporter = new SAMContigExporter(adb);
			
			exporter.exportContigsForProject(project, pw);
			
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
	
	private static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS");
		ps.println("\t-instance\tThe name of the instance");
		ps.println("\t-organism\tThe name of the organism");
		ps.println("\t-project\tThe name of the project to be exported");
		ps.println("\t-out\tThe name of the SAM file to be written");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-assembly\tThe name of the assembly, to disambiguate projects");
	}
}
