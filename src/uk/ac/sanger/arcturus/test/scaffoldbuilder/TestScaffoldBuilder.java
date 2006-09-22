package uk.ac.sanger.arcturus.test.scaffoldbuilder;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.zip.DataFormatException;
import java.util.logging.*;

import javax.swing.*;

import java.awt.Container;
import java.awt.BorderLayout;
import java.awt.Point;
import java.awt.Insets;
import java.awt.FlowLayout;
import java.awt.Dimension;
import java.awt.Color;

import java.awt.event.*;

import javax.naming.Context;

public class TestScaffoldBuilder implements ScaffoldBuilderListener {
    private static Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

    private long lasttime;
    private Runtime runtime = Runtime.getRuntime();
   
    private String instance = null;
    private String organism = null;

    private int flags = ArcturusDatabase.CONTIG_BASIC_DATA | ArcturusDatabase.CONTIG_TAGS;

    private boolean debug = false;
    private boolean lowmem = false;
    private boolean quiet = false;

    private int seedcontigid = -1;
    private int minlen = -1;
    private int puclimit = -1;
    private int minbridges = 2;

    protected ArcturusDatabase adb = null;

    public static void main(String args[]) {
	TestScaffoldBuilder tsb = new TestScaffoldBuilder();
	tsb.execute(args);
    }

    public void execute(String args[]) {
	lasttime = System.currentTimeMillis();

	logger.info("TestScaffoldBuilder");

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-instance"))
		instance = args[++i];

	    if (args[i].equalsIgnoreCase("-organism"))
		organism = args[++i];

	    if (args[i].equalsIgnoreCase("-minlen"))
		minlen = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-puclimit"))
		puclimit = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-minbridges"))
		minbridges = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-contig"))
		seedcontigid = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-debug"))
		debug = true;

	    if (args[i].equalsIgnoreCase("-lowmem"))
		lowmem = true;

	    if (args[i].equalsIgnoreCase("-quiet"))
		quiet = true;
	}

	if (instance == null || organism == null || seedcontigid <= 0) {
	    printUsage(System.err);
	    System.exit(1);
	}

