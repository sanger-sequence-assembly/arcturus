package uk.ac.sanger.arcturus.gui.projecttable;

import java.awt.*;
import java.awt.event.*;

import javax.swing.*;
import javax.swing.event.PopupMenuEvent;
import javax.swing.event.PopupMenuListener;
import javax.swing.table.*;

import java.sql.SQLException;
import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.gui.*;

import uk.ac.sanger.arcturus.gui.contigtable.ContigTablePanel;
import uk.ac.sanger.arcturus.gui.scaffoldtable.ScaffoldTableFrame;
import uk.ac.sanger.arcturus.people.*;

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ProjectLockException;

public class ProjectTable extends SortableTable {
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected Project projectForPopup;

	protected JMenuItem itemUnlockProject = new JMenuItem("Unlock");
	protected JMenuItem itemLockAsOwner = new JMenuItem("Set owner lock");
	protected JMenuItem itemLockAsMe = new JMenuItem("Acquire lock");

	protected JPopupMenu popupLock = new JPopupMenu();
	
	protected Person me = PeopleManager.findMe();
	protected ArcturusDatabase adb;

	public ProjectTable(ProjectTableModel ptm) {
		super((SortableTableModel) ptm);

		addMouseListener(new MouseAdapter() {
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

		createPopupMenus();
		
		adb = ptm.adb;
	}

	private void createPopupMenus() {
		popupLock.add(itemUnlockProject);
		popupLock.addSeparator();
		popupLock.add(itemLockAsOwner);
		popupLock.add(itemLockAsMe);

		itemUnlockProject.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				unlockProject();
			}
		});

