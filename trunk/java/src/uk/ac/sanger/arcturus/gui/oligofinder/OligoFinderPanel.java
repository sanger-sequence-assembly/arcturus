package uk.ac.sanger.arcturus.gui.oligofinder;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectListModel;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectProxy;
import uk.ac.sanger.arcturus.oligo.*;
import uk.ac.sanger.arcturus.oligo.OligoFinderEvent.Type;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.event.*;

import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.Vector;
import java.io.*;
import java.text.*;

public class OligoFinderPanel extends MinervaPanel implements
		OligoFinderEventListener, ProjectChangeEventListener {
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
	protected JCheckBox cbTerseList = new JCheckBox("I want a list of reads that I can cut and paste");
	
	private boolean terse;

	protected ProjectListModel plm;

	protected MinervaAbstractAction actionFindOligos;
	protected MinervaAbstractAction actionGetOligosFromFile;
	protected MinervaAbstractAction actionGetConsensusFromFile;

	protected boolean searchInProgress = false;

	protected JFileChooser fileChooser = new JFileChooser();

	protected int bpdone;

	protected boolean showHashMatch = false;

	protected HashMap<Oligo, HashSet<OligoMatch>> oligomatches = 
		new HashMap<Oligo, HashSet<OligoMatch>>();

	protected DecimalFormat df = new DecimalFormat();

	public OligoFinderPanel(MinervaTabbedPane parent, ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(parent, adb);

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
				JScrollPane.HORIZONTAL_SCROLLBAR_AS_NEEDED);

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
		
		plm.addListDataListener(new ListDataListener() {
			public void contentsChanged(ListDataEvent e) {
				refreshList();
			}

			public void intervalAdded(ListDataEvent e) {
				refreshList();
			}

			public void intervalRemoved(ListDataEvent e) {
				refreshList();
			}		
		});

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
				boolean allSelected = e.getStateChange() == ItemEvent.SELECTED;
				
				setAllProjectsSelected(allSelected);
			}

		});

		cbFreeReads.setSelected(false);
		panel.add(cbFreeReads);

		cbFreeReads.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				updateFindOligosButton();
			}
		});
		
		panel.add(cbTerseList);

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
		
		adb.addProjectChangeEventListener(this);
	}
	
	protected void refreshList() {
		boolean allSelected = cbSelectAll.isSelected();
		
		setAllProjectsSelected(allSelected);
	}
	
	protected void setAllProjectsSelected(boolean allSelected) {
		if (allSelected) {
			int start = 0;
			int end = lstProjects.getModel().getSize() - 1;
			
			if (end >= 0) {
				lstProjects.setSelectionInterval(start, end);
				lstProjects.setEnabled(false);
			}
		} else {
			lstProjects.clearSelection();
			lstProjects.setEnabled(true);
		}

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

		actionGetConsensusFromFile = new MinervaAbstractAction(
				"Import a consensus file", null, "Import a consensus file",
				new Integer(KeyEvent.VK_C), KeyStroke.getKeyStroke(
						KeyEvent.VK_C, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				getConsensusFromFile();
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
		menu.add(actionGetConsensusFromFile);

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

	public void refresh() throws ArcturusDatabaseException {
		if (plm != null)
			plm.refresh();
	}

	public void closeResources() {
	}

	protected void getOligosFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			File file = fileChooser.getSelectedFile();
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
	}

	protected void getConsensusFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			File file = fileChooser.getSelectedFile();
			try {
				BufferedReader br = new BufferedReader(new FileReader(file));

				String line;

				while ((line = br.readLine()) != null) {
					txtOligoList.append(line);
				}

				txtOligoList.append("\n");

				br.close();
			} catch (IOException ioe) {
				Arcturus.logWarning("Error encountered whilst reading file "
						+ file.getPath(), ioe);
			}
		}
	}

	protected void findOligoMatches() {
		txtOligoList.setEditable(false);
		searchInProgress = true;
		updateFindOligosButton();
		
		terse = cbTerseList.isSelected();

		Object[] selected = lstProjects.getSelectedValues();

		int[] projects = new int[selected.length];

		for (int i = 0; i < selected.length; i++) {
			ProjectProxy proxy = (ProjectProxy) selected[i];
			projects[i] = proxy.getProject().getID();
		}

		Oligo[] oligos = parseOligos(txtOligoList.getText());
		
		if (oligos == null || oligos.length == 0)
			return;

		txtMessages.append("Searching for oligos:\n\n");

		for (int i = 0; i < oligos.length; i++)
			if (oligos[i] != null)
				txtMessages.append(oligos[i].getName() + " : "
						+ oligos[i].getSequence() + "\n");

		txtMessages.append("\n\n");

		boolean freereads = cbFreeReads.isSelected();
		
		OligoFinderWorker worker = new OligoFinderWorker(this, finder, oligos, projects, freereads);
		
		worker.execute();
	}
	
	class OligoFinderWorker extends SwingWorker<Void, OligoFinderEvent> {
		protected final OligoFinder finder;
		protected final Oligo[] oligos;
		protected final int[] projects;
		protected boolean freereads;
		protected OligoFinderPanel parent;
		protected ArcturusDatabaseException pendingException = null;

		public OligoFinderWorker(OligoFinderPanel parent, OligoFinder finder, Oligo[] oligos, int[] projects,
				boolean freereads) {
			this.parent = parent;
			this.finder = finder;
			this.oligos = oligos;
			this.projects = projects;
			this.freereads = freereads;		
		}
		
		protected Void doInBackground() throws Exception {
			try {
				finder.findMatches(oligos, projects, freereads);
			}
			catch (ArcturusDatabaseException e) {
				pendingException = e;
				return null;
			}
			
			return null;
		}
		
		protected void process(List<OligoFinderEvent> events) {
			for (OligoFinderEvent event : events)
				parent.oligoFinderUpdate(event);
		}
		
		protected void done() {
			if (pendingException != null) {
				OligoFinderEvent event = new OligoFinderEvent(finder);
				event.setException(pendingException);
				parent.oligoFinderUpdate(event);
			}
		
			parent.setSearchInProgress(false);
			parent.updateFindOligosButton();
		}
	}

	protected Oligo[] parseOligos(String text) {
		String[] lines = text.split("[\n\r]+");

		List<Oligo> oligoList = new Vector<Oligo>();

		int anon = 0;

		for (int i = 0; i < lines.length; i++) {
			String[] words = lines[i].trim().split("\\s");

			String name;
			String sequence;

			if (words.length < 1 || words[0].length() == 0)
				continue;

			if (words.length == 1) {
				name = "ANON." + (++anon);
				sequence = words[0];
			} else {
				name = words[0];
				sequence = words[1];
			}

			oligoList.add(new Oligo(name, sequence));
		}

		Oligo[] oligos = oligoList.toArray(new Oligo[0]);

		return oligos;
	}

	public void oligoFinderUpdate(OligoFinderEvent event) {
		Type type = event.getType();
		int value = event.getValue();
		
		Date now = new Date();

		switch (type) {
			case START_CONTIGS:
				oligomatches.clear();
				bpdone = 0;
				initProgressBar(pbarContigProgress, value);
				postMessage("\nTIMESTAMP: " + now + "\n");
				postMessage("\nStarting oligo search in " + df.format(value)
						+ " bp of contig consensus sequence\n");
				break;

			case ENUMERATING_FREE_READS:
				postMessage("\nTIMESTAMP: " + now + "\n");
				postMessage("\nMaking a list of free reads.  This may take some time.  Please be patient.\n");
				break;

			case START_READS:
				oligomatches.clear();
				bpdone = 0;
				postMessage("\nTIMESTAMP: " + now + "\n");
				initProgressBar(pbarReadProgress, value);
				postMessage("\nStarting oligo search in " + df.format(value)
						+ " free reads\n");
				break;

			case START_SEQUENCE:
				break;

			case FOUND_MATCH:
				addMatch(event);
				break;

			case FINISH_SEQUENCE:
				if (event.getDNASequence().isContig()) {
					bpdone += value;
					incrementProgressBar(pbarContigProgress, bpdone);
				} else if (event.getDNASequence().isRead()) {
					bpdone++;
					incrementProgressBar(pbarReadProgress, bpdone);
				}
				break;

			case FINISH_CONTIGS:
				setProgressBarToDone(pbarContigProgress);
				postMessage("Finished.\n");
				reportMatches(false);
				break;

			case FINISH_READS:
				setProgressBarToDone(pbarReadProgress);
				postMessage("Finished.\n");
				reportMatches(terse);
				break;

			case FINISH:
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

			case MESSAGE:
				postMessage("\n{MESSAGE [" + now + "] : " + event.getMessage() + "}\n");
				break;
				
			case EXCEPTION:
				postMessage("***** WARNING [" + now + "] : " + event.getMessage() + " *****");
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
			oligomatches.put(oligo, new HashSet<OligoMatch>());

		HashSet<OligoMatch> matchset = (HashSet<OligoMatch>) oligomatches.get(oligo);

		matchset.add(match);
	}

	protected void reportMatches(boolean terseReport) {
		Set<Oligo> oligoset = oligomatches.keySet();

		if (oligoset.isEmpty()) {
			postMessage("\nNo oligo matches were found.\n");
		} else {
			Oligo[] oligos = (Oligo[]) oligoset.toArray(new Oligo[0]);

			Arrays.sort(oligos);

			for (int i = 0; i < oligos.length; i++)
				reportMatchesForOligo(oligos[i], (Set<OligoMatch>) oligomatches
						.get(oligos[i]), terseReport);
		}
	}

	protected void reportMatchesForOligo(Oligo oligo, Set<OligoMatch> matchset, boolean terse) {
		if (terse)
			terseReportMatchesForOligo(oligo, matchset);
		else
			verboseReportMatchesForOligo(oligo, matchset);
	}
	
	private void terseReportMatchesForOligo(Oligo oligo, Set<OligoMatch> matchset) {
		SortedSet<String> sequenceNames = new TreeSet<String>();
		
		for (OligoMatch match : matchset) {
			String seqname = match.getDNASequence().getName();
			sequenceNames.add(seqname);
		}
		
		int matches = sequenceNames.size();
		
		postMessage("\n\nOligo " + oligo.getName() + " matches " + matches
				+ " sequences\n\n");

		for (String seqname : sequenceNames) {
			postMessage(seqname + "\n");
		}
	}

	private void verboseReportMatchesForOligo(Oligo oligo, Set<OligoMatch> matchset) {
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
			postMessage(matches[i].getDNASequence().toString());

			postMessage(" from " + df.format(matches[i].getOffset() + 1)
					+ " in ");
			postMessage(matches[i].isForward() ? "forward" : "reverse");
			postMessage(" direction.\n");
		}
	}

	class OligoMatchComparator implements Comparator<OligoMatch> {
		public int compare(OligoMatch m1, OligoMatch m2) {
			int rc = m1.getDNASequence().getID() - m2.getDNASequence().getID();

			if (rc != 0)
				return rc;

			return m1.getOffset() - m2.getOffset();
		}
	}

	protected void postMessage(final String message) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				txtMessages.append(message);
				txtMessages.setCaretPosition(txtMessages.getText().length());
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
	
	protected void setSearchInProgress(boolean inProgress) {
		searchInProgress = inProgress;
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

	public void setOligos(String text) {
		txtOligoList.setText(text);
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}

	public void projectChanged(ProjectChangeEvent event) {
		if (event.getType() == ProjectChangeEvent.CREATED)
			try {
				refresh();
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to refresh in response to a project change event", e);
			}
	}
}
