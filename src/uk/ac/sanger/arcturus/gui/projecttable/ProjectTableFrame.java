package uk.ac.sanger.arcturus.gui.projecttable;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.database.*;

import javax.swing.*;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

public class ProjectTableFrame extends MinervaFrame {
	/**
	 * 
	 */
	private static final long serialVersionUID = 1351208181264915551L;
	protected ProjectTable table = null;
	protected ProjectTableModel model = null;
	protected JMenu projectMenu = null;

	public ProjectTableFrame(Minerva minerva, ArcturusDatabase adb) {
		super(minerva, "Project List : " + adb.getName());

		model = new ProjectTableModel(adb);

		table = new ProjectTable(model);

		JScrollPane scrollpane = new JScrollPane(table);

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);
		panel.setPreferredSize(new Dimension(900, 530));

		setContentPane(panel);

		projectMenu = new JMenu("Project");
		menubar.add(projectMenu);

		projectMenu.add(new ViewProjectAction("View selected project(s)"));

		projectMenu.addSeparator();

		ButtonGroup group = new ButtonGroup();

		JRadioButtonMenuItem rbShowProjectDate = new JRadioButtonMenuItem(
				"Show project date");
		group.add(rbShowProjectDate);
		projectMenu.add(rbShowProjectDate);

		rbShowProjectDate.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.PROJECT_UPDATED_DATE);
			}
		});

		JRadioButtonMenuItem rbShowContigCreated = new JRadioButtonMenuItem(
				"Show contig creation date");
		group.add(rbShowContigCreated);
		projectMenu.add(rbShowContigCreated);

		rbShowContigCreated.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.CONTIG_CREATED_DATE);
			}
		});

		JRadioButtonMenuItem rbShowContigUpdated = new JRadioButtonMenuItem(
				"Show contig updated date");
		group.add(rbShowContigUpdated);
		projectMenu.add(rbShowContigUpdated);

		rbShowContigUpdated.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.CONTIG_UPDATED_DATE);
			}
		});

		model.setDateColumn(ProjectTableModel.CONTIG_UPDATED_DATE);
		rbShowContigUpdated.setSelected(true);

		pack();
		setVisible(true);
	}

	class ViewProjectAction extends AbstractAction {
		/**
		 * 
		 */
		private static final long serialVersionUID = 4286787816579294056L;

		public ViewProjectAction(String name) {
			super(name);
		}

		public void actionPerformed(ActionEvent event) {
			table.displaySelectedProjects();
		}
	}
}
