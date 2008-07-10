package uk.ac.sanger.arcturus.gui.projecttable;

import java.io.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.swing.SwingUtilities;
import javax.swing.WindowConstants;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.jobrunner.*;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;

public class ProjectImporterExporter extends Thread {
	public static final int IMPORT = 1;
	public static final int EXPORT = 2;

	protected ProjectProxy proxy;
	protected ProjectTablePanel parent;
	protected String directory;
	protected boolean importing;

	public ProjectImporterExporter(ProjectProxy proxy, String directory,
			ProjectTablePanel parent, int mode) {
		this.proxy = proxy;
		this.directory = directory;
		this.parent = parent;
		
		importing = mode == IMPORT;
	}

	public void run() {
		final String host = Arcturus.getProperty("jobplacer.host");

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

		String shellcommand = "/software/arcturus/utils/" + (importing ?
				"importintoarcturus" : "exportfromarcturus") + ".lsf";		
		
		final String command = shellcommand + " -instance " +
				instance + " -organism " + organism + " -project " + project;
		
		final String caption = (importing ? "Importing " : "Exporting ") + 
				instance + ":" + organism + ":" + project + " on " + host;
		
		PrintWriter logtmp = null;
		
		try {
			logtmp = createLogWriter(organism, project);
		} catch (IOException e) {
			Arcturus.logWarning("Failed to create log file for " + (importing ? "import" : "export") +
					" of " + project, e);
		}
		
		final PrintWriter log = logtmp;

		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				final StyledJobRunnerFrame frame = importing ?
						new ImporterFrame(host, directory, command,
								proxy, ProjectImporterExporter.this, caption, log) :
						new ExporterFrame(host, directory, command,
								proxy, ProjectImporterExporter.this, caption, log);		;
				
				frame.setSize(800, 600);
				frame.setDefaultCloseOperation(WindowConstants.DO_NOTHING_ON_CLOSE);
				frame.setVisible(true);
				frame.run();
			}
		});
	}

	private PrintWriter createLogWriter(String organism, String project) throws IOException {
		File userhome = new File(System.getProperty("user.home"));
		File dotarcturus = new File(userhome, ".arcturus");

		if (!dotarcturus.isDirectory())
			dotarcturus.mkdirs();
		
		Date now = new Date();
		
		DateFormat formatter = new SimpleDateFormat("yyyyMMMdd-HHmm");
		
		String datestring = formatter.format(now);

		String filename = (importing ? "import" : "export") + "-" + organism + "-" + project + 
			"-" + datestring + ".log";
		
		File logfile = new File(dotarcturus, filename);
		
		FileOutputStream fos = new FileOutputStream(logfile);
		
		return new PrintWriter(fos, true);
	}

	class ImporterFrame extends StyledJobRunnerFrame {
		protected ProjectProxy proxy;
		protected ProjectImporterExporter parent;

		public ImporterFrame(String hostname, String workingDirectory,
				String command, ProjectProxy proxy, ProjectImporterExporter parent,
				String caption, PrintWriter log) {
			super(hostname, workingDirectory, command, caption, log);
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
			
			proxy.getProject().getArcturusDatabase().notifyProjectChangeEventListeners(event, null);
		}
	}

	class ExporterFrame extends StyledJobRunnerFrame {
		protected ProjectProxy proxy;
		protected ProjectImporterExporter parent;

		public ExporterFrame(String hostname, String workingDirectory,
				String command, ProjectProxy proxy, ProjectImporterExporter parent,
				String caption, PrintWriter log) {
			super(hostname, workingDirectory, command, caption, log);
			this.proxy = proxy;
			this.parent = parent;
		}

		public void run() {
			proxy.setExporting(true);
			super.run();
		}

		public void done(int rc) {
			super.done(rc);
			proxy.setExporting(false);
		}
	}

}
