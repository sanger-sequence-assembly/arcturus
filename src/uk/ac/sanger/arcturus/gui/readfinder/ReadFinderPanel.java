package uk.ac.sanger.arcturus.gui.readfinder;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.readfinder.*;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.sql.SQLException;
import java.awt.*;
import java.awt.event.*;
import java.io.*;

public class ReadFinderPanel extends MinervaPanel implements ReadFinderEventListener {
	protected JTextArea txtReadList = new JTextArea(20, 32);
	protected JTextArea txtMessages = new JTextArea(20, 100);
	protected JButton btnFindReads;
	protected JButton btnClearMessages = new JButton("Clear messages");
	
	protected MinervaAbstractAction actionFindReads;
	protected MinervaAbstractAction actionGetReadsFromFile;
	
	protected JFileChooser fileChooser = new JFileChooser();

	protected ReadFinder readFinder;
	
	public ReadFinderPanel(ArcturusDatabase adb, MinervaTabbedPane parent) {
		super(parent);
		
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
	
	protected void createActions() {
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
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionGetReadsFromFile);
		
		return true;
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
		}
		catch (IOException ioe) {
			Arcturus.logWarning("Error encountered whilst reading file " + file.getPath(), ioe);
		}
	}


	protected void findReads() {
		String text = txtReadList.getText();
		String regex = "\\s";
		
		String[] readnames = text.split(regex);
		
		for (int i = 0; i < readnames.length; i++)
			readnames[i] = readnames[i].trim();
		
		Task task = new Task(readFinder, readnames, this);
		
		task.start();
	}
	
	class Task extends Thread {
		protected final String[] readnames;
		protected final ReadFinder readFinder;
		protected final ReadFinderEventListener listener;
		
		public Task(ReadFinder readFinder, String[] readnames, ReadFinderEventListener listener) {
			this.readFinder = readFinder;
			this.readnames = readnames;
			this.listener = listener;
		}
		
		public void run() {
			for (int i = 0; i < readnames.length; i++) {
				try {
					readFinder.findRead(readnames[i], listener);
				}
				catch (SQLException sqle) {
					Arcturus.logWarning("An error occurred whilst searching for " + readnames[i], sqle);
				}
			}			
		}	
	}

	public void readFinderUpdate(final ReadFinderEvent event) {
		final String message;
		
		Read read = event.getRead();
		String readname = (read == null) ? null : read.getName();
		
		switch (event.getStatus()) {
			case ReadFinderEvent.START:
				message = "----- Searching for \"" + event.getPattern() + "\" -----";
				break;
				
			case ReadFinderEvent.READ_DOES_NOT_EXIST:
				message = readname + " does not exist";
				break;
				
			case ReadFinderEvent.READ_IS_FREE:
				message = readname + " is free";
				break;
				
			case ReadFinderEvent.READ_IS_IN_CONTIG:
				Contig contig = event.getContig();
				message = readname + " is in contig " + contig.getID() +
				" (" + contig.getName() + ", " + contig.getReadCount() +
				" reads, " + contig.getLength() + " bp, updated " +
				contig.getUpdated() +
				") in project " +
				contig.getProject().getName() + " at " + event.getContigStart() +
				" to " + event.getContigFinish() + " in " +
				(event.isForward() ? "forward" : "reverse") + " sense";
				break;
				
			case ReadFinderEvent.FINISH:
				message = "";
				break;
				
			default:
				message = "has unknown status (" + event.getStatus() + ")";
				break;
		}
		
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				txtMessages.append(message + "\n\n");
			}
		});
	}


	protected void updateFindReadsButton() {
		boolean haveReadsInList = txtReadList.getDocument().getLength() > 0;
		
		actionFindReads.setEnabled(haveReadsInList);
	}

	protected boolean isRefreshable() {
		return false;
	}
}
