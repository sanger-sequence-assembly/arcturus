package uk.ac.sanger.arcturus.gui.contigfinder;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.util.StringTokenizer;
import java.awt.*;
import java.awt.event.*;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Set;
import java.util.HashSet;

public class ContigFinderPanel extends MinervaPanel {
	protected JTextArea txtContigList = new JTextArea(20, 32);
	protected JTextArea txtMessages = new JTextArea(20, 100);
	protected JButton btnFindContigs;
	protected JButton btnClearMessages = new JButton("Clear messages");

	protected MinervaAbstractAction actionFindContigs;

	private final String SEPARATOR = "======================================="
			+ "=======================================\n\n";

	class ContigByID implements Comparator<Contig> {
		public int compare(Contig c1, Contig c2) {
			return c1.getID() - c2.getID();
		}
	}

	private ContigByID comparator = new ContigByID();

	public ContigFinderPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);

		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);

		JPanel topPanel = new JPanel();

		topPanel.setLayout(new BoxLayout(topPanel, BoxLayout.X_AXIS));

		// Set up the text area for the list of reads

		JScrollPane scrollpane = new JScrollPane(txtContigList,
				JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
				JScrollPane.HORIZONTAL_SCROLLBAR_NEVER);

		txtContigList.getDocument().addDocumentListener(new DocumentListener() {
			public void changedUpdate(DocumentEvent e) {
				// Do nothing
			}

			public void insertUpdate(DocumentEvent e) {
				updateFindContigsButton();
			}

			public void removeUpdate(DocumentEvent e) {
				updateFindContigsButton();
			}
		});

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);

		JButton btnClearContigs = new JButton("Clear contig list");
		panel.add(btnClearContigs, BorderLayout.SOUTH);

		btnClearContigs.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				txtContigList.setText("");
			}
		});

		panel.setBorder(etchedTitledBorder("Contigs to search for"));

		topPanel.add(panel);

		add(topPanel);

		panel = new JPanel(new FlowLayout());

		btnFindContigs = new JButton(actionFindContigs);

		panel.add(btnFindContigs);

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
		actionFindContigs = new MinervaAbstractAction("Find contigs", null,
				"Find contigs", new Integer(KeyEvent.VK_I), KeyStroke
						.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent event) {
				setEnabled(false);
				
				try {
					findContigs();
				} catch (ArcturusDatabaseException e) {
					Arcturus.logWarning("Failed to find contigs", e);
				}
			}
		};

		actionFindContigs.setEnabled(false);
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

	private void findContigs() throws ArcturusDatabaseException {
		String text = txtContigList.getText();

		StringTokenizer st = new StringTokenizer(text);

		int wordcount = st.countTokens();

		for (int i = 0; i < wordcount; i++)
			findContig(st.nextToken());
		
		updateFindContigsButton();
	}

	private void findContig(String contigname) throws ArcturusDatabaseException {
		int contig_id = 0;
		
		try {
			contig_id = Integer.parseInt(contigname);
		} catch (NumberFormatException nfe) {
			String message = "That is not a valid contig ID.\nMinerva was expecting a number,\nbut got \"" + contigname + "\"";
			String title = "That is not a valid contig ID";
			JOptionPane.showMessageDialog(this, message, title, JOptionPane.ERROR_MESSAGE);
		} 
		
		Contig parent = adb.getContigByID(contig_id);

		if (parent == null) {
			report("Contig " + contigname + " does not exist\n\n");
		} else {
			Set<Contig> children = getCurrentChildren(parent);

			report(contigInfo(parent));

			if (children == null || children.isEmpty()) {
				report(" is a current contig\n\n");
			} else {
				int nkids = children.size();

				report(" has " + nkids + " current"
						+ (nkids < 2 ? " child" : " children") + ":\n\n");

				Contig[] contigs = children.toArray(new Contig[0]);

				Arrays.sort(contigs, comparator);

				for (Contig contig : contigs) {
					report("\t" + contigInfo(contig) + "\n\n");
				}
			}
		}

		report(SEPARATOR);
	}

	private String contigInfo(Contig contig) {
		return "Contig " + contig.getID() + " ["
				+ contig.getName() + ", "
				+ contig.getLength() + " bp, "
				+ contig.getReadCount() + " reads, created "
				+ contig.getCreated() + ", in project "
				+ contig.getProject().getName() + "]";
	}

	private void report(String text) {
		txtMessages.append(text);
	}

	private Set<Contig> getCurrentChildren(Contig parent) throws ArcturusDatabaseException {
		return getCurrentChildren(parent, 0);
	}

	private Set<Contig> getCurrentChildren(Contig parent, int level)
			throws ArcturusDatabaseException {
		Set<Contig> resultSet = new HashSet<Contig>();

		Set<Contig> children = adb.getChildContigs(parent);

		if (children == null || children.isEmpty()) {
			if (level > 0)
				resultSet.add(parent);
		} else {
			for (Contig child : children)
				resultSet.addAll(getCurrentChildren(child, level + 1));
		}

		return resultSet;
	}

	protected void updateFindContigsButton() {
		boolean haveContigsInList = txtContigList.getDocument().getLength() > 0;

		actionFindContigs.setEnabled(haveContigsInList);
	}

	protected boolean isRefreshable() {
		return false;
	}

	protected void doPrint() {
		// Does nothing.
	}

}
