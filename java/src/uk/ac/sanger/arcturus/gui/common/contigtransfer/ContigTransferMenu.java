package uk.ac.sanger.arcturus.gui.common.contigtransfer;

import java.util.Comparator;
import java.util.Set;
import java.util.SortedSet;
import java.util.TreeSet;

import javax.swing.JMenu;

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.gui.VerticalGridLayout;
import uk.ac.sanger.arcturus.people.Person;

public class ContigTransferMenu extends JMenu {
	private ContigTransferSource source;
	private ArcturusDatabase adb;
	
	protected final ProjectComparator comparator = new ProjectComparator();

	public ContigTransferMenu(String caption, ContigTransferSource source, ArcturusDatabase adb) {
		super(caption);
		this.source = source;
		this.adb = adb;
	}
	
	public void refreshMenu() throws ArcturusDatabaseException {
		removeAll();
		
		Person me = adb.findMe();

		Set<Project> mypset = null;
		
		if (adb.isCoordinator())
			mypset = adb.getAllProjects();
		else
			mypset = adb.getProjectsForOwner(me);

		SortedSet<Project> myProjects = new TreeSet<Project>(comparator);
		
		if (mypset != null && !mypset.isEmpty()) {
			myProjects.addAll(mypset);

			for (Project project : myProjects)
				if (!project.isBin()) {
					ContigTransferAction action = new ContigTransferAction(source, project);
					action.setEnabled(project.isActive());
					add(action);
				}
			
			Set<Project> bin = null;

			bin = adb.getBinProjects();

			if (bin != null) {
				myProjects.clear();
				myProjects.addAll(bin);
				addSeparator();
				for (Project project : myProjects)
					add(new ContigTransferAction(source, project));
			}
			
			if (getMenuComponentCount() > 40) {	        
				VerticalGridLayout menuGrid = new VerticalGridLayout(40,0);   
		        getPopupMenu().setLayout(menuGrid); 
			}
		}
	}

	class ProjectComparator implements Comparator<Project> {
		public int compare(Project p1, Project p2) {
			return p1.getName().compareTo(p2.getName());
		}
	}
}