		itemLockAsOwner.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				lockProjectAsOwner();
			}
		});

		itemLockAsMe.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				lockProjectAsMe();
			}
		});

		popupLock.addPopupMenuListener(new PopupMenuListener() {

			public void popupMenuCanceled(PopupMenuEvent e) {
				// Do nothing
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
				// Do nothing
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
				boolean noOwner = projectForPopup.isUnowned();

				String pname = projectForPopup.getName();

				try {
					itemUnlockProject.setEnabled(adb.canUserUnlockProject(projectForPopup, me));
				} catch (SQLException sqle) {
					Arcturus.logWarning("Failed to obtain user privileges", sqle);
				}
				
				itemUnlockProject.setText("Unlock " + pname);

				try {
					itemLockAsOwner.setEnabled(adb.canUserLockProjectForOwner(projectForPopup, me) &&
							!projectForPopup.isMine());
				} catch (SQLException sqle) {
					Arcturus.logWarning("Failed to obtain user privileges", sqle);
				}

				itemLockAsOwner.setText(noOwner ? "(" + pname
						+ " has no owner)" : "Set lock on " + pname + " for "
						+ projectForPopup.getOwner().getName());

				try {
					itemLockAsMe.setEnabled(adb.canUserLockProject(projectForPopup, me));
				} catch (SQLException sqle) {
					Arcturus.logWarning("Failed to obtain user privileges", sqle);
				}
				
				itemLockAsMe.setText("Acquire lock on " + pname);
			}
		});
	}

	private void handleCellMouseClick(MouseEvent event) {
		if (event.isPopupTrigger()) {
			Point point = event.getPoint();

			int row = rowAtPoint(point);
			ProjectProxy proxy = ((ProjectTableModel) getModel())
					.getProjectAtRow(row);
			projectForPopup = proxy.getProject();

			int column = columnAtPoint(point);
			int modelColumn = convertColumnIndexToModel(column);

			switch (modelColumn) {
				case ProjectTableModel.LOCKED_COLUMN:
					showProjectLockPopup(event);
					break;

				case ProjectTableModel.OWNER_COLUMN:
					showProjectOwnerPopup(event);
					break;
			}
		} else if (event.getID() == MouseEvent.MOUSE_CLICKED
				&& event.getButton() == MouseEvent.BUTTON1
				&& event.getClickCount() == 2) {
			displaySelectedProjects();
		}
	}

	private void showProjectOwnerPopup(MouseEvent event) {
		JOptionPane.showMessageDialog(getParent(),
				"At this point, you would see the project owner popup menu",
				"Project Owner Popup", JOptionPane.INFORMATION_MESSAGE, null);

	}

	private void showProjectLockPopup(MouseEvent event) {
		popupLock.show(event.getComponent(), event.getX(), event.getY());
	}

	protected void unlockProject() {
		try {
			adb.unlockProject(projectForPopup);
		} catch (ProjectLockException e) {
			Arcturus.logWarning("Failed to unlock project", e);
		} catch (SQLException e) {
			Arcturus.logWarning("Failed to unlock project", e);
		}
	}

	protected void lockProjectAsMe() {
		try {
			adb.lockProject(projectForPopup);
		} catch (ProjectLockException e) {
			Arcturus.logWarning("Failed to lock project", e);
		} catch (SQLException e) {
			Arcturus.logWarning("Failed to lock project", e);
		}
	}

	protected void lockProjectAsOwner() {
		try {
			adb.lockProjectForOwner(projectForPopup);
		} catch (ProjectLockException e) {
			Arcturus.logWarning("Failed to lock project for owner", e);
		} catch (SQLException e) {
			Arcturus.logWarning("Failed to lock project for owner", e);
		}
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

		if (isCellSelected(rowIndex, vColIndex)) {
			c.setBackground(getBackground());
			c.setForeground(Color.RED);
		} else {
			if (rowIndex % 2 == 0) {
				c.setBackground(VIOLET1);
			} else {
				c.setBackground(VIOLET2);
			}
			c.setForeground(Color.BLACK);
		}

		ProjectTableModel ptm = (ProjectTableModel) getModel();
		ProjectProxy proxy = ptm.getProjectAtRow(rowIndex);

		if (proxy.isMine()) {
			Font font = c.getFont().deriveFont(Font.BOLD);
			c.setFont(font);
		}
		
		if (proxy.isImporting() || proxy.isExporting())
			c.setForeground(Color.lightGray);

		return c;
	}

	public ProjectList getSelectedValues() {
		int[] indices = getSelectedRows();
		ProjectTableModel ptm = (ProjectTableModel) getModel();
		ProjectList clist = new ProjectList();
		for (int i = 0; i < indices.length; i++)
			clist.add(ptm.elementAt(indices[i]));

		return clist;
	}

	public ProjectProxy getSelectedProject() {
		int[] indices = getSelectedRows();

		switch (indices.length) {
			case 0:
				return null;

			case 1:
				return (ProjectProxy) ((ProjectTableModel) getModel())
						.elementAt(indices[0]);

			default:
				Arcturus
						.logWarning("Project table has more than one selected project");
				return null;
		}
	}

	public void displaySelectedProjects() {
		int[] indices = getSelectedRows();

		if (indices.length == 0)
			return;

		ProjectTableModel ptm = (ProjectTableModel) getModel();

		Project[] projects = new Project[indices.length];

		String title = null;

		String names[] = new String[indices.length];

		for (int i = 0; i < indices.length; i++) {
			ProjectProxy proxy = (ProjectProxy) ptm.elementAt(indices[i]);
			projects[i] = proxy.getProject();
			names[i] = projects[i].getName();
		}

		Arrays.sort(names);

		for (int i = 0; i < names.length; i++) {
			if (i == 0)
				title = names[i];
			else
				title += "," + names[i];
		}

		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);

		ContigTablePanel ctp = new ContigTablePanel(projects, mtp);

		mtp.add(title, ctp);

		JFrame frame = (JFrame) SwingUtilities.getRoot(mtp);
		frame.pack();

		mtp.setSelectedComponent(ctp);
	}

	public void scaffoldSelectedProjects() {
		int[] indices = getSelectedRows();

		if (indices.length == 0)
			return;

		String title = "Scaffold:";

		ProjectTableModel ptm = (ProjectTableModel) getModel();

		Set projects = new HashSet();

		for (int i = 0; i < indices.length; i++) {
			ProjectProxy proxy = (ProjectProxy) ptm.elementAt(indices[i]);
			Project project = proxy.getProject();
			projects.add(project);

			title += ((i > 0) ? "," : " ") + project.getName();
		}

		Minerva minerva = Minerva.getInstance();

		ArcturusDatabase adb = ptm.getArcturusDatabase();

		ScaffoldTableFrame.createAndShowFrame(minerva, title, adb, projects);
	}
}