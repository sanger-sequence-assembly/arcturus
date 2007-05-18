package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.awt.BorderLayout;
import java.awt.Dimension;

import javax.swing.*;
import javax.swing.border.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigTransferTablePanel extends MinervaPanel {
	private ContigTransferTable tableRequester = null;
	private ContigTransferTableModel modelRequester = null;

	private ContigTransferTable tableContigOwner = null;
	private ContigTransferTableModel modelContigOwner = null;
	private JSplitPane splitpane;
	
	public ContigTransferTablePanel(ArcturusDatabase adb, Person user, MinervaTabbedPane mtp) {
		super(mtp);
		
		setLayout(new BorderLayout());
		
		modelRequester = new ContigTransferTableModel(adb, user, ArcturusDatabase.USER_IS_REQUESTER);

		tableRequester = new ContigTransferTable(modelRequester);

		JScrollPane scrollpane1 = new JScrollPane(tableRequester);
		
		Border loweredetched1 = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		Border title1 = BorderFactory.createTitledBorder(loweredetched1, "Requests I have made");
		scrollpane1.setBorder(title1);

		modelContigOwner = new ContigTransferTableModel(adb, user, ArcturusDatabase.USER_IS_CONTIG_OWNER);

		tableContigOwner = new ContigTransferTable(modelContigOwner);

		JScrollPane scrollpane2 = new JScrollPane(tableContigOwner);
		
		Border loweredetched2 = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		Border title2 = BorderFactory.createTitledBorder(loweredetched2, "Requests for contigs I own");
		scrollpane2.setBorder(title2);
		
		splitpane = new JSplitPane(JSplitPane.VERTICAL_SPLIT, scrollpane1, scrollpane2);
		
		add(splitpane, BorderLayout.CENTER);
		
		splitpane.setDividerLocation(0.5);
		
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
		tableRequester.refresh();
		tableContigOwner.refresh();
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
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
		Dimension prefsize = super.getPreferredSize();
		
		if (prefsize.height > 800)
			prefsize.height = 800;
		
		return prefsize;
	}
	
	public void resetDivider() {
		splitpane.setDividerLocation(0.5);
	}
}
