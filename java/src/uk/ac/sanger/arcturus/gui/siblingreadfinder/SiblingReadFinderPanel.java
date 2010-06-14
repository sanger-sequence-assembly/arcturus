package uk.ac.sanger.arcturus.gui.siblingreadfinder;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectListModel;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectProxy;
import uk.ac.sanger.arcturus.siblingreadfinder.SiblingReadFinder;
import uk.ac.sanger.arcturus.siblingreadfinder.SiblingReadFinderEvent;
import uk.ac.sanger.arcturus.siblingreadfinder.SiblingReadFinderEventListener;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.util.Comparator;
import java.util.Set;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.regex.Pattern;
import java.awt.*;
import java.awt.event.*;

public class SiblingReadFinderPanel extends MinervaPanel {
	protected JTextArea txtMessages = new JTextArea(20, 100);
	protected JCheckBox cbxOmitShotgunReads = new JCheckBox("Don't list reads with these suffixes:");
	protected JTextField txtSuffixes = new JTextField(20);
	protected JCheckBox cbxSortReadsBySuffix = new JCheckBox("Sort reads by suffix");
	protected JCheckBox cbxBothStrands = new JCheckBox("Show reads from both strands");
	protected JButton btnFindReads;
	protected JButton btnClearMessages = new JButton("Clear messages");
	protected JList lstProjects;
	
	protected MinervaAbstractAction actionFindReads;

	protected ProjectListModel plm;

	protected SiblingReadFinder siblingReadFinder;
	
	protected boolean running = false;
	
	public SiblingReadFinderPanel(MinervaTabbedPane parent, ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(parent, adb);
		
		siblingReadFinder = new SiblingReadFinder(adb);
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		createActions();
		
		createMenus();
		
		getPrintAction().setEnabled(false);
		
		JPanel topPanel = new JPanel();
		
		topPanel.setLayout(new BoxLayout(topPanel, BoxLayout.X_AXIS));

		JPanel panel = new JPanel(new BorderLayout());
		
		plm = new ProjectListModel(adb);

		lstProjects = new JList(plm);

		lstProjects.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

		lstProjects.addListSelectionListener(new ListSelectionListener() {
			public void valueChanged(ListSelectionEvent e) {
				updateFindReadsButton();
			}
		});
		
		JScrollPane scrollpane = new JScrollPane(lstProjects);

		panel.add(scrollpane, BorderLayout.CENTER);

		panel.setBorder(etchedTitledBorder("Projects"));
	
		add(panel);
		
		panel = new JPanel(new FlowLayout());
		
		btnFindReads = new JButton(actionFindReads);
		
		panel.add(btnFindReads);
		
		panel.add(cbxOmitShotgunReads);
		
		panel.add(txtSuffixes);
		
		txtSuffixes.setText("p1k,q1k");
		
		panel.add(cbxSortReadsBySuffix);
		
		panel.add(cbxBothStrands);
			
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
		
		panel.setBorder(etchedTitledBorder("Free sibling reads"));

		add(panel);
	}
	
	protected void createActions() {
		actionFindReads = new MinervaAbstractAction("Find free sibling reads",
				null, "Find reads", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				setEnabled(false);
				findReads();
			}
		};
		
