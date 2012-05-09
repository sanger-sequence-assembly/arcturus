package uk.ac.sanger.arcturus.gui;

import javax.swing.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public interface MinervaClient {
	public JMenuBar getMenuBar();
	public JToolBar getToolBar();
	public void closeResources();
	public void refresh() throws ArcturusDatabaseException;
}
