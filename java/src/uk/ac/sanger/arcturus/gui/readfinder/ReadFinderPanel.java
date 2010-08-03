package uk.ac.sanger.arcturus.gui.readfinder;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.readfinder.*;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.sql.SQLException;
import java.util.StringTokenizer;
import java.awt.*;
import java.awt.event.*;
import java.io.*;

public class ReadFinderPanel extends MinervaPanel implements ReadFinderEventListener {
	protected JTextArea txtReadList = new JTextArea(20, 32);
	protected JTextArea txtMessages = new JTextArea(20, 100);
	protected JButton btnFindReads;
	protected JButton btnClearMessages = new JButton("Clear messages");
	protected JCheckBox cbxOnlyFreeReads = new JCheckBox("Only list free reads");
	protected boolean onlyFreeReads;
	
	protected MinervaAbstractAction actionFindReads;
	protected MinervaAbstractAction actionGetReadsFromFile;
	
	protected JFileChooser fileChooser = new JFileChooser();

	protected ReadFinder readFinder;
	
	public ReadFinderPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);
		
		try {
			readFinder = new ReadFinder(adb);
		} catch (SQLException sqle) {
			Arcturus.logWarning("Could not create a ReadFinder", sqle);
		}
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

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
		
		panel.add(cbxOnlyFreeReads);
		
		cbxOnlyFreeReads.setSelected(false);
		
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
				setEnabled(false);
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
		
		StringTokenizer st = new StringTokenizer(text);
		
		int wordcount = st.countTokens();
		
		String[] readnames = new String[wordcount];
		
		for (int i = 0; i < wordcount; i++)
			readnames[i] = st.nextToken();
		
		onlyFreeReads = cbxOnlyFreeReads.isSelected();
		
		ReadFinderWorker worker = new ReadFinderWorker(readFinder, readnames, onlyFreeReads, this);
		
		worker.execute();
	}
	
	class ReadFinderWorker extends SwingWorker<Void, Void> {
		protected final String[] readnames;
		protected final ReadFinder readFinder;
		protected final boolean onlyFreeReads;
		protected final ReadFinderEventListener listener;
		
		public ReadFinderWorker(ReadFinder readFinder, String[] readnames, boolean onlyFreeReads, 
				ReadFinderEventListener listener) {
			this.readFinder = readFinder;
			this.readnames = readnames;
			this.onlyFreeReads = onlyFreeReads;
			this.listener = listener;
		}

		protected Void doInBackground() throws Exception {
			try {
				for (int i = 0; i < readnames.length; i++) {
					readFinder.findRead(readnames[i], onlyFreeReads, listener);
				}
			}
			catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("An error occurred whilst finding free reads", e);
			}
			
			return null;
		}
		
		protected void done() {
			actionFindReads.setEnabled(true);
		}
	}

	public void readFinderUpdate(final ReadFinderEvent event) {
		final String message;
		
		Read read = event.getRead();
		String readname = (read == null) ? event.getPattern() : read.getUniqueName();
		
		switch (event.getStatus()) {
			case ReadFinderEvent.START:
				message = "----- Searching for \"" + event.getPattern() + "\" -----";
				break;
				
			case ReadFinderEvent.READ_DOES_NOT_EXIST:
				message = readname + " does not exist\n";
				break;
				
			case ReadFinderEvent.READ_IS_FREE:
				message = onlyFreeReads? readname : readname + " is free\n";
				break;
				
			case ReadFinderEvent.READ_IS_IN_CONTIG:
				Contig contig = event.getContig();
				int coffset = event.getContigStart();
				int cfinish = event.getContigFinish();
				message = readname + " is in contig " + contig.getID() +
				" (" + contig.getName() + ", " + contig.getReadCount() +
				" reads, " + contig.getLength() + " bp, updated " +
				contig.getUpdated() +
				") in project " +
				contig.getProject().getName() + " at " + coffset +
				(cfinish > 0 ? " to " + event.getContigFinish() : "") + " in " +
				(event.isForward() ? "forward" : "reverse") + " sense\n";
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
				txtMessages.append(message + "\n");
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

	protected void doPrint() {
		// Does nothing.
	}
}
