package uk.ac.sanger.arcturus.gui.consensusreadimporter;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.KeyEvent;
import java.io.File;
import java.util.List;

import javax.swing.*;
import javax.swing.border.Border;
import javax.swing.border.EtchedBorder;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;

import uk.ac.sanger.arcturus.consensusreadimporter.ConsensusReadImporter;
import uk.ac.sanger.arcturus.consensusreadimporter.ConsensusReadImporterListener;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.MinervaAbstractAction;
import uk.ac.sanger.arcturus.gui.MinervaPanel;
import uk.ac.sanger.arcturus.gui.MinervaTabbedPane;

public class ConsensusReadImporterPanel extends MinervaPanel {
	private static final int DEFAULT_QUALITY = 2;
	private static final int MINIMUM_QUALITY = 0;
	private static final int MAXIMUM_QUALITY = 99;
	
	private ConsensusReadImporter importer = new ConsensusReadImporter();
	
	private JButton btnChooseFile;
	private JTextField txtFilename = new JTextField(60); 
	private JSpinner spnQuality = new JSpinner(new SpinnerNumberModel(DEFAULT_QUALITY, MINIMUM_QUALITY, MAXIMUM_QUALITY, 1));
	private JButton btnImportReads;
	private JTextArea txtMessages = new JTextArea(20, 100);
	private JButton btnClearMessages = new JButton("Clear messages");
	
	private final Border LOWERED_ETCHED_BORDER = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);

	protected MinervaAbstractAction actionChooseFile;
	protected MinervaAbstractAction actionImportReads;
	
	protected File fileToImport = null;
	
	private JFileChooser chooser = new JFileChooser();

	public ConsensusReadImporterPanel(MinervaTabbedPane parent,
			ArcturusDatabase adb) {
		super(parent, adb);
		
		createActions();
		
		createMenus();
		
		initialiseFileChooser();
		
		btnChooseFile = new JButton(actionChooseFile);
		btnImportReads = new JButton(actionImportReads);

		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		int vfill = 5;

		add(createChooseFilePanel());

		add(Box.createVerticalStrut(vfill));
		
		add(createSetQualityPanel());
		
		add(Box.createVerticalStrut(vfill));
		
		add(createImportReadsButtonPanel());
		
		add(Box.createVerticalStrut(vfill));
		
		add(createMessagePanel());
		
		getPrintAction().setEnabled(false);
	}
	
	private void initialiseFileChooser() {	
		File userDirectory = new File(System.getProperty("user.dir"));
		
		chooser.setCurrentDirectory(userDirectory);
		
		chooser.setMultiSelectionEnabled(false);
		
		FileFilter filter = new FileNameExtensionFilter("FASTA file", "fas", "fa", "fna", "seq");
		chooser.addChoosableFileFilter(filter);
	}
	
	private JPanel createChooseFilePanel() {
		JPanel panel = new JPanel(new FlowLayout());
		
		panel.add(btnChooseFile);
		
		panel.add(txtFilename);
		
		txtFilename.setEditable(false);
		
		return decoratePanel(panel, "Step 1: Choose the FASTA file");
	}
	
	private JPanel createSetQualityPanel() {
		JPanel panel = new JPanel(new FlowLayout());
		
		panel.add(new JLabel("Set the quality score for the consensus read(s): "));
		
		panel.add(spnQuality);
		
		return decoratePanel(panel, "Step 2: Set the quality value");
	}
	
	private JPanel createImportReadsButtonPanel() {
		JPanel panel = new JPanel(new FlowLayout());
		
		panel.add(btnImportReads);
		
		return decoratePanel(panel, "Step 3: Import the reads");
	}
	
	private JPanel createMessagePanel() {
		JPanel panel = new JPanel(new BorderLayout());
		
		JScrollPane sp = new JScrollPane(txtMessages);
		
		panel.add(sp, BorderLayout.CENTER);
		
		panel.add(btnClearMessages, BorderLayout.SOUTH);
		
		return decoratePanel(panel, "Messages");
	}
	
	private JPanel decoratePanel(JPanel panel, String caption) {
		Border border = BorderFactory.createTitledBorder(LOWERED_ETCHED_BORDER, caption);

		panel.setBorder(border);
		
		return panel;
	}

	protected void createActions() {
		actionChooseFile = new MinervaAbstractAction("Choose FASTA file",
				null, "Choose FASTA file", new Integer(KeyEvent.VK_C),
				KeyStroke.getKeyStroke(KeyEvent.VK_C, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				chooseFile();
			}
		};

		actionImportReads = new MinervaAbstractAction("Import reads",
				null, "Import reads", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				setEnabled(false);
				importReads();
			}
		};
		
		actionImportReads.setEnabled(false);
		
		btnClearMessages.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtMessages.setText("");
			}			
		});
	}
	
	private void chooseFile() {
		int returnVal = chooser.showOpenDialog(null);

		if (returnVal == JFileChooser.APPROVE_OPTION) {
			fileToImport = chooser.getSelectedFile();
		
			if (fileToImport.exists()  && fileToImport.canRead()) {
				txtFilename.setText(fileToImport.getAbsolutePath());
			
				actionImportReads.setEnabled(true);
			} else {
				if (!fileToImport.exists())
					JOptionPane.showMessageDialog(this, "The file " + fileToImport + " does not exist",
						"File does not exist", JOptionPane.ERROR_MESSAGE);
				else
					JOptionPane.showMessageDialog(this, "The file " + fileToImport + " exists\nbut you don't have permission to read it",
							"File cannot be read", JOptionPane.ERROR_MESSAGE);
			}
		}
	}

	private void importReads() {
		Object q = spnQuality.getValue();
		
		int quality =  (q instanceof Integer) ? ((Integer) q).intValue() : DEFAULT_QUALITY;
		
		actionImportReads.setEnabled(false);
		
		Worker worker = new Worker(adb, fileToImport, quality);
		worker.execute();
	}

	class Worker extends SwingWorker<Void, String> implements ConsensusReadImporterListener {
		private ArcturusDatabase adb;
		private File file;
		private int quality;
		
		public Worker(ArcturusDatabase adb, File file, int quality) {
			this.adb = adb;
			this.file = file;
			this.quality = quality;
		}
		
		protected Void doInBackground() throws Exception {
			publish("--------------------------------------------------------------------------------");
			publish("The sequences in " + file.getAbsolutePath() + " will be imported with Q=" + quality);
				
			importer.importReads(this.adb, file, quality, this);
			
			return null;
		}

		protected void done() {			
			actionImportReads.setEnabled(false);
		}

		protected void process(List<String> messages) {
			for (String message : messages) {
				txtMessages.append(message);
				txtMessages.append("\n");
			}
		}

		public void report(String message) {
			publish(message);
		}
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		// No menu items to add
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
		// Does nothing
		
	}

	public void closeResources() {
		// Does nothing
	}

	protected void createClassSpecificMenus() {
		// Does nothing		
	}

	protected void doPrint() {
		// Does nothing
	}

	protected boolean isRefreshable() {
		return false;
	}

	public void refresh() {
		// Does nothing, since the panel is not refreshable
	}
}
