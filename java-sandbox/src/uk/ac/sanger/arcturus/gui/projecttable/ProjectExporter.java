package uk.ac.sanger.arcturus.gui.projecttable;

public class ProjectExporter extends ProjectImporterExporter {
	public ProjectExporter(ProjectProxy proxy, String directory,
			ProjectTablePanel parent) {
		super(proxy, directory, parent, EXPORT);
	}
}
