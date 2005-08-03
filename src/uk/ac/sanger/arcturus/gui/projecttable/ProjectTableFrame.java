package uk.ac.sanger.arcturus.gui.projecttable;

import uk.ac.sanger.arcturus.gui.*;

import javax.swing.*;
import java.awt.BorderLayout;
import java.awt.Dimension;

public class ProjectTableFrame extends MinervaFrame {
    public ProjectTableFrame(Minerva minerva) {
	super(minerva, "Project List : " +  minerva.getArcturusDatabase().getName());

	ProjectTableModel model = new ProjectTableModel( minerva.getArcturusDatabase());

	ProjectTable table = new ProjectTable(model);

	JScrollPane scrollpane = new JScrollPane(table);

	JPanel panel = new JPanel(new BorderLayout());

	panel.add(scrollpane, BorderLayout.CENTER);
	panel.setPreferredSize(new Dimension(600, 530));

	setContentPane(panel);
	pack();
	setVisible(true);
    }
}
