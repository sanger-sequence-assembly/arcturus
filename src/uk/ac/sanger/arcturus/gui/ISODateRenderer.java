package uk.ac.sanger.arcturus.gui;

import javax.swing.table.*;
import java.text.*;

public class ISODateRenderer extends DefaultTableCellRenderer {
    private final DateFormat formatter= new SimpleDateFormat("yyyy-MMM-dd HH:mm:ss");

    public void setValue(Object value) {
        setText((value == null) ? "" : formatter.format(value));
    }
}
