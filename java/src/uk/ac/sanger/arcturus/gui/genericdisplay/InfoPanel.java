package uk.ac.sanger.arcturus.gui.genericdisplay;

import javax.swing.JPanel;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;

public abstract class InfoPanel extends JPanel {
	protected PopupManager manager;

	public InfoPanel(PopupManager mymanager) {
		this.manager = mymanager;

		addMouseListener(new MouseAdapter() {
			public void mousePressed(MouseEvent event) {
				manager.hidePopup();
			}

			public void mouseExited(MouseEvent event) {
				manager.hidePopup();
			}
		});
	}

	public abstract void setClientObject(Object o)
			throws InvalidClientObjectException;
}
