package uk.ac.sanger.arcturus.gui.projecttable;

import uk.ac.sanger.arcturus.gui.*;

import javax.swing.*;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;

public class ProjectTableFrame extends MinervaFrame {
    protected ProjectTable table = null;
    protected JMenu projectMenu = null;

    public ProjectTableFrame(Minerva minerva) {
	super(minerva, "Project List : " +  minerva.getArcturusDatabase().getName());

	ProjectTableModel model = new ProjectTableModel( minerva.getArcturusDatabase());

	table = new ProjectTable(model);

	JScrollPane scrollpane = new JScrollPane(table);

	JPanel panel = new JPanel(new BorderLayout());

	panel.add(scrollpane, BorderLayout.CENTER);
	panel.setPreferredSize(new Dimension(700, 530));

	setContentPane(panel);

	projectMenu = new JMenu("Project");
	menubar.add(projectMenu);

	projectMenu.add(new ViewProjectAction("View selected project(s)")); 

	pack();
	setVisible(true);
    }

    class ViewProjectAction extends AbstractAction {
	public ViewProjectAction(String name) {
	    super(name);
	}

	public void actionPerformed(ActionEvent event) {
	    table.displaySelectedProjects();
	}
    }
}
