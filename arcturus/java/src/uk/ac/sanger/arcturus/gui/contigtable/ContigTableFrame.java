package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.table.*;
import java.awt.*;
import java.awt.event.*;
import java.net.*;
import java.util.Set;
import uk.ac.sanger.arcturus.gui.Minerva;
import uk.ac.sanger.arcturus.gui.MinervaFrame;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigTableFrame extends MinervaFrame implements ActionListener,
		ItemListener {
	/**
	 * 
	 */
	private static final long serialVersionUID = -7452550307617586529L;
	ContigTable contigTable;
	JPopupMenu popupMenu;
	JTableHeader tableHeader;
	JCheckBox checkColourByProject;
	JCheckBox checkGroupByProject;

	public ContigTableFrame(Minerva minerva, String title,
			ArcturusDatabase adb, Set contigs) {
		super(minerva, title);

		JPanel panel = new JPanel(new BorderLayout());

		JToolBar toolBar = new JToolBar();
		addButtons(toolBar);
		toolBar.setFloatable(false);
		toolBar.setRollover(true);

		panel.add(toolBar, BorderLayout.PAGE_START);

		ContigTableModel ctm = new ContigTableModel(adb, contigs);

		contigTable = new ContigTable(this, ctm);

		// contigTable.setTransferHandler(contigListHandler);
		// contigTable.setDragEnabled(true);

		JScrollPane scrollPane = new JScrollPane(contigTable);

		contigTable.addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				handleCellMouseClick(e);
			}

			public void mousePressed(MouseEvent e) {
				handleCellMouseClick(e);
			}

			public void mouseReleased(MouseEvent e) {
				handleCellMouseClick(e);
			}
		});

		panel.add(scrollPane, BorderLayout.CENTER);
		panel.setPreferredSize(new Dimension(900, 530));

		setContentPane(panel);

		popupMenu = new JPopupMenu();
		popupMenu.add(new JMenuItem("Select"));
		popupMenu.add(new JMenuItem("Delete"));
		popupMenu.addSeparator();
		popupMenu.add(new JMenuItem("Display"));
	}

	protected void addButtons(JToolBar toolBar) {
		checkColourByProject = new JCheckBox("Colour by project");
		checkColourByProject.addItemListener(this);
		toolBar.add(checkColourByProject);
		checkGroupByProject = new JCheckBox("Group by project");
		checkGroupByProject.addItemListener(this);
		toolBar.add(checkGroupByProject);
	}

	protected JButton makeNavigationButton(String imageName,
			String actionCommand, String toolTipText, String altText) {
		// Look for the image.
		String imgLocation = "/toolbarButtonGraphics/navigation/" + imageName
				+ ".gif";
		URL imageURL = getClass().getResource(imgLocation);

		// Create and initialize the button.
		JButton button = new JButton();
		button.setActionCommand(actionCommand);
		button.setToolTipText(toolTipText);
		button.addActionListener(this);

		if (imageURL != null) { // image found
			button.setIcon(new ImageIcon(imageURL, altText));
		} else { // no image found
			button.setText(altText);
			System.err.println("Resource not found: " + imgLocation);
		}

		return button;
	}

	public void actionPerformed(ActionEvent e) {
	}

	public void itemStateChanged(ItemEvent e) {
		Object source = e.getItemSelectable();

		if (source instanceof JCheckBox) {
			JCheckBox checkbox = (JCheckBox) source;

			if (checkbox == checkColourByProject) {
				if (e.getStateChange() == ItemEvent.SELECTED)
					contigTable.setHowToColour(ContigTable.BY_PROJECT);
				else
					contigTable.setHowToColour(ContigTable.BY_ROW_NUMBER);
			}

			if (checkbox == checkGroupByProject) {
				ContigTableModel ctm = (ContigTableModel) contigTable
						.getModel();
				ctm.setGroupByProject(e.getStateChange() == ItemEvent.SELECTED);
			}
		}
	}

	private void handleCellMouseClick(MouseEvent event) {
		Point point = event.getPoint();
		int row = contigTable.rowAtPoint(point);
		int col = contigTable.columnAtPoint(point);
		int modelcol = contigTable.convertColumnIndexToModel(col);

		if (event.isPopupTrigger()) {
			System.err.println("popup triggered at row " + row
					+ ", view column " + col + ", model column " + modelcol);
			popupMenu.show(event.getComponent(), event.getX(), event.getY());
		}

		if (event.getID() == MouseEvent.MOUSE_CLICKED
				&& event.getButton() == MouseEvent.BUTTON1
				&& event.getClickCount() == 2) {
			System.err.println("Double click at row " + row + ", view column "
					+ col + ", model column " + modelcol);
		}
	}
}
