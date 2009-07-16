package uk.ac.sanger.arcturus.gui.projecttable;

public class ProjectImporter extends ProjectImporterExporter {
	public ProjectImporter(ProjectProxy proxy, String directory,
			ProjectTablePanel parent) {
		super(proxy, directory, parent, IMPORT);
	}
}
