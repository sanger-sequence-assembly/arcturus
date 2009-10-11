package uk.ac.sanger.arcturus.gui.contigtransfertable;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.MinervaTabbedPane;

public class AdministratorContigTransferTablePanel extends ContigTransferTablePanel {
	public AdministratorContigTransferTablePanel(MinervaTabbedPane mtp, ArcturusDatabase adb) {
		super(mtp, adb, true);
	}
}
