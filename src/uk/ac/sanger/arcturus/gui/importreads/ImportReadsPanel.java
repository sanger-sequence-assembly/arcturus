package uk.ac.sanger.arcturus.gui.importreads;

import uk.ac.sanger.arcturus.gui.*;
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

public class ImportReadsPanel extends JPanel implements MinervaClient {
	private ReadToProjectImporter importer;
	private JMenuBar menubar = new JMenuBar();

	private JTextArea txtReadList = new JTextArea(20, 32);
	private JList lstProjects;
	private JTextArea txtMessages = new JTextArea(20, 40);
	private JButton btnImportReads;
	private JButton btnClearMessages = new JButton("Clear messages");
	
	private ProjectListModel plm;
	
	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionImportReads;
	private MinervaAbstractAction actionGetReadsFromFile;
	private MinervaAbstractAction actionHelp;
	private MinervaAbstractAction actionRefresh;
	
	private JFileChooser fileChooser = new JFileChooser();

	ArcturusDatabase adb;

	public ImportReadsPanel(ArcturusDatabase adb) {
		this.adb = adb;
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		try {
			importer = new ReadToProjectImporter(adb);
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error creating an importer", sqle);
		}

		createActions();
		
		createMenus();
		
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
	
		panel.add(btnImportReads, BorderLayout.SOUTH);
		
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
	
	private void createActions() {
		actionClose = new MinervaAbstractAction("Close", null, "Close this window",
				new Integer(KeyEvent.VK_C),
				KeyStroke.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
					public void actionPerformed(ActionEvent e) {
						closePanel();
					}			
		};
		
		actionGetReadsFromFile = new MinervaAbstractAction("Open file of read names",
				null, "Open file of read names", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				getReadsFromFile();
			}
		};

		actionImportReads = new MinervaAbstractAction("Import reads",
				null, "Import reads into project", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				importReadsIntoProject();
			}
		};
		
		actionImportReads.setEnabled(false);
		
		actionRefresh = new MinervaAbstractAction("Refresh",
				null, "Refresh the display", new Integer(KeyEvent.VK_R),
				KeyStroke.getKeyStroke(KeyEvent.VK_F5, 0)) {
			public void actionPerformed(ActionEvent e) {
				refresh();
			}
		};
	
		actionHelp = new MinervaAbstractAction("Help",
				null, "Help", new Integer(KeyEvent.VK_H),
				KeyStroke.getKeyStroke(KeyEvent.VK_F1, 0)) {
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
		
		fileMenu.add(actionGetReadsFromFile);
		
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
		// Does nothing
	}

	private void closePanel() {
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

	private void getReadsFromFile() {
		int rc = fileChooser.showOpenDialog(this);
		
		if (rc == JFileChooser.APPROVE_OPTION) {
			addReadsToList(fileChooser.getSelectedFile());
		}
	}
	
	private void addReadsToList(File file) {
		try {
			BufferedReader br = new BufferedReader(new FileReader(file));
			
			String line;
			
			while ((line = br.readLine()) != null) {
				txtReadList.append(line);
				txtReadList.append("\n");
			}
			
			br.close();
		}
		catch (IOException ioe) {
			Arcturus.logWarning("Error encountered whilst reading file " + file.getPath(), ioe);
		}
	}

	private void importReadsIntoProject() {
		ProjectProxy proxy = (ProjectProxy)lstProjects.getSelectedValue();
		
		Project project = proxy.getProject();
		
		String text = txtReadList.getText();
		String regex = "\\s";
		
		String[] readnames = text.split(regex);
		
		txtMessages.append("There are " + readnames.length + " read names in the list\n");
		txtMessages.append("They will be imported into " + project.getName() + "\n\n");
		
		try {
			int[] rcs = importer.makeSingleReadContigs(readnames, project.getID());
		
			for (int i = 0; i < readnames.length; i++)
				txtMessages.append(readnames[i] + " : " +
						importer.getErrorMessage(rcs[i]) + "\n");
		}
		catch (SQLException sqle) {
			Arcturus.logWarning("An error occurred whilst making single-read contigs", sqle);
		}
	}
	
	private void updateImportReadsButton() {
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
					Project project = (Project)iter.next();
					projects[i] = new ProjectProxy(project);
				}
				
				Arrays.sort(projects);
				fireContentsChanged(this, 0, projects.length);
			}
			catch (SQLException sqle) {
				
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
			ProjectProxy that = (ProjectProxy)o;
			return project.getName().compareToIgnoreCase(that.project.getName());
		}
	}
	
	public static void main(String[] args) {
		try {
			String instance = "test";
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			String organism = "TESTPKN";
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
			
			JFrame frame = new JFrame("Testing ImportReadsPanel");
			
			ImportReadsPanel irp = new ImportReadsPanel(adb);
			
			frame.getContentPane().add(irp);
			
			frame.setJMenuBar(irp.getMenuBar());
			
			frame.pack();
			
			frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
			
			irp.setSelectedProject("PKN13");
			
			frame.setVisible(true);
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
		
	}
}