		actionFindReads.setEnabled(false);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
		// Does nothing
	}

	protected void createClassSpecificMenus() {
		// Does nothing
	}

	protected Border etchedTitledBorder(String title) {
		Border etched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		return BorderFactory.createTitledBorder(etched, title);
	}

	public void refresh() throws ArcturusDatabaseException {
		if (plm != null)
			plm.refresh();
	}

	public void closeResources() {
	}

	protected void setRunning(boolean running) {
		this.running = running;
		
		actionFindReads.setEnabled(!running);
	}

	protected void findReads() {
		setRunning(true);
		
		ProjectProxy proxy = (ProjectProxy) lstProjects.getSelectedValue();

		Project project = proxy.getProject();
		
		String[] suffixList = cbxOmitShotgunReads.isSelected() ? getSuffixes() : null;
		
		boolean sortReadsBySuffix = cbxSortReadsBySuffix.isSelected();
		boolean bothStrands = cbxBothStrands.isSelected();

		ReadFinderWorker worker = new ReadFinderWorker(siblingReadFinder, project,
				suffixList, sortReadsBySuffix, bothStrands, this);
		
		worker.execute();
	}
	
	private String[] getSuffixes() {
		String text = txtSuffixes.getText();
		
		if (text == null)
			return null;
		
		text = text.trim();
		
		return (text.length() == 0) ? null : text.split("[,\\s;]+");
	}

	class CompareReadsBySuffix implements Comparator<String> {
		public int compare(String s1, String s2) {
			String[] words1 = s1.split("\\.", 2);
			String[] words2 = s2.split("\\.", 2);
			
			if (words1.length == 2 && words2.length == 2) {
				int rc = words1[1].compareTo(words2[1]);
				
				if (rc != 0)
					return rc;
				else
					return words1[0].compareTo(words2[0]);
			} else
				return s1.compareTo(s2);
		}		
	}
	
	class ReadFinderWorker extends SwingWorker<Void, Void> implements SiblingReadFinderEventListener {
		protected final SiblingReadFinder readFinder;
		protected Project project;
		protected Pattern omitSuffixes;
		protected boolean sortReadsBySuffix;
		protected boolean bothStrands;
		protected SiblingReadFinderPanel parent;
		
		protected SortedSet<String> results;
		
		protected ProgressMonitor monitor;
		
		public ReadFinderWorker(SiblingReadFinder readFinder, Project project, String[] suffixList,
				boolean sortReadsBySuffix, boolean bothStrands, SiblingReadFinderPanel parent) {
			this.readFinder = readFinder;
			this.project = project;
			this.omitSuffixes = createPattern(suffixList);
			this.sortReadsBySuffix = sortReadsBySuffix;
			this.bothStrands = bothStrands;
			this.parent = parent;
			
			readFinder.setListener(this);
		}

		private Pattern createPattern(String[] suffixList) {
			if (suffixList == null || suffixList.length == 0)
				return null;
			
			String pattern = suffixList[0];
			
			for (int i = 1; i < suffixList.length; i++)
				pattern += "|" + suffixList[i];
			
			pattern = "\\.(" + pattern + ")$";

			return Pattern.compile(pattern);
		}

		protected Void doInBackground() throws Exception {
			try {
				Set<String> rawResults = readFinder.getSiblingReadnames(project, omitSuffixes, bothStrands);
				
				if (rawResults == null)
					results = null;
				else
				
				results = sortReadsBySuffix ? new TreeSet<String>(new CompareReadsBySuffix()) : new TreeSet<String>();
				
				results.addAll(rawResults);
			}
			catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("An error occurred whilst finding free reads", e);
			}
			
			return null;
		}
		
		protected void done() {
			txtMessages.append("RESULTS FOR PROJECT " + project.getName() + "\n");
			
			if (results != null && !results.isEmpty()) {
				for (String readname : results) {
					txtMessages.append(readname + "\n");
				}
			} else
				txtMessages.append("--- No free sibling reads could be found ---\n");
				
			txtMessages.append("\n");

			parent.setRunning(false);
		}

		public void siblingReadFinderUpdate(SiblingReadFinderEvent event) {
			switch (event.getStatus()) {
				case STARTED:
					monitor = new ProgressMonitor(parent, "Finding free sibling reads",
							"Counting sub-clones ...", 0, 1000);
					
				case COUNTED_SUBCLONES:
					int value = event.getValue();
					monitor.setMaximum(value);
					monitor.setNote("Examining sub-clones ...");
					break;
					
				case IN_PROGRESS:
					value = event.getValue();
					monitor.setProgress(value);
					break;
					
				case FINISHED:
					monitor.close();
					break;
			}
		}
	}


	protected void updateFindReadsButton() {
		boolean isProjectSelected = !lstProjects.isSelectionEmpty();
		
		actionFindReads.setEnabled(isProjectSelected && !running);
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Does nothing.
	}
}
