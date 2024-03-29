// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.createcontigtransfers;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectListModel;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectProxy;
import uk.ac.sanger.arcturus.jdbc.ContigTransferRequestManager;
import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestNotifier;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;

import java.awt.*;
import java.awt.event.*;
import java.io.*;

public class CreateContigTransferPanel extends MinervaPanel {
	protected JTextArea txtContigList = new JTextArea(20, 32);
	protected JList lstProjects;
	protected JTextArea txtMessages = new JTextArea(20, 40);
	protected JButton btnTransferContigs;
	protected JButton btnClearMessages = new JButton("Clear messages");

	protected ProjectListModel plm;

	protected MinervaAbstractAction actionTransferContigs;
	protected MinervaAbstractAction actionGetContigsFromFile;

	protected JFileChooser fileChooser = new JFileChooser();

	public CreateContigTransferPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);

		this.adb = adb;

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
				updateTransferContigsButton();
			}

			public void removeUpdate(DocumentEvent e) {
				updateTransferContigsButton();
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

		panel.setBorder(etchedTitledBorder("Contigs to transfer"));

		topPanel.add(panel);

		panel = new JPanel(new BorderLayout());

		try {
			plm = new ProjectListModel(adb);
		} catch (ArcturusDatabaseException e1) {
			Arcturus.logWarning("Failed to create project list model", e1);
		}

		lstProjects = new JList(plm);

		lstProjects.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

		scrollpane = new JScrollPane(lstProjects);

		panel.add(scrollpane, BorderLayout.CENTER);

		btnTransferContigs = new JButton(actionTransferContigs);

		panel.setBorder(etchedTitledBorder("Projects"));

		topPanel.add(panel);

		add(topPanel);

		panel = new JPanel(new FlowLayout());

		panel.add(btnTransferContigs);

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
		actionGetContigsFromFile = new MinervaAbstractAction(
				"Open file of contig names", null, "Open contig of read names",
				new Integer(KeyEvent.VK_O), KeyStroke.getKeyStroke(
						KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				getContigsFromFile();
			}
		};

		actionTransferContigs = new MinervaAbstractAction("Transfer contigs",
				null, "Transfer contigs", new Integer(KeyEvent.VK_I), KeyStroke
						.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				try {
					createContigTransferRequests();
				} catch (ArcturusDatabaseException e1) {
					Arcturus.logWarning("Failed to create contig transfer requests", e1);
				}
			}
		};

		actionTransferContigs.setEnabled(false);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionGetContigsFromFile);

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

	public void refresh() throws ArcturusDatabaseException {
		if (plm != null)
			plm.refresh();
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	public void closeResources() {
	}

	protected void getContigsFromFile() {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			addContigsToList(fileChooser.getSelectedFile());
		}
	}

	protected void addContigsToList(File file) {
		try {
			BufferedReader br = new BufferedReader(new FileReader(file));

			String line;

			while ((line = br.readLine()) != null) {
				txtContigList.append(line);
				txtContigList.append("\n");
			}

			br.close();
		} catch (IOException ioe) {
			Arcturus.logWarning("Error encountered whilst reading file "
					+ file.getPath(), ioe);
		}
	}

	protected void createContigTransferRequests() throws ArcturusDatabaseException {
		ProjectProxy proxy = (ProjectProxy) lstProjects.getSelectedValue();

		Project defaultProject = proxy == null ? null : proxy.getProject();

		String projectName = defaultProject == null ? "(null)" : defaultProject
				.getName();

		String text = txtContigList.getText();

		String[] lines = text.split("[\n\r]");

		for (int i = 0; i < lines.length; i++) {
			String[] words = lines[i].trim().split("[ \t]");

			if (words.length == 0 || words[0].length() == 0)
				continue;

			if (words.length == 2 || (words.length == 1 && projectName != null)) {
				String contigname = words[0];
				String pname = words.length == 2 ? words[1] : projectName;

				Contig contig = null;
				Project project = null;

					if (contigname.matches("^\\d+$")) {
						int contig_id = Integer.parseInt(contigname);
						contig = adb.isCurrentContig(contig_id) ? adb
								.getContigByID(contig_id) : null;
					} else {
						contig = adb.getContigByReadName(contigname);
					}

					project = words.length == 1 ? defaultProject : adb
							.getProjectByName(null, pname);

				if (contig == null) {
					appendMessage(lines[i]
							+ "  : Unable to find contig in current set");
				} else if (project == null) {
					appendMessage(lines[i]
							+ " : Unable to find specified project");
				} else {
					appendMessage("--------------------------------------------------------------------------------");
					appendMessage("Submitting request to transfer contig "
							+ contig.getID() + " to project "
							+ project.getName());

					try {
						ContigTransferRequest request = adb
								.createContigTransferRequest(contig, project);
						
						appendMessage("New contig transfer request:" + ContigTransferRequestManager.prettyPrint(request));
					} catch (ContigTransferRequestException e) {
						appendMessage("Unable to create a contig transfer request: "
								+ e.getTypeAsString());
					}
				}
			} else {
				appendMessage("Invalid request: \"" + lines[i] + "\"");
			}
		}
		
		ContigTransferRequestNotifier.getInstance().processAllQueues();
	}

	protected void updateTransferContigsButton() {
		boolean haveContigsInList = txtContigList.getDocument().getLength() > 0;

		actionTransferContigs.setEnabled(haveContigsInList);
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

	protected void doPrint() {
		// Do nothing.
	}

	protected void appendMessage(String message) {
		txtMessages.append(message);
		txtMessages.append("\n");
	}
}
