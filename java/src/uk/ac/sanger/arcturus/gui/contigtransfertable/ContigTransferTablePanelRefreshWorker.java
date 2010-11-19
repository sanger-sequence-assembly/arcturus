package uk.ac.sanger.arcturus.gui.contigtransfertable;


import javax.swing.SwingWorker;

import uk.ac.sanger.arcturus.Arcturus;

public class ContigTransferTablePanelRefreshWorker extends SwingWorker <Void, Void> {
	private ContigTransferTablePanel panel;
	private String messagePrefix;
	
	public ContigTransferTablePanelRefreshWorker(ContigTransferTablePanel panel) {
		this.panel = panel;
	}
	
	protected Void doInBackground() throws Exception {
		panel.refreshAllTables();
		
		return null;
	}

	protected void done() {
		panel.setBusyCursor(false);
	}

}
