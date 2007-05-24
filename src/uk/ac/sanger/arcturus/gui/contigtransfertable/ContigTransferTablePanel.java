package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.Toolkit;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.*;
import javax.swing.border.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigTransferTablePanel extends MinervaPanel {
	private ContigTransferTable tableRequester = null;
	private ContigTransferTableModel modelRequester = null;

	private ContigTransferTable tableContigOwner = null;
	private ContigTransferTableModel modelContigOwner = null;

	private JSplitPane splitpane;

	private ContigTransferTable tableAdmin = null;
	private ContigTransferTableModel modelAdmin = null;

	public ContigTransferTablePanel(ArcturusDatabase adb, Person user,
			MinervaTabbedPane mtp, boolean isAdmin) {
		super(mtp, adb);

		setLayout(new BorderLayout());

		if (isAdmin) {
			modelAdmin = new ContigTransferTableModel(adb, user,
					ArcturusDatabase.USER_IS_ADMINISTRATOR);
			
			tableAdmin = new ContigTransferTable(modelAdmin);		

			JScrollPane scrollpane = new JScrollPane(tableAdmin);

			Border loweredetched1 = BorderFactory
					.createEtchedBorder(EtchedBorder.LOWERED);
			Border title1 = BorderFactory.createTitledBorder(loweredetched1,
					"All requests");
			
			scrollpane.setBorder(title1);

			add(scrollpane, BorderLayout.CENTER);
		} else {
			modelRequester = new ContigTransferTableModel(adb, user,
					ArcturusDatabase.USER_IS_REQUESTER);

			tableRequester = new ContigTransferTable(modelRequester);

			JScrollPane scrollpane1 = new JScrollPane(tableRequester);

			Border loweredetched1 = BorderFactory
					.createEtchedBorder(EtchedBorder.LOWERED);
			Border title1 = BorderFactory.createTitledBorder(loweredetched1,
					"Requests I have made, or to a project I own");
			scrollpane1.setBorder(title1);

			modelContigOwner = new ContigTransferTableModel(adb, user,
					ArcturusDatabase.USER_IS_CONTIG_OWNER);

			tableContigOwner = new ContigTransferTable(modelContigOwner);

			JScrollPane scrollpane2 = new JScrollPane(tableContigOwner);

			Border loweredetched2 = BorderFactory
					.createEtchedBorder(EtchedBorder.LOWERED);
			Border title2 = BorderFactory.createTitledBorder(loweredetched2,
					"Requests for contigs I own");
			scrollpane2.setBorder(title2);

			splitpane = new JSplitPane(JSplitPane.VERTICAL_SPLIT, scrollpane1,
					scrollpane2);

			add(splitpane, BorderLayout.CENTER);

			splitpane.setDividerLocation(0.5);
		}

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);
	}

	protected void createActions() {
	}

	public void closeResources() {
		// Does nothing
	}

	public void refresh() {
		if (tableRequester != null)
			tableRequester.refresh();
		
		if (tableContigOwner != null)
			tableContigOwner.refresh();
		
		if (tableAdmin != null)
			tableAdmin.refresh();
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
		menu.addSeparator();

		ButtonGroup group = new ButtonGroup();

		int[] cutoffs = { 0, 7, 14, 28, 90 };

		JRadioButtonMenuItem rb = null;

		for (int i = 0; i < cutoffs.length; i++) {
			String caption = cutoffs[i] == 0 ? "Show full history"
					: "Show requests made in last " + cutoffs[i] + " days";

			rb = new JRadioButtonMenuItem(caption);
			group.add(rb);
			menu.add(rb);

			final int n = cutoffs[i];

			rb.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					if (modelContigOwner != null)
						modelContigOwner.setDateCutoff(n);
					
					if (modelRequester != null)
						modelRequester.setDateCutoff(n);
					
					if (modelAdmin != null)
						modelAdmin.setDateCutoff(n);
				}
			});

			if (cutoffs[i] == 0)
				rb.doClick();
		}

		int[] status = { ContigTransferRequest.ACTIVE,
				ContigTransferRequest.FAILED, ContigTransferRequest.REFUSED,
				ContigTransferRequest.DONE, ContigTransferRequest.ALL };

		menu.addSeparator();

		group = new ButtonGroup();

		for (int i = 0; i < status.length; i++) {
			String caption = status[i] == ContigTransferRequest.ALL ? "Show all requests"
					: "Show requests which are "
							+ ContigTransferRequest
									.convertStatusToString(status[i]);

			rb = new JRadioButtonMenuItem(caption);
			group.add(rb);
			menu.add(rb);

			final int n = status[i];

			rb.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					if (modelContigOwner != null)
						modelContigOwner.setShowStatus(n);

					if (modelRequester != null)
						modelRequester.setShowStatus(n);

					if (modelAdmin != null)
						modelAdmin.setShowStatus(n);
				}
			});

			if (status[i] == ContigTransferRequest.ACTIVE)
				rb.doClick();
		}
	}

	protected void createClassSpecificMenus() {
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}

	public Dimension getPreferredSize() {
		Dimension screen = Toolkit.getDefaultToolkit().getScreenSize();

		// Some window managers don't take into account toolbars, menu bars etc.
		screen.height -= 200;
		screen.width -= 50;

		Dimension prefsize = super.getPreferredSize();

		if (prefsize.height > screen.height)
			prefsize.height = screen.height;

		if (prefsize.width > screen.width)
			prefsize.width = screen.width;

		return prefsize;
	}

	public void resetDivider() {
		splitpane.setDividerLocation(0.5);
	}
}
