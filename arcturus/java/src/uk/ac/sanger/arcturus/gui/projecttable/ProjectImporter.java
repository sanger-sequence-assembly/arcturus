package uk.ac.sanger.arcturus.gui.projecttable;

import java.io.IOException;
import javax.swing.SwingUtilities;
import javax.swing.WindowConstants;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.jobrunner.*;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;

public class ProjectImporter extends Thread {
	protected ProjectProxy proxy;
	protected ProjectTablePanel parent;
	protected String directory;

	public ProjectImporter(ProjectProxy proxy, String directory,
			ProjectTablePanel parent) {
		this.proxy = proxy;
		this.directory = directory;
		this.parent = parent;
	}

	public void run() {
		JobPlacer placer = null;

		try {
			placer = new JobPlacer();
		} catch (Exception e) {
			Arcturus.logWarning("Unable to create a JobPlacer", e);
			return;
		}

		final String host;

		try {
			host = placer.findHost();
		} catch (IOException e) {
			Arcturus.logWarning("Unable to find a host for the job", e);
			return;
		}

		ArcturusDatabase adb = proxy.getProject().getArcturusDatabase();

		ArcturusInstance ai = adb.getInstance();
		
		String instance = ai == null ? null : ai.getName();

		if (instance == null) {
			Arcturus.logWarning("Arcturus.getDefaultInstance returned null",
					new Throwable());
			return;
		}

		String organism = adb.getName();

		if (organism == null) {
			Arcturus.logWarning(
					"Could not get name of organism from ArcturusDatabase",
					new Throwable());
			return;
		}

		String project = proxy.getName();

		if (project == null) {
			Arcturus.logWarning("Project name was null", new Throwable());
			return;
		}

		String importcommand = "/software/arcturus/utils/importintoarcturus";		
		
		final String command = importcommand + " -instance "
				+ instance + " -organism " + organism + " -project " + project;
		
		final String caption = "Importing " + instance + ":" + organism + ":" + project + " on " + host;

		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				final ImporterFrame frame = new ImporterFrame(host, directory, command,
						proxy, ProjectImporter.this, caption);
				
				frame.setSize(800, 600);
				frame.setDefaultCloseOperation(WindowConstants.DO_NOTHING_ON_CLOSE);
				frame.setVisible(true);
				frame.run();
			}
		});
	}

	class ImporterFrame extends StyledJobRunnerFrame {
		protected ProjectProxy proxy;
		protected ProjectImporter parent;

		public ImporterFrame(String hostname, String workingDirectory,
				String command, ProjectProxy proxy, ProjectImporter parent, String caption) {
			super(hostname, workingDirectory, command, caption);
			this.proxy = proxy;
			this.parent = parent;
		}

		public void run() {
			proxy.setImporting(true);
			super.run();
		}

		public void done(int rc) {
			super.done(rc);
			proxy.setImporting(false);

			ProjectChangeEvent event = new ProjectChangeEvent(this, proxy
					.getProject(), ProjectChangeEvent.IMPORTED);
			
			proxy.getProject().getArcturusDatabase().notifyProjectChangeEventListeners(event);
		}
	}
}