	try {
	    logger.info("Creating an ArcturusInstance for " + instance);

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    logger.info("Creating an ArcturusDatabase for " + organism);

	    adb = ai.findArcturusDatabase(organism);

	    if (lowmem)
		adb.getSequenceManager().setCacheing(false);

	    ScaffoldBuilder sb = new ScaffoldBuilder(adb);

	    if (minlen >= 0)
		sb.setMinimumLength(minlen);

	    if (puclimit >= 0)
		sb.setPucLimit(puclimit);

	    if (minbridges > 0)
		sb.setMinimumBridges(minbridges);

	    Set bs = sb.createScaffold(seedcontigid, this);

	    if (bs != null) {
		logger.info("Bridge Set:" + bs);

		Map layout = createLayout(bs);

		ContigBox[] contigBoxes = (ContigBox[])layout.values().toArray(new ContigBox[0]);

		Arrays.sort(contigBoxes, new ContigBoxComparator());

		logger.info("SCAFFOLD:");

		for (int i = 0; i < contigBoxes.length; i++)
		    logger.info("" + contigBoxes[i]);

		Contig seedcontig = adb.getContigByID(seedcontigid, ArcturusDatabase.CONTIG_BASIC_DATA);

		TestFrame frame = new TestFrame(organism + " contig " + seedcontigid,
						contigBoxes, bs, seedcontig);
		
		frame.setDefaultLookAndFeelDecorated(true);
	    
		frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
	    
		frame.pack();
		frame.setSize(800,800);
		frame.setVisible(true);

	    } else {
		logger.info("Seed contig " + seedcontigid + " cannot be scaffolded. ");
	    }
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    protected Map createLayout(Set bridges) {
	Map layout = new HashMap();
	RowRanges rowranges = new RowRanges();

	Vector bridgevector = new Vector(bridges);

	Collections.sort(bridgevector, new BridgeComparator());

	logger.info("Sorted graph:");
	for (int j = 0; j < bridgevector.size(); j++)
	    logger.info("\t" + bridgevector.elementAt(j));
	
	Bridge bridge = (Bridge)bridgevector.firstElement();
	bridgevector.removeElementAt(0);
	
	Contig contiga = bridge.getContigA();
	Contig contigb = bridge.getContigB();
	int endcode = bridge.getEndCode();
	int gapsize = bridge.getGapSize().getMinimum();
	
	Range rangea = new Range(0, contiga.getLength());
	
	int rowa = rowranges.addRange(rangea, 0);
	
	ContigBox cba = new ContigBox(contiga, rowa, rangea, true);
	layout.put(contiga, cba);
	
	ContigBox cbb = calculateRelativePosition(cba, contiga, contigb, endcode, gapsize, rowranges);
	layout.put(contigb, cbb);
	
	logger.info("# Using " + bridge);
	logger.info("Laid out contig " + contiga.getID() + " at " + cba);
	logger.info("Laid out contig " + contigb.getID() + " at " + cbb);
	
	int ordinal = 1;
	
	while (bridgevector.size() > 0) {
	    bridge = null;
	    
	    boolean hasa = false;
	    boolean hasb = false;
	    
	    for (int i = 0; i < bridgevector.size(); i++) {
		Bridge nextbridge = (Bridge)bridgevector.elementAt(i);
		
		contiga = nextbridge.getContigA();
		contigb = nextbridge.getContigB();
		
		hasa = layout.containsKey(contiga);
		hasb = layout.containsKey(contigb);
		
		if (hasa || hasb) {
		    bridge = nextbridge;
		    bridgevector.removeElementAt(i);
		    break;
		}
	    }
	    
	    if (bridge != null) {
		logger.info("# Using " + bridge);
		if (hasa && hasb) {
		    logger.info("INCONSISTENCY : Both contig " + contiga.getID() + " and contig " +
				       contigb.getID() + " have been laid out already.");
		} else {
		    endcode = bridge.getEndCode();
		    gapsize = bridge.getGapSize().getMinimum();
		    
		    if (hasa) {
			cba = (ContigBox)layout.get(contiga);
			
			cbb = calculateRelativePosition(cba, contiga, contigb, endcode, gapsize, rowranges);
			layout.put(contigb, cbb);
			
			logger.info("Laid out contig " + contigb.getID() + " at " + cbb);
		    } else {
			cbb = (ContigBox)layout.get(contigb);
			
			if (endcode == 0 || endcode == 3)
			    endcode = 3 - endcode;
			
			cba = calculateRelativePosition(cbb, contigb, contiga, endcode, gapsize, rowranges);
			layout.put(contiga, cba);
			
			logger.info("Laid out contig " + contiga.getID() + " at " + cba);
		    }
		}
	    } else {
		logger.info("INCONSISTENCY : Neither contig " + contiga.getID() + " nor contig " +
				   contigb.getID() + " have been laid out yet.");
		break;
	    }
	}
	
	normaliseLayout(layout);
	
	return layout;
    }
 
    private ContigBox calculateRelativePosition(ContigBox cba, Contig contiga, Contig contigb, int endcode,
						int gapsize, RowRanges rowranges) {
	int starta = cba.getRange().getStart();
	boolean forwarda = cba.isForward();
	int lengtha = contiga.getLength();
	int enda = starta + lengtha;
	int rowa = cba.getRow();
	
	boolean forwardb = (endcode == 0 || endcode == 3) ? forwarda : !forwarda;
	
	int startb;
	int endb;
	
	if ((endcode > 1) ^ forwarda) {
	    startb = enda + gapsize;
	    endb = startb + contigb.getLength() - 1;
	} else {
	    endb = starta - gapsize;
	    startb = endb - contigb.getLength() + 1;
	}
	
	Range rangeb = new Range(startb, endb);
	
	int rowb = rowranges.addRange(rangeb, rowa);
	
	return new ContigBox(contigb, rowb, rangeb, forwardb);
    }
    
    private void normaliseLayout(Map layout) {
	int xmin = 0;
	
	for (Iterator iterator = layout.entrySet().iterator(); iterator.hasNext();) {
	    Map.Entry mapentry = (Map.Entry)iterator.next();
	    ContigBox cb = (ContigBox)mapentry.getValue();
	    int left = cb.getRange().getStart();
	    if (left < xmin)
		xmin = left;
	}
	
	if (xmin == 0)
	    return;
	
	xmin = -xmin;
	
	for (Iterator iterator = layout.entrySet().iterator(); iterator.hasNext();) {
	    Map.Entry mapentry = (Map.Entry)iterator.next();
	    ContigBox cb = (ContigBox)mapentry.getValue();
	    cb.getRange().shift(xmin);
	}
    }
    
    class BridgeComparator implements Comparator {
	public int compare(Object o1, Object o2) {
	    Bridge bridgea = (Bridge)o1;
	    Bridge bridgeb = (Bridge)o2;
	    
	    return bridgeb.getLinkCount() - bridgea.getLinkCount();
	}
    }

    class ContigBox {
	protected Contig contig;
	protected int row;
	protected Range range;
	protected boolean forward;

	public ContigBox(Contig contig, int row, Range range, boolean forward) {
	    this.contig = contig;
	    this.row = row;
	    this.range = range;
	    this.forward = forward;
	}

	public Contig getContig() { return contig; }

	public int getRow() { return row; }

	public Range getRange() { return range; }

	public int getLeft() { return range.getStart(); }

	public int getRight() { return range.getEnd(); }

	public int getLength() { return range.getLength(); }

	public boolean isForward() { return forward; }

	public String toString() {
	    return "ContigBox[contig=" + contig.getID() +
		", row=" + row +
		", range=" + range.getStart() + ".." + range.getEnd() +
		", " + (forward ? "forward" : "reverse") + "]";
	}
    }
    
    class ContigBoxComparator implements Comparator {
	public int compare(Object o1, Object o2) {
	    ContigBox box1 = (ContigBox)o1;
	    ContigBox box2 = (ContigBox)o2;
	    
	    int diff = box1.getLeft() - box2.getLeft();

	    if (diff != 0)
		return diff;

	    diff = box1.getRight() - box2.getRight();

	    if (diff != 0)
		return diff;
	    else
		return box1.getRow() - box2.getRow();
	}
    }

    class Range {
	protected int start;
	protected int end;

	public Range(int start, int end) {
	    this.start = (start < end) ? start : end;
	    this.end = (start < end ) ? end : start;
	}

	public int getStart() { return start; }

	public int getEnd() { return end; }

	public int getLength() { return 1 + end - start; }

	public boolean overlaps(Range that) {
	    return !(start > that.end || end < that.start);
	}

	public void shift(int offset) {
	    start += offset;
	    end += offset;
	}
    }

    class RowRanges {
	Vector rangesets = new Vector();

	public int addRange(Range range, int tryrow) {
	    for (int row = tryrow; row < rangesets.size(); row++) {
		Set ranges = (Set)rangesets.elementAt(row);
	
		if (!overlaps(range, ranges)) {
		    ranges.add(range);
		    return row;
		}
	    }

	    for (int row = tryrow - 1; row >= 0; row--) {
		Set ranges = (Set)rangesets.elementAt(row);
	
		if (!overlaps(range, ranges)) {
		    ranges.add(range);
		    return row;
		}
	    }

	    Set ranges = new HashSet();
	    ranges.add(range);

	    rangesets.add(ranges);
	    return rangesets.indexOf(ranges);
	}

	private boolean overlaps(Range range, Set ranges) {
	    for (Iterator iterator = ranges.iterator(); iterator.hasNext();) {
		Range rangeInRow = (Range)iterator.next();
		if (range.overlaps(rangeInRow))
		    return true;
	    }

	    return false;
	}
    }

    class TestFrame extends JFrame {
	protected GenericContigDisplayPanel panel;

	public TestFrame(String title, ContigBox[] contigboxes, Set bridgeset, Contig seedcontig) {
	    super(title);

	    panel = new GenericContigDisplayPanel(seedcontig);

	    JScrollPane scrollpane = new JScrollPane(panel);

	    Container contentPane = getContentPane();

	    contentPane.setLayout(new BorderLayout());

	    JPanel topPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));

	    topPanel.add(new JLabel("Mode: "));

	    JComboBox cb = new JComboBox();

	    cb.addItem(new DisplayMode(DisplayMode.INFO));
	    cb.addItem(new DisplayMode(DisplayMode.DRAG));
	    cb.addItem(new DisplayMode(DisplayMode.ZOOM_IN));
	    cb.addItem(new DisplayMode(DisplayMode.ZOOM_OUT));

	    cb.setSelectedIndex(0);

	    topPanel.add(cb);

	    cb.addActionListener(new ActionListener() {
		    public void actionPerformed(ActionEvent e) {
			JComboBox cb = (JComboBox)e.getSource();
			DisplayMode dm = (DisplayMode)cb.getSelectedItem();
			logger.info("DisplayMode is " + dm.getMode() + " (" +
					   dm.toString() + ")");
			panel.setDisplayMode(dm.getMode());
		    }
		});

	    contentPane.add(topPanel, BorderLayout.NORTH);

	    contentPane.add(scrollpane, BorderLayout.CENTER);

	    panel.setBackground(Color.white);

	    Dimension userarea = calculateUserArea(contigboxes);

	    panel.setInsetsAndUserArea(new Insets(20, 20, 20, 20), userarea);

	    populate(contigboxes, bridgeset);
	}

