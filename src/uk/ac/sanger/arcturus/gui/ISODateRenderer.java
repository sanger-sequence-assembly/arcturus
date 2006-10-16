package uk.ac.sanger.arcturus.gui;

import javax.swing.table.*;
import java.text.*;

public class ISODateRenderer extends DefaultTableCellRenderer {
	/**
	 * 
	 */
	private static final long serialVersionUID = -4674507936665605972L;
	private final DateFormat formatter = new SimpleDateFormat(
			"yyyy MMM dd HH:mm");

	public ISODateRenderer() {
		super();

		setHorizontalAlignment(DefaultTableCellRenderer.CENTER);
	}

	public void setValue(Object value) {
		setText((value == null) ? "" : formatter.format(value));
	}
}
