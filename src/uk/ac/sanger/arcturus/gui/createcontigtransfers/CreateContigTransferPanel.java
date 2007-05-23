package uk.ac.sanger.arcturus.gui.createcontigtransfers;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ContigTransferRequestManager;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.sql.SQLException;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import java.util.zip.DataFormatException;
import java.io.*;

public class CreateContigTransferPanel extends MinervaPanel {
	protected JTextArea txtContigList = new JTextArea(20, 32);
	protected JList lstProjects;
	protected JTextArea txtMessages = new JTextArea(20, 40);
	protected JButton btnTransferContigs;
	protected JButton btnClearMessages = new JButton("Clear messages");

	protected ProjectListModel plm;

	protected MinervaAbstractAction actionTransferContigs;
	protected MinervaAbstractAction actionGetContigsFromFile;

	protected JFileChooser fileChooser = new JFileChooser();

	public CreateContigTransferPanel(ArcturusDatabase adb,
			MinervaTabbedPane parent) {
		super(parent, adb);

		this.adb = adb;

		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);

		JPanel topPanel = new JPanel();

		topPanel.setLayout(new BoxLayout(topPanel, BoxLayout.X_AXIS));

		// Set up the text area for the list of reads

		JScrollPane scrollpane = new JScrollPane(txtContigList,
				JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
				JScrollPane.HORIZONTAL_SCROLLBAR_NEVER);

