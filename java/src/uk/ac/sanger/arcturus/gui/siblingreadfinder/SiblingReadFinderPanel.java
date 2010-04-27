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

import java.util.Set;
import java.util.SortedSet;
import java.util.TreeSet;
import java.awt.*;
import java.awt.event.*;

public class SiblingReadFinderPanel extends MinervaPanel {
	protected JTextArea txtMessages = new JTextArea(20, 100);
	protected JButton btnFindReads;
	protected JButton btnClearMessages = new JButton("Clear messages");
	protected JList lstProjects;
	
	protected MinervaAbstractAction actionFindReads;

	protected ProjectListModel plm;

	protected SiblingReadFinder siblingReadFinder;
	
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

	public void refresh() {
		// Does nothing
	}

	public void closeResources() {
	}


	protected void findReads() {		
		ProjectProxy proxy = (ProjectProxy) lstProjects.getSelectedValue();

		Project project = proxy.getProject();
		
		ReadFinderWorker worker = new ReadFinderWorker(siblingReadFinder, project, this);
		
		worker.execute();
	}
	
	class ReadFinderWorker extends SwingWorker<Void, Void> implements SiblingReadFinderEventListener {
		protected final SiblingReadFinder readFinder;
		protected Project project;
		protected SiblingReadFinderPanel parent;
		
		protected SortedSet<String> results;
		
		protected ProgressMonitor monitor;
		
		public ReadFinderWorker(SiblingReadFinder readFinder, Project project, SiblingReadFinderPanel parent) {
			this.readFinder = readFinder;
			this.project = project;
			this.parent = parent;
			
			readFinder.setListener(this);
		}

		protected Void doInBackground() throws Exception {
			try {
				Set<String> rawResults = readFinder.getSiblingReadnames(project);
				
				results = rawResults == null ? null : new TreeSet<String>(rawResults);
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

			actionFindReads.setEnabled(true);
		}

		public void siblingReadFinderUpdate(SiblingReadFinderEvent event) {
			switch (event.getStatus()) {
				case COUNTED_SUBCLONES:
					int value = event.getValue();
					monitor = new ProgressMonitor(parent, "Finding free sibling reads",
							"Examining sub-clones ...", 0, value);
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
		
		actionFindReads.setEnabled(isProjectSelected);
	}

	protected boolean isRefreshable() {
		return false;
	}

	protected void doPrint() {
		// Does nothing.
	}
}
