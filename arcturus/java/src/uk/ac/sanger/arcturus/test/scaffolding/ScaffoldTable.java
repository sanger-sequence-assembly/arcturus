package scaffolding;

import javax.swing.*;
import javax.swing.table.*;
import javax.swing.event.*;

import java.awt.event.*;

import java.util.Enumeration;

import java.awt.*;

class ScaffoldTable extends JPanel implements ListSelectionListener {
    private JTable table;
    //private JTextArea textarea;
    private ScaffoldPanel panel;
    private ScaffoldTableModel model;

    public ScaffoldTable(Assembly assembly) {
        super(new BorderLayout());

	model = new ScaffoldTableModel(assembly);

        //Create a table.
        table = new JTable(model);

	table.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

	table.getSelectionModel().addListSelectionListener(this);

        //Create the scroll pane and add the table to it. 
        JScrollPane tableView = new JScrollPane(table);

        //Create the HTML viewing pane.
        //textarea = new JTextArea();
        //textarea.setEditable(false);
        //JScrollPane textView = new JScrollPane(textarea);

	panel = new ScaffoldPanel();
	JScrollPane panelView = new JScrollPane(panel);

        //Add the scroll panes to a split pane.
        JSplitPane splitPane = new JSplitPane(JSplitPane.VERTICAL_SPLIT);
        splitPane.setTopComponent(tableView);
        //splitPane.setBottomComponent(textView);
	splitPane.setBottomComponent(panelView);

        Dimension minimumSize = new Dimension(100, 50);
        //textView.setMinimumSize(minimumSize);
	panelView.setMinimumSize(minimumSize);
        tableView.setMinimumSize(minimumSize);
        splitPane.setDividerLocation(100);

        splitPane.setPreferredSize(new Dimension(500, 300));

	JPanel mainpanel = new JPanel(new GridLayout(1,0));
        mainpanel.add(splitPane);

	add(mainpanel, BorderLayout.CENTER);

	JToolBar toolbar = new JToolBar();

	Action zoomInAction = new MyAbstractAction("Zoom In", createImageIcon("general/ZoomIn24"),
					  "Zoom In",
					  new Integer(KeyEvent.VK_I),
					  KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.ALT_MASK)) {
		public void actionPerformed(ActionEvent e) {
		    panel.zoomIn();
		}
	    };
 
	Action zoomOutAction = new MyAbstractAction("Zoom Out", createImageIcon("general/ZoomOut24"),
					  "Zoom Out",
					  new Integer(KeyEvent.VK_O),
					  KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.ALT_MASK)) {
		public void actionPerformed(ActionEvent e) {
		    panel.zoomOut();
		}
	    };

	toolbar.add(zoomInAction);
	toolbar.add(zoomOutAction);

	toolbar.setFloatable(false);

	add(toolbar, BorderLayout.NORTH);
   }

    protected ImageIcon createImageIcon(String imageName) {
	String path = "/toolbarButtonGraphics/"
	    + imageName
	    + ".gif";

        java.net.URL imgURL = getClass().getResource(path);

        if (imgURL != null) {
            return new ImageIcon(imgURL);
        } else {
            System.err.println("Couldn't find file: " + path);
            return null;
        }
    }

    public void valueChanged(ListSelectionEvent e) {
        //Ignore extra messages.
        if (e.getValueIsAdjusting()) return;
	
        ListSelectionModel lsm = (ListSelectionModel)e.getSource();

        if (!lsm.isSelectionEmpty()) {
	    int selectedRow = lsm.getMinSelectionIndex();
            SuperScaffoldInfo ssi = (SuperScaffoldInfo)model.getSuperScaffoldInfo(selectedRow);
	    //textarea.append("Selected: " + ssi + "\n");
	    panel.setSuperScaffold(ssi.getSuperScaffold());
	}
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

	public SuperScaffold getSuperScaffold() { return ss; }

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

	public String toString() {
	    return "SuperScaffoldInfo[SuperScaffold=" + ss.getId() +
		", " + numScaffolds + " scaffolds, " + numContigs + " contigs, " +
		totalLength + " bp]";
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

	public SuperScaffoldInfo getSuperScaffoldInfo(int row) {
	    return info[row];
	}
    }

    abstract class MyAbstractAction extends AbstractAction {
	public MyAbstractAction(String text, ImageIcon icon, String description,
				Integer mnemonic, KeyStroke accelerator) {
	    super(text, icon);
	    
	    if (description != null)
		putValue(SHORT_DESCRIPTION, description);
	    
	    if (mnemonic != null)
		putValue(MNEMONIC_KEY, mnemonic);
	    
	    if (accelerator != null)
		putValue(ACCELERATOR_KEY, accelerator);
	}
    }
}