		txtContigList.getDocument().addDocumentListener(new DocumentListener() {
			public void changedUpdate(DocumentEvent e) {
				// Do nothing
			}

			public void insertUpdate(DocumentEvent e) {
				updateTransferContigsButton();
			}

			public void removeUpdate(DocumentEvent e) {
				updateTransferContigsButton();
			}
		});

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);

		JButton btnClearContigs = new JButton("Clear contig list");
		panel.add(btnClearContigs, BorderLayout.SOUTH);

		btnClearContigs.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtContigList.setText("");
			}
		});

		panel.setBorder(etchedTitledBorder("Contigs to transfer"));

		topPanel.add(panel);

		panel = new JPanel(new BorderLayout());

		plm = new ProjectListModel(adb);

		lstProjects = new JList(plm);

		lstProjects.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

		scrollpane = new JScrollPane(lstProjects);

		panel.add(scrollpane, BorderLayout.CENTER);

		btnTransferContigs = new JButton(actionTransferContigs);

		panel.setBorder(etchedTitledBorder("Projects"));

		topPanel.add(panel);

		add(topPanel);

		panel = new JPanel(new FlowLayout());

		panel.add(btnTransferContigs);

		add(panel);

		scrollpane = new JScrollPane(txtMessages);

		panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);

		panel.add(btnClearMessages, BorderLayout.SOUTH);

		btnClearMessages.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtMessages.setText("");
			}
		});

		panel.setBorder(etchedTitledBorder("Information"));

		add(panel);
	}

	protected void createActions() {
		actionGetContigsFromFile = new MinervaAbstractAction(
				"Open file of contig names", null, "Open contig of read names",
				new Integer(KeyEvent.VK_O), KeyStroke.getKeyStroke(
						KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				getContigsFromFile();
			}
		};

		actionTransferContigs = new MinervaAbstractAction("Transfer contigs",
				null, "Transfer contigs", new Integer(KeyEvent.VK_I), KeyStroke
						.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				createContigTransferRequests();
			}
		};

		actionTransferContigs.setEnabled(false);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionGetContigsFromFile);

		return true;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	protected void createClassSpecificMenus() {
	}

	protected Border etchedTitledBorder(String title) {
		Border etched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		return BorderFactory.createTitledBorder(etched, title);
	}

	public void refresh() {
		// Does nothing
	}

	protected void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	public void closeResources() {
	}

	protected void getContigsFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			addContigsToList(fileChooser.getSelectedFile());
		}
	}

	protected void addContigsToList(File file) {
		try {
			BufferedReader br = new BufferedReader(new FileReader(file));

			String line;

			while ((line = br.readLine()) != null) {
				txtContigList.append(line);
				txtContigList.append("\n");
			}

			br.close();
		} catch (IOException ioe) {
			Arcturus.logWarning("Error encountered whilst reading file "
					+ file.getPath(), ioe);
		}
	}

	protected void createContigTransferRequests() {
		ProjectProxy proxy = (ProjectProxy) lstProjects.getSelectedValue();

		Project defaultProject = proxy == null ? null : proxy.getProject();

		String projectName = defaultProject == null ? "(null)" : defaultProject
				.getName();

		String text = txtContigList.getText();

		String[] lines = text.split("[\n\r]");

		for (int i = 0; i < lines.length; i++) {
			String[] words = lines[i].trim().split("[ \t]");

			if (words.length == 0 || words[0].length() == 0)
				continue;

			if (words.length == 2 || (words.length == 1 && projectName != null)) {
				String contigname = words[0];
				String pname = words.length == 2 ? words[1] : projectName;

				Contig contig = null;
				Project project = null;

				try {
					if (contigname.matches("^\\d+$")) {
						int contig_id = Integer.parseInt(contigname);
						contig = adb.isCurrentContig(contig_id) ? adb
								.getContigByID(contig_id) : null;
					} else {
						contig = adb.getContigByReadName(contigname);
					}

					project = words.length == 1 ? defaultProject : adb
							.getProjectByName(null, pname);
				} catch (SQLException e) {
					Arcturus.logWarning("Failed to find contig", e);
				} catch (DataFormatException e) {
					Arcturus.logWarning("Failed to find contig", e);
				}

				if (contig == null) {
					appendMessage(lines[i]
							+ "  : Unable to find contig in current set");
				} else if (project == null) {
					appendMessage(lines[i]
							+ " : Unable to find specified project");
				} else {
					appendMessage("--------------------------------------------------------------------------------");
					appendMessage("Submitting request to transfer contig "
							+ contig.getID() + " to project "
							+ project.getName());

					try {
						ContigTransferRequest request = adb
								.createContigTransferRequest(contig, project);
						
						appendMessage("New contig transfer request:" + ContigTransferRequestManager.prettyPrint(request));
					} catch (ContigTransferRequestException e) {
						appendMessage("Unable to create a contig transfer request: "
								+ e.getTypeAsString());
					} catch (SQLException e) {
						Arcturus
								.logWarning(
										"SQL exception whilst creating a contig transfer request",
										e);
						appendMessage("SQL Exception: " + e.getMessage());
					}
				}
			} else {
				appendMessage("Invalid request: \"" + lines[i] + "\"");
			}
		}
	}

	protected void updateTransferContigsButton() {
		boolean haveContigsInList = txtContigList.getDocument().getLength() > 0;

		actionTransferContigs.setEnabled(haveContigsInList);
	}

	public boolean setSelectedProject(String name) {
		ProjectProxy proxy = plm.getProjectProxyByName(name);

		if (proxy == null)
			return false;
		else {
			lstProjects.setSelectedValue(proxy, true);
			return true;
		}
	}

	class ProjectListModel extends AbstractListModel {
		ProjectProxy[] projects;
		ArcturusDatabase adb;

		public ProjectListModel(ArcturusDatabase adb) {
			this.adb = adb;
			refresh();
		}

		public void refresh() {
			try {
				Set projectset = adb.getAllProjects();

				projects = new ProjectProxy[projectset.size()];

				int i = 0;

				for (Iterator iter = projectset.iterator(); iter.hasNext(); i++) {
					Project project = (Project) iter.next();
					projects[i] = new ProjectProxy(project);
				}

				Arrays.sort(projects);
				fireContentsChanged(this, 0, projects.length);
			} catch (SQLException sqle) {
				Arcturus.logWarning("Error whilst refreshing project list",
						sqle);
			}
		}

		public Object getElementAt(int index) {
			return projects[index];
		}

		public int getSize() {
			return projects.length;
		}

		public ProjectProxy getProjectProxyByName(String name) {
			for (int i = 0; i < projects.length; i++)
				if (projects[i].toString().equalsIgnoreCase(name))
					return projects[i];

			return null;
		}
	}

	class ProjectProxy implements Comparable {
		protected final Project project;

		public ProjectProxy(Project project) {
			this.project = project;
		}

		public Project getProject() {
			return project;
		}

		public String toString() {
			return project.getName();
		}

		public int compareTo(Object o) {
			ProjectProxy that = (ProjectProxy) o;
			return project.getName()
					.compareToIgnoreCase(that.project.getName());
		}
	}

	protected boolean isRefreshable() {
		return false;
	}

	protected void doPrint() {
		// Do nothing.
	}

	protected void appendMessage(String message) {
		txtMessages.append(message);
		txtMessages.append("\n");
	}
}
