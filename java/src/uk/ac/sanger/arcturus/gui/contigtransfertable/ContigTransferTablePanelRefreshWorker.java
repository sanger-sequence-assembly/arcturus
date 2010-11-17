package uk.ac.sanger.arcturus.gui.contigtransfertable;


import javax.swing.SwingWorker;

import uk.ac.sanger.arcturus.Arcturus;

public class ContigTransferTablePanelRefreshWorker extends SwingWorker <Void, Void> {
	private ContigTransferTablePanel panel;
	private String messagePrefix;
	
	public ContigTransferTablePanelRefreshWorker(ContigTransferTablePanel panel) {
		this.panel = panel;
		
		Arcturus.logInfo("Created " + messagePrefix);
	}
	
	protected Void doInBackground() throws Exception {
		Arcturus.logInfo(messagePrefix + " : doInBackground started");

		panel.refreshAllTables();
		
		Arcturus.logInfo(messagePrefix + " : doInBackground ended");
		
		return null;
	}

	protected void done() {
		Arcturus.logInfo(messagePrefix + " : done started");
		panel.setBusyCursor(false);
		Arcturus.logInfo(messagePrefix + " : done ended");
	}

}
