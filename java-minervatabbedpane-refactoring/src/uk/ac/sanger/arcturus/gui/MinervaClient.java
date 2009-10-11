package uk.ac.sanger.arcturus.gui;

import javax.swing.*;

public interface MinervaClient {
	public JMenuBar getMenuBar();
	public JToolBar getToolBar();
	public void closeResources();
	public void refresh();
}
