package uk.ac.sanger.arcturus.gui;

import javax.swing.JMenu;
import javax.swing.JPopupMenu;
import javax.swing.event.PopupMenuEvent;
import javax.swing.event.PopupMenuListener;

/**
 * This utility class contains a single method which is designed
 * as a workaround for the following Java bug:
 * 
 * http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=6566185
 *
 */

public class MenuFixer {
	public static void fixPopup(final JMenu menu) {
		final JPopupMenu popupMenu = menu.getPopupMenu();
		
		popupMenu.addPopupMenuListener(new PopupMenuListener() {
			public void popupMenuCanceled(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
				popupMenu.setInvoker(menu);
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
			}			
		});
	}
}
