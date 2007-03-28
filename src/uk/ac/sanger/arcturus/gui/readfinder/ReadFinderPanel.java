package uk.ac.sanger.arcturus.gui.readfinder;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.sql.SQLException;
import java.awt.*;
import java.awt.event.*;
import java.io.*;

public class ReadFinderPanel extends JPanel implements MinervaClient {
	private JMenuBar menubar = new JMenuBar();

	private JTextArea txtReadList = new JTextArea(20, 32);
	private JTextArea txtMessages = new JTextArea(20, 80);
	private JButton btnFindReads;
	private JButton btnClearMessages = new JButton("Clear messages");
	
	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionFindReads;
	private MinervaAbstractAction actionGetReadsFromFile;
	private MinervaAbstractAction actionHelp;
	
	private JFileChooser fileChooser = new JFileChooser();

	private ReadFinder readFinder;
	
	public ReadFinderPanel(ArcturusDatabase adb) {
		try {
			readFinder = new ReadFinder(adb);
		} catch (SQLException sqle) {
			Arcturus.logWarning("Could not create a ReadFinder", sqle);
		}
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

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
				updateFindReadsButton();
			}

			public void removeUpdate(DocumentEvent e) {
				updateFindReadsButton();
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

		panel.setBorder(etchedTitledBorder("Reads to search for"));
		
		topPanel.add(panel);
		
		add(topPanel);
		
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

		actionFindReads = new MinervaAbstractAction("Find reads",
				null, "Find reads", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				findReads();
			}
		};
		
		actionFindReads.setEnabled(false);
	
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


	private void findReads() {
		String text = txtReadList.getText();
		String regex = "\\s";
		
		String[] readnames = text.split(regex);
		
		txtMessages.append("There are " + readnames.length + " read names in the list\n");

		for (int i = 0; i < readnames.length; i++) {
			try {
				txtMessages.append(readnames[i] + ": ");
				
				int rc = readFinder.findRead(readnames[i]);
				
				switch (rc) {
					case ReadFinder.READ_DOES_NOT_EXIST:
						txtMessages.append(" does not exist\n");
						break;
						
					case ReadFinder.READ_IS_FREE:
						txtMessages.append(" is free\n");
						break;
						
					case ReadFinder.READ_IS_IN_CONTIG:
						txtMessages.append(" is in contig " + readFinder.getContigID() +
								" (" + readFinder.getGap4Name() + ", " + readFinder.getReadCount() +
								" reads, " + readFinder.getContigLength() + " bp, updated " +
								readFinder.getContigUpdated() +
								") in project " +
								readFinder.getProjectName() + " at " + readFinder.getContigStart() +
								" to " + readFinder.getContigFinish() + " in " +
								readFinder.getDirection() + " sense\n");
				}
				
				txtMessages.append("\n");
			}
			catch (SQLException sqle) {
				Arcturus.logWarning("An error occurred whilst making single-read contigs", sqle);
			}
		}
	}

	private void updateFindReadsButton() {
		boolean haveReadsInList = txtReadList.getDocument().getLength() > 0;
		
		actionFindReads.setEnabled(haveReadsInList);
	}
		
	public static void main(String[] args) {
		try {
			String instance = "pathogen";
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			String organism = "PKN";
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
			
			JFrame frame = new JFrame("Testing ReadFinderPanel");
			
			ReadFinderPanel rfp = new ReadFinderPanel(adb);
			
			frame.getContentPane().add(rfp);
			
			frame.setJMenuBar(rfp.getMenuBar());
			
			frame.pack();
			
			frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
			
			frame.setVisible(true);
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
		
	}

}
