package uk.ac.sanger.arcturus.gui.organismtable;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.gui.*;
import javax.swing.*;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;

public class OrganismTableFrame extends MinervaFrame {
	/**
	 * 
	 */
	private static final long serialVersionUID = 1308316002652882202L;
	protected OrganismTable table = null;
	protected JMenu organismMenu = null;

	public OrganismTableFrame(Minerva minerva, ArcturusInstance instance) {
		super(minerva, "Organism List : " + instance.getName());

		OrganismTableModel model = new OrganismTableModel(instance);

		table = new OrganismTable(model);

		JScrollPane scrollpane = new JScrollPane(table);

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);
		panel.setPreferredSize(new Dimension(700, 530));

		setContentPane(panel);

		organismMenu = new JMenu("Organism");
		menubar.add(organismMenu);

		organismMenu.add(new ViewOrganismAction("View selected organism(s)"));

		pack();
		setVisible(true);
	}

	class ViewOrganismAction extends AbstractAction {
		/**
		 * 
		 */
		private static final long serialVersionUID = 2412652544602521298L;

		public ViewOrganismAction(String name) {
			super(name);
		}

		public void actionPerformed(ActionEvent event) {
			table.displaySelectedOrganisms();
		}
	}
}
