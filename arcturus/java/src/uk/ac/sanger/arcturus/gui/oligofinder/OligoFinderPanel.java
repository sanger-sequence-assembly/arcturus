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
import java.text.*;

public class OligoFinderPanel extends MinervaPanel implements
		OligoFinderEventListener {
	protected OligoFinder finder;

	protected JTextArea txtOligoList = new JTextArea(20, 60);
	protected JList lstProjects;
	protected JTextArea txtMessages = new JTextArea(20, 40);
	protected JButton btnFindOligos;
	protected JButton btnClearMessages = new JButton("Clear messages");
	protected JProgressBar pbarContigProgress = new JProgressBar();
	protected JProgressBar pbarReadProgress = new JProgressBar();
	protected JCheckBox cbSelectAll = new JCheckBox("All projects");
	protected JCheckBox cbFreeReads = new JCheckBox("Scan free reads");

	protected ProjectListModel plm;

	protected MinervaAbstractAction actionFindOligos;
	protected MinervaAbstractAction actionGetOligosFromFile;

	protected boolean searchInProgress = false;

	protected JFileChooser fileChooser = new JFileChooser();

	protected int bpdone;

	protected boolean showHashMatch = false;

	protected HashMap oligomatches = new HashMap();

	protected DecimalFormat df = new DecimalFormat();

	public OligoFinderPanel(ArcturusDatabase adb, MinervaTabbedPane parent) {
		super(parent);

		df.setGroupingSize(3);
		df.setGroupingUsed(true);

		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		finder = new OligoFinder(adb, this);

		createActions();

		createMenus();
		
		getPrintAction().setEnabled(false);

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

		JButton btnClearOligos = new JButton("Clear oligos");
		panel.add(btnClearOligos, BorderLayout.SOUTH);

		btnClearOligos.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtOligoList.setText("");
			}
		});

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
		
		cbSelectAll.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				if (e.getStateChange() == ItemEvent.SELECTED) {
					int start = 0;
					int end = lstProjects.getModel().getSize() - 1;
					if (end >= 0) {
						lstProjects.setSelectionInterval(start, end);
					}				
				} else {
					lstProjects.clearSelection();				
				}
			}
			
		});

		cbFreeReads.setSelected(false);
		panel.add(cbFreeReads);

		cbFreeReads.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				updateFindOligosButton();
			}			
		});

		add(panel);

		panel = new JPanel(new GridBagLayout());
		GridBagConstraints gbc = new GridBagConstraints();

		gbc.gridx = 0;

		panel.add(new JLabel("Contigs: "), gbc);

		gbc.gridx = GridBagConstraints.RELATIVE;
		gbc.gridwidth = GridBagConstraints.REMAINDER;

		panel.add(pbarContigProgress, gbc);

		pbarContigProgress.setStringPainted(true);

		Dimension d = pbarContigProgress.getPreferredSize();
		d.width = 600;
		pbarContigProgress.setPreferredSize(d);

		gbc.gridx = 0;
		gbc.gridwidth = 1;

		panel.add(new JLabel("Reads: "), gbc);

		gbc.gridx = GridBagConstraints.RELATIVE;
		gbc.gridwidth = GridBagConstraints.REMAINDER;

		panel.add(pbarReadProgress, gbc);

		pbarReadProgress.setStringPainted(true);

		pbarReadProgress.setPreferredSize(d);

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

		showHashMatch = Boolean.getBoolean("showHashMatch");
	}

	protected void createActions() {
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
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionGetOligosFromFile);

		return true;
	}

	protected Border etchedTitledBorder(String title) {
		Border etched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		return BorderFactory.createTitledBorder(etched, title);
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	protected void createClassSpecificMenus() {
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

	public void closeResources() {
	}

	protected void getOligosFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			addOligosToList(fileChooser.getSelectedFile());
		}
	}

	protected void addOligosToList(File file) {
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

	protected void findOligoMatches() {
		txtOligoList.setEditable(false);
		searchInProgress = true;
		updateFindOligosButton();

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

		boolean freereads = cbFreeReads.isSelected();

		Task task = new Task(finder, oligos, projects, freereads);

		task.setName("OligoSearch");
		task.start();
	}

	class Task extends Thread {
		protected final OligoFinder finder;
		protected final Oligo[] oligos;
		protected final Project[] projects;
		protected boolean freereads;

		public Task(OligoFinder finder, Oligo[] oligos, Project[] projects,
				boolean freereads) {
			this.finder = finder;
			this.oligos = oligos;
			this.projects = projects;
			this.freereads = freereads;
		}

		public void run() {
			try {
				finder.findMatches(oligos, projects, freereads);
			} catch (SQLException sqle) {
				Arcturus.logWarning("An error occurred whilst finding matches",
						sqle);
			}
		}
	}

	protected Oligo[] parseOligos(String text) {
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
		int value = event.getValue();

		switch (type) {
			case OligoFinderEvent.START_CONTIGS:
				oligomatches.clear();
				bpdone = 0;
				initProgressBar(pbarContigProgress, value);
				postMessage("\nStarting oligo search in " + df.format(value)
						+ " bp of contig consensus sequence\n");
				break;

			case OligoFinderEvent.ENUMERATING_FREE_READS:
				postMessage("Making a list of free reads.  This may take some time.  Please be patient.\n");
				break;

			case OligoFinderEvent.START_READS:
				oligomatches.clear();
				bpdone = 0;
				initProgressBar(pbarReadProgress, value);
				postMessage("\nStarting oligo search in " + df.format(value)
						+ " free reads\n");
				break;

			case OligoFinderEvent.START_SEQUENCE:
				break;

			case OligoFinderEvent.HASH_MATCH:
				if (showHashMatch)
					postMessage("HASH MATCH: " + event.getOligo().getName()
							+ " to contig " + event.getContig().getID()
							+ " at " + event.getValue()
							+ (event.isForward() ? "" : " REVERSED") + "\n");
				break;

			case OligoFinderEvent.FOUND_MATCH:
				addMatch(event);
				break;

			case OligoFinderEvent.FINISH_SEQUENCE:
				if (event.isContig()) {
					bpdone += value;
					incrementProgressBar(pbarContigProgress, bpdone);
				} else if (event.isRead()) {
					bpdone++;
					incrementProgressBar(pbarReadProgress, bpdone);
				}
				break;

			case OligoFinderEvent.FINISH_CONTIGS:
				setProgressBarToDone(pbarContigProgress);
				postMessage("Finished.\n");
				reportMatches();
				break;

			case OligoFinderEvent.FINISH_READS:
				setProgressBarToDone(pbarReadProgress);
				postMessage("Finished.\n");
				reportMatches();
				break;

			case OligoFinderEvent.FINISH:
				SwingUtilities.invokeLater(new Runnable() {
					public void run() {
						actionFindOligos.setEnabled(true);
						pbarContigProgress.setValue(0);
						pbarReadProgress.setValue(0);
						searchInProgress = false;
						updateFindOligosButton();
						txtOligoList.setEditable(true);
					}
				});
				break;

			default:
				break;
		}
	}

	protected void addMatch(OligoFinderEvent event) {
		Oligo oligo = event.getOligo();

		OligoMatch match = new OligoMatch(oligo, event.getDNASequence(), event
				.getValue(), event.isForward());

		if (!oligomatches.containsKey(oligo))
			oligomatches.put(oligo, new HashSet());

		HashSet matchset = (HashSet) oligomatches.get(oligo);

		matchset.add(match);
	}

	protected void reportMatches() {
		Set oligoset = oligomatches.keySet();

		if (oligoset.isEmpty()) {
			postMessage("\nNo oligo matches were found.\n");
		} else {
			Oligo[] oligos = (Oligo[]) oligoset.toArray(new Oligo[0]);

			Arrays.sort(oligos);

			for (int i = 0; i < oligos.length; i++)
				reportMatchesForOligo(oligos[i], (Set) oligomatches
						.get(oligos[i]));
		}
	}

	protected void reportMatchesForOligo(Oligo oligo, Set matchset) {
		OligoMatch[] matches = (OligoMatch[]) matchset
				.toArray(new OligoMatch[0]);

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

		postMessage("\n\nOligo " + oligo.getName() + " matches " + ordinal
				+ "\n");

		for (int i = 0; i < matches.length; i++) {
			Contig contig = matches[i].getContig();

			if (contig != null)
				postMessage("    CONTIG " + contig.getID() + " ("
						+ contig.getName() + ", "
						+ df.format(contig.getLength()) + " bp, in "
						+ contig.getProject().getName() + ")");

			Read read = matches[i].getRead();

			if (read != null)
				postMessage("    READ " + read.getName());

			postMessage(" from " + df.format(matches[i].getOffset() + 1)
					+ " in ");
			postMessage(matches[i].isForward() ? "forward" : "reverse");
			postMessage(" direction.\n");
		}
	}

	class OligoMatchComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			OligoMatch m1 = (OligoMatch) o1;
			OligoMatch m2 = (OligoMatch) o2;

			int rc = m1.getID() - m2.getID();

			if (rc != 0)
				return rc;

			return m1.getOffset() - m2.getOffset();
		}
	}

	protected void postMessage(final String message) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				txtMessages.append(message);
			}
		});
	}

	protected void initProgressBar(final JProgressBar pbar, final int value) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				pbar.setMinimum(0);
				pbar.setValue(0);
				pbar.setMaximum(value);
			}
		});
	}

	protected void incrementProgressBar(final JProgressBar pbar, final int value) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				pbar.setValue(value);
			}
		});
	}

	protected void setProgressBarToDone(final JProgressBar pbar) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				int value = pbar.getMaximum();
				pbar.setValue(value);
			}
		});

	}

	protected void updateFindOligosButton() {
		boolean isProjectSelected = !lstProjects.isSelectionEmpty();
		boolean haveOligosInList = txtOligoList.getDocument().getLength() > 0;
		boolean scanFreeReads = cbFreeReads.isSelected();

		actionFindOligos.setEnabled(!searchInProgress
				&& (isProjectSelected || scanFreeReads) && haveOligosInList);
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

	public void setOligos(String text) {
		txtOligoList.setText(text);
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}
}
