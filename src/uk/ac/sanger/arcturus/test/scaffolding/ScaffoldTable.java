package scaffolding;

import javax.swing.*;
import javax.swing.table.*;
import javax.swing.event.*;

import java.util.Enumeration;

import java.awt.Dimension;
import java.awt.GridLayout;

class ScaffoldTable extends JPanel {
    private JTable table;
     private JEditorPane htmlPane;

    public ScaffoldTable(Assembly assembly) {
        super(new GridLayout(1,0));

	ScaffoldTableModel model = new ScaffoldTableModel(assembly);

        //Create a table.
        table = new JTable(model);

        //Create the scroll pane and add the table to it. 
        JScrollPane tableView = new JScrollPane(table);

        //Create the HTML viewing pane.
        htmlPane = new JEditorPane();
        htmlPane.setEditable(false);
        JScrollPane htmlView = new JScrollPane(htmlPane);

        //Add the scroll panes to a split pane.
        JSplitPane splitPane = new JSplitPane(JSplitPane.VERTICAL_SPLIT);
        splitPane.setTopComponent(tableView);
        splitPane.setBottomComponent(htmlView);

        Dimension minimumSize = new Dimension(100, 50);
        htmlView.setMinimumSize(minimumSize);
        tableView.setMinimumSize(minimumSize);
        splitPane.setDividerLocation(100);

        splitPane.setPreferredSize(new Dimension(500, 300));

        add(splitPane);
    }

    class SuperScaffoldInfo {
	protected SuperScaffold ss = null;
	protected int numScaffolds = 0;
	protected int numContigs = 0;
	protected int totalLength = 0;

	public SuperScaffoldInfo(SuperScaffold ss) {
	    this.ss = ss;

	    calculateStatistics();
	}

	public int getId() { return ss.getId(); }

	public int getNumberOfScaffolds() { return numScaffolds; }

	public int getNumberOfContigs() { return numContigs; }

	public int getTotalLength() { return totalLength; }

	private void calculateStatistics() {
	    for (Enumeration e = ss.elements(); e.hasMoreElements();) {
		Object obj = e.nextElement();

		if (obj instanceof Scaffold) {
		    Scaffold scaffold = (Scaffold)obj;
		    numScaffolds++;
		    processScaffold(scaffold);
		}
	    }
	}

	private void processScaffold(Scaffold scaffold) {
	    for (Enumeration e = scaffold.elements(); e.hasMoreElements();) {
		Object obj = e.nextElement();

		if (obj instanceof Contig) {
		    Contig contig = (Contig)obj;

		    numContigs++;

		    totalLength += contig.getSize();
		}
	    }
	}
    }

    class ScaffoldTableModel extends AbstractTableModel {
	protected SuperScaffoldInfo info[] = null;

	public ScaffoldTableModel(Assembly assembly) {
	    info = new SuperScaffoldInfo[assembly.getChildCount()];

	    Enumeration e = assembly.elements();

	    for (int i = 0; e.hasMoreElements(); i++) {
		SuperScaffold ss = (SuperScaffold)e.nextElement();
		info[i] = new SuperScaffoldInfo(ss);
	    }
	}

	public int getRowCount() {
	    return info.length;
	}

	public int getColumnCount() {
	    return 4;
	}

	public Object getValueAt(int row, int column) {
	    SuperScaffoldInfo ssi = info[row];

	    switch (column) {
	    case 0:
		return new Integer(ssi.getId());

	    case 1:
		return new Integer(ssi.getNumberOfScaffolds());

	    case 2:
		return new Integer(ssi.getNumberOfContigs());

	    case 3:
		return new Integer(ssi.getTotalLength());

	    default:
		return null;
	    }
	}

	public Class getColumnClass(int column) {
	    return Integer.class;
	}

	public String getColumnName(int column) {
	    switch (column) {
	    case 0:
		return "SuperScaffold ID";

	    case 1:
		return "Number of Scaffolds";

	    case 2:
		return "Number of Contigs";

	    case 3:
		return "Total Consensus Length";

	    default:
		return null;
	    }
	}
    }
}
