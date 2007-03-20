package uk.ac.sanger.arcturus.gui.oligofinder;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.oligo.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.sql.SQLException;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import java.io.*;

public class OligoFinderPanel extends JPanel implements MinervaClient,
		OligoFinderEventListener {
	private OligoFinder finder;
	private JMenuBar menubar = new JMenuBar();

	private JTextArea txtOligoList = new JTextArea(20, 60);
	private JList lstProjects;
	private JTextArea txtMessages = new JTextArea(20, 40);
	private JButton btnFindOligos;
	private JButton btnClearMessages = new JButton("Clear messages");
	private JProgressBar pbarTaskProgress = new JProgressBar();
	private JCheckBox cbSelectAll = new JCheckBox("All projects");

	private ProjectListModel plm;

	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionFindOligos;
	private MinervaAbstractAction actionGetOligosFromFile;
	private MinervaAbstractAction actionHelp;

	private JFileChooser fileChooser = new JFileChooser();

	private int bpdone;

	private boolean showHashMatch = false;
	
	private HashMap oligomatches = new HashMap();

	public OligoFinderPanel(ArcturusDatabase adb) {
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		finder = new OligoFinder(adb, this);

		createActions();

		createMenus();

		JPanel topPanel = new JPanel();

		topPanel.setLayout(new BoxLayout(topPanel, BoxLayout.X_AXIS));

		// Set up the text area for the list of reads

		JScrollPane scrollpane = new JScrollPane(txtOligoList,
				JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
				JScrollPane.HORIZONTAL_SCROLLBAR_NEVER);

		txtOligoList.getDocument().addDocumentListener(new DocumentListener() {
			public void changedUpdate(DocumentEvent e) {
				// Do nothing
			}

			public void insertUpdate(DocumentEvent e) {
				updateFindOligosButton();
			}

			public void removeUpdate(DocumentEvent e) {
				updateFindOligosButton();
			}
		});

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);

		panel.setBorder(etchedTitledBorder("Oligos to search for"));

		topPanel.add(panel);

		panel = new JPanel(new BorderLayout());

		plm = new ProjectListModel(adb);

		lstProjects = new JList(plm);

		lstProjects
				.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);

		lstProjects.addListSelectionListener(new ListSelectionListener() {
			public void valueChanged(ListSelectionEvent e) {
				updateFindOligosButton();
			}
		});

		scrollpane = new JScrollPane(lstProjects);

		panel.add(scrollpane, BorderLayout.CENTER);

		btnFindOligos = new JButton(actionFindOligos);

		panel.add(btnFindOligos, BorderLayout.SOUTH);

		panel.setBorder(etchedTitledBorder("Projects to search"));

		topPanel.add(panel);

		add(topPanel);

		panel = new JPanel(new FlowLayout());

		panel.add(btnFindOligos);

		cbSelectAll.setSelected(false);
		panel.add(cbSelectAll);

		cbSelectAll.addChangeListener(new ChangeListener() {
			public void stateChanged(ChangeEvent e) {
				if (cbSelectAll.isSelected()) {
					int start = 0;
					int end = lstProjects.getModel().getSize() - 1;
					if (end >= 0) {
						lstProjects.setSelectionInterval(start, end); // A, B,
																		// C, D
					}
				} else {
					lstProjects.clearSelection();
				}

			}
		});

		add(panel);

		add(pbarTaskProgress);

		pbarTaskProgress.setStringPainted(true);

		scrollpane = new JScrollPane(txtMessages);

		panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);

		panel.add(btnClearMessages, BorderLayout.SOUTH);

		btnClearMessages.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtMessages.selectAll();
				txtMessages.cut();
			}
		});

		panel.setBorder(etchedTitledBorder("Information"));

		add(panel);

		showHashMatch = Boolean.getBoolean("showHashMatch");
	}

	private void createActions() {
		actionClose = new MinervaAbstractAction("Close", null,
				"Close this window", new Integer(KeyEvent.VK_C), KeyStroke
						.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				closePanel();
			}
		};

		actionGetOligosFromFile = new MinervaAbstractAction(
				"Open file of oligos", null, "Open file of oligos",
				new Integer(KeyEvent.VK_O), KeyStroke.getKeyStroke(
						KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				getOligosFromFile();
			}
		};

		actionFindOligos = new MinervaAbstractAction("Find oligos", null,
				"Find oligos in selected projects", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				findOligoMatches();
			}
		};

		actionFindOligos.setEnabled(false);

		actionHelp = new MinervaAbstractAction("Help", null, "Help",
				new Integer(KeyEvent.VK_H), KeyStroke.getKeyStroke(
						KeyEvent.VK_F1, 0)) {
			public void actionPerformed(ActionEvent e) {
				Minerva.displayHelp();
			}
		};
	}

	private void createMenus() {
		createFileMenu();
		createEditMenu();
		createViewMenu();
		menubar.add(Box.createHorizontalGlue());
		createHelpMenu();
	}

	private JMenu createMenu(String name, int mnemonic, String description) {
		JMenu menu = new JMenu(name);

		menu.setMnemonic(mnemonic);

		if (description != null)
			menu.getAccessibleContext().setAccessibleDescription(description);

		return menu;
	}

	private void createFileMenu() {
		JMenu fileMenu = createMenu("File", KeyEvent.VK_F, "File");
		menubar.add(fileMenu);

		fileMenu.add(actionGetOligosFromFile);

		fileMenu.addSeparator();

		fileMenu.add(actionClose);

		fileMenu.addSeparator();

		fileMenu.add(Minerva.getQuitAction());
	}

	private void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}

	private void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);
	}

	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);

		helpMenu.add(actionHelp);
	}

	private Border etchedTitledBorder(String title) {
		Border etched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		return BorderFactory.createTitledBorder(etched, title);
	}

	public JMenuBar getMenuBar() {
		return menubar;
	}

	public JToolBar getToolBar() {
		return null;
	}

	public void refresh() {
		if (plm != null) {
			try {
				plm.refresh();
			} catch (SQLException sqle) {
				Arcturus.logWarning(
						"An error occurred when refreshing the project list",
						sqle);
			}
		}
	}

	private void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	public void closeResources() {
	}

	private void getOligosFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			addOligosToList(fileChooser.getSelectedFile());
		}
	}

	private void addOligosToList(File file) {
		try {
			BufferedReader br = new BufferedReader(new FileReader(file));

			String line;

			while ((line = br.readLine()) != null) {
				txtOligoList.append(line);
				txtOligoList.append("\n");
			}

			br.close();
		} catch (IOException ioe) {
			Arcturus.logWarning("Error encountered whilst reading file "
					+ file.getPath(), ioe);
		}
	}

	private void findOligoMatches() {
		Object[] selected = lstProjects.getSelectedValues();

		Project[] projects = new Project[selected.length];

		for (int i = 0; i < selected.length; i++) {
			ProjectProxy proxy = (ProjectProxy) selected[i];
			projects[i] = proxy.getProject();
		}

		Oligo[] oligos = parseOligos(txtOligoList.getText());

		txtMessages.append("Searching for oligos:\n\n");

		for (int i = 0; i < oligos.length; i++)
			if (oligos[i] != null)
				txtMessages.append(oligos[i].getName() + " : "
						+ oligos[i].getSequence() + "\n");

		txtMessages.append("\n\n");

		oligomatches.clear();
		
		Task task = new Task(finder, oligos, projects);

		task.start();
	}

	class Task extends Thread {
		private final OligoFinder finder;
		private final Oligo[] oligos;
		private final Project[] projects;

		public Task(OligoFinder finder, Oligo[] oligos, Project[] projects) {
			this.finder = finder;
			this.oligos = oligos;
			this.projects = projects;
		}

		public void run() {
			try {
				finder.findMatches(oligos, projects);
			} catch (SQLException sqle) {
				Arcturus.logWarning("An error occurred whilst finding matches",
						sqle);
			}
		}
	}

	private Oligo[] parseOligos(String text) {
		String[] lines = text.split("[\n\r]+");

		Oligo[] oligos = new Oligo[lines.length];

		int anon = 0;

		for (int i = 0; i < lines.length; i++) {
			String[] words = lines[i].split("\\s");

			String name;
			String sequence;

			if (words.length < 1)
				continue;

			if (words.length == 1) {
				name = "ANON." + (++anon);
				sequence = words[0];
			} else {
				name = words[0];
				sequence = words[1];
			}

			oligos[i] = new Oligo(name, sequence);
		}

		return oligos;
	}

	public void oligoFinderUpdate(OligoFinderEvent event) {
		int type = event.getType();
		int offset = event.getOffset();

		switch (type) {
			case OligoFinderEvent.START:
				bpdone = 0;
				initProgressBar(offset);
				postMessage("Starting oligo search ... (" + offset + " bp)\n\n");
				break;

			case OligoFinderEvent.START_CONTIG:
				// postMessage("Scanning contig " + event.getContig().getID() +
				// " (" + event.getContig().getLength() + " bp)\n\n");
				break;

			case OligoFinderEvent.HASH_MATCH:
				if (showHashMatch)
					postMessage("HASH MATCH: " + event.getOligo().getName()
							+ " to contig " + event.getContig().getID()
							+ " at " + event.getOffset()
							+ (event.isForward() ? "" : " REVERSED") + "\n");
				break;

			case OligoFinderEvent.FOUND_MATCH:
				//postMessage("MATCH: " + event.getOligo().getName()
				//		+ " to contig " + event.getContig().getID() + " at "
				//		+ event.getOffset()
				//		+ (event.isForward() ? "" : " REVERSED") + "\n");
				
				addMatch(event);
				break;

			case OligoFinderEvent.FINISH_CONTIG:
				bpdone += offset;
				incrementProgressBar(bpdone);
				// postMessage("Finished contig " + event.getContig().getName()
				// + "\n\n");
				break;

			case OligoFinderEvent.FINISH:
				setProgressBarToDone();
				postMessage("FINISHED\n");
				reportMatches();
				break;

			default:
				break;
		}
	}
	
	private void addMatch(OligoFinderEvent event) {
		Oligo oligo = event.getOligo();
		
		OligoMatch match = new OligoMatch(oligo, event.getContig(),
				event.getOffset(), event.isForward());
		
		if (!oligomatches.containsKey(oligo))
			oligomatches.put(oligo, new HashSet());
		
		HashSet matchset = (HashSet)oligomatches.get(oligo);
		
		matchset.add(match);
	}
	
	private void reportMatches() {
		Set oligoset = oligomatches.keySet();
		
		Oligo[] oligos = (Oligo[])oligoset.toArray(new Oligo[0]);
		
		Arrays.sort(oligos);
		
		for (int i = 0; i < oligos.length; i++)
			reportMatchesForOligo(oligos[i], (Set)oligomatches.get(oligos[i]));
	}
	
	private void reportMatchesForOligo(Oligo oligo, Set matchset) {
		OligoMatch[] matches = (OligoMatch[])matchset.toArray(new OligoMatch[0]);
		
		Arrays.sort(matches, new OligoMatchComparator());
		
		String ordinal;
		
		switch (matches.length) {
			case 1:
				ordinal = "once";
				break;
				
			case 2:
				ordinal = "twice";
				break;
				
			default:
				ordinal = matches.length + " times";
				break;
		}
		
		postMessage("\n\nOligo " + oligo.getName() + " matches " + ordinal + "\n");
		
		for (int i = 0; i < matches.length; i++) {
			Contig contig = matches[i].getContig();
			
			postMessage("    CONTIG " + contig.getID() + " (" + contig.getName() + ", " +
					contig.getLength() + " bp, in " + contig.getProject().getName() + ")");
			postMessage(" from " + matches[i].getOffset() + " in ");
			postMessage(matches[i].isForward() ? "forward" : "reverse");
			postMessage(" direction.\n");
		}
	}
	
	class OligoMatchComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			OligoMatch m1 = (OligoMatch)o1;
			OligoMatch m2 = (OligoMatch)o2;
			
			int rc = m1.getContig().getID() - m2.getContig().getID();
			
			if (rc != 0)
				return rc;
			
			return m1.getOffset() - m2.getOffset();
		}		
	}

	private void postMessage(final String message) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				txtMessages.append(message);
			}
		});
	}

	private void initProgressBar(final int value) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				pbarTaskProgress.setMinimum(0);
				pbarTaskProgress.setValue(0);
				pbarTaskProgress.setMaximum(value);
			}
		});
	}

	private void incrementProgressBar(final int value) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				pbarTaskProgress.setValue(value);
			}
		});
	}
	
	private void setProgressBarToDone() {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				int value = pbarTaskProgress.getMaximum();
				pbarTaskProgress.setValue(value);
			}
		});
	
	}

	private void updateFindOligosButton() {
		boolean isProjectSelected = !lstProjects.isSelectionEmpty();
		boolean haveOligosInList = txtOligoList.getDocument().getLength() > 0;

		actionFindOligos.setEnabled(isProjectSelected && haveOligosInList);
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
			try {
				refresh();
			} catch (SQLException sqle) {
				Arcturus.logWarning(
						"An error occurred when initialising the project list",
						sqle);
			}
		}

		public void refresh() throws SQLException {
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
		private final Project project;

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

	public void setOligos(String text) {
		txtOligoList.setText(text);
	}

	public static void main(String[] args) {
		try {
			String instance = args.length == 2 ? args[0] : "pathogen";
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			String organism = args.length == 2 ? args[1] : "PKN";
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			JFrame frame = new JFrame("Testing OligoFinderPanel");

			OligoFinderPanel ofp = new OligoFinderPanel(adb);

			frame.getContentPane().add(ofp);

			frame.setJMenuBar(ofp.getMenuBar());

			frame.pack();

			frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

			ofp.setOligos("TAATAAAAATTATTACGACTGTGATAAACTAACATTTAGTCGTATAGTGA");

			frame.setVisible(true);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

	}
}
