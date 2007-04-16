package uk.ac.sanger.arcturus.gui.contigtransfertable;

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

	public ContigTransferTablePanel(ArcturusDatabase adb, Person user, MinervaTabbedPane mtp) {
		super(mtp);
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));
		
		modelRequester = new ContigTransferTableModel(adb, user, ArcturusDatabase.USER_IS_REQUESTER);

		tableRequester = new ContigTransferTable(modelRequester);

		JScrollPane scrollpane1 = new JScrollPane(tableRequester);
		
		Border loweredetched1 = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		Border title1 = BorderFactory.createTitledBorder(loweredetched1, "Requests I have made");
		scrollpane1.setBorder(title1);
		
		add(scrollpane1);

		modelContigOwner = new ContigTransferTableModel(adb, user, ArcturusDatabase.USER_IS_CONTIG_OWNER);

		tableContigOwner = new ContigTransferTable(modelContigOwner);

		JScrollPane scrollpane2 = new JScrollPane(tableContigOwner);
		
		Border loweredetched2 = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		Border title2 = BorderFactory.createTitledBorder(loweredetched2, "Requests for contigs I own");
		scrollpane2.setBorder(title2);
		
		add(scrollpane2);
		
		createActions();

		createMenus();
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
}