	protected void populate(ContigBox[] contigboxes, Set bridgeset) {
	    int dragMode = DrawableFeature.DRAG_XY;

	    HashMap contigmap = new HashMap();
	    
	    for (int i = 0; i < contigboxes.length; i++) {
		ContigBox cb = contigboxes[i];

		Contig contig = cb.getContig();

		ContigFeature cf = new ContigFeature(contig,
						     new Point(cb.getLeft(), (1 + cb.getRow()) * 30),
						     cb.isForward());

		contigmap.put(contig, cf);

		panel.addFeature(cf, dragMode);
	    }

	    dragMode = DrawableFeature.DRAG_NONE;

	    for (Iterator iter = bridgeset.iterator(); iter.hasNext();) {
		Bridge bridge = (Bridge)iter.next();

		Contig contiga = bridge.getContigA();
		Contig contigb = bridge.getContigB();

		ContigFeature cfa = (ContigFeature)contigmap.get(contiga);
		ContigFeature cfb = (ContigFeature)contigmap.get(contigb);

		BridgeFeature bf = new BridgeFeature(bridge, cfa, cfb);

		panel.addFeature(bf, dragMode);
	    }
	}

	protected Dimension calculateUserArea(ContigBox[] contigboxes) {
	    int width = 0;
	    int height = 0;

	    for (int i = 0; i < contigboxes.length; i++) {
		int right = contigboxes[i].getRight();

		if (right > width)
		    width = right;

		int row = contigboxes[i].getRow();

		if (row > height)
		    height = row;
	    }

	    height += 1;
	    height *= 30;

	    return new Dimension(width, height);
	}
    }

    public void scaffoldUpdate(ScaffoldEvent event) {
	logger.info("ScaffoldEvent[mode=" + event.getMode() + ", description=" +
			   event.getDescription() + "]");
    }

    protected void printUsage(PrintStream ps) {
	ps.println("MANDATORY PARAMETERS:");
	ps.println("\t-instance\tName of instance");
	ps.println("\t-organism\tName of organism");
	ps.println("\t-contig\t\tContig ID");
	ps.println();
	ps.println("OPTIONAL PARAMETERS");
	ps.println("\t-minlen\t\tMinimum contig length");
	ps.println("\t-puclimit\tAssumed maximum pUC insert size");
	ps.println("\t-minbridges\tMinimum number of pUC bridges for a valid link");
	ps.println();
	ps.println("OPTIONS");
	String[] options = {"-debug", "-lowmem", "-quiet"};
	for (int i = 0; i < options.length; i++)
	    ps.println("\t" + options[i]);
    }
}
