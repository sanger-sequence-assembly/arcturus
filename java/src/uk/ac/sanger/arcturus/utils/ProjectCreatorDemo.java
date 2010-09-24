package uk.ac.sanger.arcturus.utils;

import java.io.PrintStream;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.gui.projecttable.NewProjectPanel;
import uk.ac.sanger.arcturus.gui.common.InputDialog;
import uk.ac.sanger.arcturus.gui.common.InputDialog.Status;

public class ProjectCreatorDemo {
	public static void main(String[] args) {
		ProjectCreatorDemo pc = new ProjectCreatorDemo();
		
		pc.run(args);
		
		System.exit(0);
	}
	
	public void run(String[] args) {
		String instance = null;
		String organism = null;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}
		
		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
			
			NewProjectPanel panel = new NewProjectPanel(adb);
			
			panel.refresh();
			
			InputDialog id = new InputDialog(null, "Create new project", panel);
			
			id.setOKActionEnabled(false);
			
			Status s = id.showDialog();
			
			System.err.println("Status is " + s);
			
			if (s == Status.OK) {
				System.err.println("Name:\t\t" + panel.getName());
				System.err.println("Assembly:\t" + panel.getAssembly().getName());
				System.err.println("Owner:\t\t" + panel.getOwner().getName());
				System.err.println("Directory:\t" + panel.getDirectory());
			}
		}
		catch (Exception e) {
			Arcturus.logWarning(e);
			System.exit(1);
		}
	}
	
	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
	}
}
