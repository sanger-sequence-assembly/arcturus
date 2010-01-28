package uk.ac.sanger.arcturus.gui.importreads;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectListModel;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectProxy;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Project;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.sql.SQLException;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import java.io.*;

public class ImportReadsPanel extends MinervaPanel {
	protected ReadToProjectImporter importer;

	protected JTextArea txtReadList = new JTextArea(20, 32);
	protected JList lstProjects;
	protected JTextArea txtMessages = new JTextArea(20, 40);
	protected JButton btnImportReads;
	protected JButton btnClearMessages = new JButton("Clear messages");

	protected ProjectListModel plm;

	protected MinervaAbstractAction actionImportReads;
	protected MinervaAbstractAction actionGetReadsFromFile;

	protected JFileChooser fileChooser = new JFileChooser();

	public ImportReadsPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);

		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		try {
			importer = new ReadToProjectImporter(adb);
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error creating an importer", sqle);
		}

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);

		JPanel topPanel = new JPanel();

		topPanel.setLayout(new BoxLayout(topPanel, BoxLayout.X_AXIS));

		// Set up the text area for the list of reads

		JScrollPane scrollpane = new JScrollPane(txtReadList,
				JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
				JScrollPane.HORIZONTAL_SCROLLBAR_NEVER);

		txtReadList.getDocument().addDocumentListener(new DocumentListener() {
			public void changedUpdate(DocumentEvent e) {
				// Do nothing
			}

			public void insertUpdate(DocumentEvent e) {
				updateImportReadsButton();
			}

			public void removeUpdate(DocumentEvent e) {
				updateImportReadsButton();
			}
		});

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);

		JButton btnClearReads = new JButton("Clear read list");
		panel.add(btnClearReads, BorderLayout.SOUTH);

		btnClearReads.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtReadList.setText("");
			}
		});

		panel.setBorder(etchedTitledBorder("Reads to import"));

		topPanel.add(panel);

		panel = new JPanel(new BorderLayout());

		plm = new ProjectListModel(adb);

		lstProjects = new JList(plm);

		lstProjects.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

		lstProjects.addListSelectionListener(new ListSelectionListener() {
			public void valueChanged(ListSelectionEvent e) {
				updateImportReadsButton();
			}
		});

		scrollpane = new JScrollPane(lstProjects);

		panel.add(scrollpane, BorderLayout.CENTER);

		btnImportReads = new JButton(actionImportReads);

		panel.setBorder(etchedTitledBorder("Projects"));

		topPanel.add(panel);

		add(topPanel);

		panel = new JPanel(new FlowLayout());

		panel.add(btnImportReads);

		add(panel);

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
	}

	protected void createActions() {
		actionGetReadsFromFile = new MinervaAbstractAction(
				"Open file of read names", null, "Open file of read names",
				new Integer(KeyEvent.VK_O), KeyStroke.getKeyStroke(
						KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				getReadsFromFile();
			}
		};

		actionImportReads = new MinervaAbstractAction("Import reads", null,
				"Import reads into project", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				importReadsIntoProject();
			}
		};

		actionImportReads.setEnabled(false);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionGetReadsFromFile);

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

	protected void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	public void closeResources() {
		try {
			importer.close();
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error closing importer", sqle);
		}
	}

	protected void getReadsFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			addReadsToList(fileChooser.getSelectedFile());
		}
	}

	protected void addReadsToList(File file) {
		try {
			BufferedReader br = new BufferedReader(new FileReader(file));

			String line;

			while ((line = br.readLine()) != null) {
				txtReadList.append(line);
				txtReadList.append("\n");
			}

			br.close();
		} catch (IOException ioe) {
			Arcturus.logWarning("Error encountered whilst reading file "
					+ file.getPath(), ioe);
		}
	}

	protected void importReadsIntoProject() {
		ProjectProxy proxy = (ProjectProxy) lstProjects.getSelectedValue();

		Project project = proxy.getProject();

		String text = txtReadList.getText();

		StringTokenizer st = new StringTokenizer(text);

		int wordcount = st.countTokens();

		String[] readnames = new String[wordcount];

		for (int i = 0; i < wordcount; i++)
			readnames[i] = st.nextToken();

		txtMessages.append("There are " + readnames.length
				+ " read names in the list\n");
		txtMessages.append("They will be imported into " + project.getName()
				+ "\n\n");

		try {
			int[] rcs = importer.makeSingleReadContigs(readnames, project
					.getID());

			int ok = 0;

			for (int i = 0; i < rcs.length; i++)
				if (rcs[i] == ReadToProjectImporter.OK)
					ok++;

			for (int i = 0; i < readnames.length; i++)
				txtMessages.append(readnames[i] + " : "
						+ importer.getErrorMessage(rcs[i]) + "\n");

			if (ok > 0) {
				ProjectChangeEvent event = new ProjectChangeEvent(this,
						project, ProjectChangeEvent.CONTIGS_CHANGED);

				adb.notifyProjectChangeEventListeners(event, null);
			}
		} catch (SQLException sqle) {
			Arcturus
					.logWarning(
							"An error occurred whilst making single-read contigs",
							sqle);
		}
	}

	protected void updateImportReadsButton() {
		boolean isProjectSelected = !lstProjects.isSelectionEmpty();
		boolean haveReadsInList = txtReadList.getDocument().getLength() > 0;

		actionImportReads.setEnabled(isProjectSelected && haveReadsInList);
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

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}
}
