package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import java.awt.*;

import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.gui.projecttable.ProjectTablePanel;

public class MinervaTabbedPane extends JTabbedPane implements MinervaClient {
	private ArcturusDatabase adb;
	private ProjectTablePanel ptp;

	public MinervaTabbedPane(ArcturusDatabase adb) {
		super();
		this.adb = adb;
	}

	public JMenuBar getMenuBar() {
		Component component = getSelectedComponent();

		if (component instanceof MinervaClient)
			return ((MinervaClient) component).getMenuBar();
		else
			return null;
	}

	public JToolBar getToolBar() {
		Component component = getSelectedComponent();

		if (component instanceof MinervaClient)
			return ((MinervaClient) component).getToolBar();
		else
			return null;
	}

	public ProjectTablePanel addProjectTablePanel() {
		if (ptp == null)
			ptp = new ProjectTablePanel(adb);

		if (indexOfComponent(ptp) < 0)
			addTab("Projects", null, ptp, "All projects");

		return ptp;
	}
	
	public static MinervaTabbedPane getTabbedPane(Component component) {
		Container c = component.getParent();
		
		while (c != null && !(c instanceof Frame)) {
			if (c instanceof MinervaTabbedPane)
				return (MinervaTabbedPane)c;
			
			c = c.getParent();
		}
		
		return null;
	}
}
