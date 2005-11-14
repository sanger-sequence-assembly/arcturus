import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.scaffold.*;

import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.zip.DataFormatException;

import javax.naming.Context;

public class DynamicScaffolding2 {
    private long lasttime;
    private Runtime runtime = Runtime.getRuntime();
   
    private String instance = null;
    private String organism = null;

    private int flags = ArcturusDatabase.CONTIG_BASIC_DATA;

    private boolean debug = false;
    private boolean lowmem = false;
    private boolean quiet = false;

    private int seedcontigid = 0;
    private int minlen = 0;
    private int puclimit = 8000;
    private int minbridges = 2;

    protected ArcturusDatabase adb = null;
    protected Connection conn = null;
    protected PreparedStatement pstmtContigData;
    protected PreparedStatement pstmtLeftEndReads;
    protected PreparedStatement pstmtRightEndReads;
    protected PreparedStatement pstmtTemplate;
    protected PreparedStatement pstmtLigation;
    protected PreparedStatement pstmtLinkReads;
    protected PreparedStatement pstmtMappings;

    public static void main(String args[]) {
	DynamicScaffolding2 ds = new DynamicScaffolding2();
	ds.execute(args);
    }

    public void execute(String args[]) {
	lasttime = System.currentTimeMillis();

	System.err.println("DynamicScaffolding");
	System.err.println("==================");
	System.err.println();

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

	if (instance == null || organism == null | seedcontigid == 0) {
	    printUsage(System.err);
	    System.exit(1);
	}

	try {
	    System.err.println("Creating an ArcturusInstance for " + instance);
	    System.err.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.err.println("Creating an ArcturusDatabase for " + organism);
	    System.err.println();

	    adb = ai.findArcturusDatabase(organism);

	    if (lowmem)
		adb.getSequenceManager().setCacheing(false);

	    conn = adb.getConnection();

	    if (conn == null) {
		System.err.println("Connection is undefined");
		printUsage(System.err);
		System.exit(1);
	    }

	    long peakMemory = 0;

	    prepareStatements(conn);

	    createScaffold();
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    private void prepareStatements(Connection conn) throws SQLException {
	String query;

	query = "select length,gap4name,project_id" +
	    "  from CONTIG  left join C2CMAPPING" +
	    "    on CONTIG.contig_id = C2CMAPPING.parent_id" +
	    " where CONTIG.contig_id = ? and C2CMAPPING.parent_id is null";

	pstmtContigData = conn.prepareStatement(query);

	query = "select read_id,MAPPING.seq_id,cstart,cfinish,direction from" +
	    " MAPPING left join SEQ2READ using(seq_id) where contig_id = ?" +
	    " and cfinish < ? and direction = 'Reverse'";

	pstmtLeftEndReads = conn.prepareStatement(query);

	query = "select read_id,MAPPING.seq_id,cstart,cfinish,direction from" +
	    " MAPPING left join SEQ2READ using(seq_id) where contig_id = ?" +
	    " and cstart > ? and direction = 'Forward'";

	pstmtRightEndReads = conn.prepareStatement(query);

	query = "select template_id,strand from READS where read_id = ?";

	pstmtTemplate = conn.prepareStatement(query);

	query =  "select silow,sihigh from TEMPLATE left join LIGATION using(ligation_id)" +
	    " where template_id = ?";

	pstmtLigation = conn.prepareStatement(query);

	query = "select READS.read_id,seq_id from READS left join SEQ2READ using(read_id)" +
	    " where template_id = ? and strand != ?";

	pstmtLinkReads = conn.prepareStatement(query);

	query = "select contig_id,cstart,cfinish,direction from MAPPING where seq_id = ?";

	pstmtMappings = conn.prepareStatement(query);
    }

    protected boolean isCurrentContig(int contigid) throws SQLException {
	pstmtContigData.setInt(1, contigid);

	ResultSet rs = pstmtContigData.executeQuery();

	boolean found = rs.next();

	rs.close();

	return found;
    }

    protected void createScaffold() throws SQLException, DataFormatException {
	Vector contigset = new Vector();

	Contig seedcontig = adb.getContigByID(seedcontigid, ArcturusDatabase.CONTIG_BASIC_DATA);

	if (seedcontig == null || !isCurrentContig(seedcontigid))
	    return;

	contigset.add(seedcontig);

	BridgeSet bs = processContigSet(contigset);

	bs.dump(System.out, minbridges);

	Set subgraph = bs.getSubgraph(seedcontig, minbridges);

	System.err.println();
	System.err.println("SUBGRAPH");
	for (Iterator iterator = subgraph.iterator(); iterator.hasNext();)
	    System.err.println((Bridge)iterator.next());
	
	Map layout = createLayout(subgraph);

	ContigBox boxes[] = (ContigBox[])layout.values().toArray(new ContigBox[0]);

	Arrays.sort(boxes, new ContigBoxComparator());

	System.out.println("\n\n----- LAYOUT -----\n");
	for (int i = 0; i < boxes.length; i++) {
	    ContigBox cb = boxes[i];

	    Contig contig = cb.getContig();
	    int left = cb.getRange().getStart();
	    int right = cb.getRange().getEnd();

	    System.out.println("Contig " + contig.getID() + " : row " + cb.getRow() + " from " +
			       left + " to " + right + " in " + (cb.isForward() ? "forward" : "reverse") + " sense");
	}
    }

    protected BridgeSet processContigSet(Vector contigset) throws SQLException, DataFormatException {
	BridgeSet bridgeset = new BridgeSet();

	Set processed = new HashSet();

	while (!contigset.isEmpty()) {
	    Contig contig = (Contig)contigset.elementAt(0);
	    contigset.removeElementAt(0);

	    if (processed.contains(contig))
		continue;

	    processed.add(contig);

	    if (contig.getLength() < minlen)
		continue;

	    if (!isCurrentContig(contig.getID()))
		continue;

	    System.err.println("Processing contig " + contig.getID());

	    int contiglength = contig.getLength();

	    Set linkedContigs = new HashSet();

	    for (int iEnd = 0; iEnd < 2; iEnd++) {
		int endcode = 2 * iEnd;

		PreparedStatement pstmt = (iEnd == 0) ? pstmtRightEndReads : pstmtLeftEndReads;

		int limit = (iEnd == 0) ? contig.getLength() - puclimit : puclimit;

		pstmt.setInt(1, contig.getID());
		pstmt.setInt(2, limit);

		ResultSet rs = pstmt.executeQuery();

		while (rs.next()) {
		    int readid = rs.getInt(1);
		    int seqid = rs.getInt(2);
		    int cstart = rs.getInt(3);
		    int cfinish = rs.getInt(4);
		    String direction = rs.getString(5);

		    ReadMapping mappinga = new ReadMapping(readid, cstart, cfinish, direction.equalsIgnoreCase("Forward"));

		    pstmtTemplate.setInt(1, readid);

		    ResultSet rs2 = pstmtTemplate.executeQuery();

		    int templateid = 0;
		    String strand = null;

		    if (rs2.next()) {
			templateid = rs2.getInt(1);
			strand = rs2.getString(2);
		    }

		    rs2.close();

		    Template template = adb.getTemplateByID(templateid);

		    int sihigh = 0;

		    pstmtLigation.setInt(1, templateid);

		    rs2 = pstmtLigation.executeQuery();

		    if (rs2.next())
			sihigh = rs2.getInt(2);

		    rs2.close();

		    int overhang = (iEnd == 0) ? cstart + sihigh - contiglength : sihigh - cfinish;

		    if (overhang < 1 || sihigh > puclimit)
			continue;

		    pstmtLinkReads.setInt(1, templateid);
		    pstmtLinkReads.setString(2, strand);

		    rs2 = pstmtLinkReads.executeQuery();

		    while (rs2.next()) {
			int link_readid = rs2.getInt(1);
			int link_seqid = rs2.getInt(2);

			pstmtMappings.setInt(1, link_seqid);

			ResultSet rs3 = pstmtMappings.executeQuery();

			while (rs3.next()) {
			    int link_contigid = rs3.getInt(1);
			    int link_cstart = rs3.getInt(2);
			    int link_cfinish = rs3.getInt(3);
			    String link_direction = rs3.getString(4);

			    ReadMapping link_mapping = new ReadMapping(link_readid, link_cstart, link_cfinish, 
								       link_direction.equalsIgnoreCase("Forward"));

			    if (isCurrentContig(link_contigid)) {
				Contig link_contig = adb.getContigByID(link_contigid, ArcturusDatabase.CONTIG_BASIC_DATA);

				int link_contiglength = link_contig.getLength();

				boolean link_forward = link_direction.equalsIgnoreCase("Forward");

				int gapsize = link_forward ?
				    overhang - (link_contiglength - link_cstart) :
				    overhang - link_cfinish;

				char link_end = link_forward ? 'R' : 'L';

				int myendcode = endcode;

				if (link_forward)
				    myendcode++;

				if (contig != link_contig && gapsize > 0) {
				    bridgeset.addBridge(contig, link_contig, myendcode, template, mappinga, link_mapping, 
							new GapSize(gapsize));

				    linkedContigs.add(link_contig);
				}
			    }
			}

			rs3.close();
		    }

		    rs2.close();
		}

		rs.close();
	    }

	    for (Iterator iterator = linkedContigs.iterator(); iterator.hasNext();) {
		Contig link_contig = (Contig)iterator.next();

		for (int endcode = 0; endcode < 4; endcode++)
		    if (bridgeset.getTemplateCount(contig, link_contig, endcode) >= minbridges &&
			!processed.contains(link_contig))
			contigset.add(link_contig);
	    }
	}

	return bridgeset;
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

    protected Map createLayout(Set bridges) {
	Map layout = new HashMap();
	RowRanges rowranges = new RowRanges();

	Vector bridgevector = new Vector(bridges);

	Collections.sort(bridgevector, new BridgeComparator());

	System.out.println("Sorted graph:");
	for (int j = 0; j < bridgevector.size(); j++)
	    System.out.println("\t" + bridgevector.elementAt(j));
	
	Bridge bridge = (Bridge)bridgevector.firstElement();
	bridgevector.removeElementAt(0);
	
	Contig contiga = bridge.getContigA();
	Contig contigb = bridge.getContigB();
	int endcode = bridge.getEndCode();
	int gapsize = bridge.getGapSize().getMinimum();
	
	Range rangea = new Range(0, contiga.getLength());
	
	int rowa = rowranges.addRange(rangea);
	
	ContigBox cba = new ContigBox(contiga, rowa, rangea, true);
	layout.put(contiga, cba);
	
	ContigBox cbb = calculateRelativePosition(cba, contiga, contigb, endcode, gapsize, rowranges);
	layout.put(contigb, cbb);
	
	System.out.println("# Using " + bridge);
	System.out.println("Laid out contig " + contiga.getID() + " at " + cba);
	System.out.println("Laid out contig " + contigb.getID() + " at " + cbb);
	
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
		System.out.println("# Using " + bridge);
		if (hasa && hasb) {
		    System.out.println("INCONSISTENCY : Both contig " + contiga.getID() + " and contig " +
				       contigb.getID() + " have been laid out already.");
		} else {
		    endcode = bridge.getEndCode();
		    gapsize = bridge.getGapSize().getMinimum();
		    
		    if (hasa) {
			cba = (ContigBox)layout.get(contiga);
			
			cbb = calculateRelativePosition(cba, contiga, contigb, endcode, gapsize, rowranges);
			layout.put(contigb, cbb);
			
			System.out.println("Laid out contig " + contigb.getID() + " at " + cbb);
		    } else {
			cbb = (ContigBox)layout.get(contigb);
			
			if (endcode == 0 || endcode == 3)
			    endcode = 3 - endcode;
			
			cba = calculateRelativePosition(cbb, contigb, contiga, endcode, gapsize, rowranges);
			layout.put(contiga, cba);
			
			System.out.println("Laid out contig " + contiga.getID() + " at " + cba);
		    }
		}
	    } else {
		System.out.println("INCONSISTENCY : Neither contig " + contiga.getID() + " nor contig " +
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
	
	int rowb = rowranges.addRange(rangeb);
	
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

	public boolean isForward() { return forward; }

	public String toString() {
	    return "ContigBox[row=" + row + ", range=" + range.getStart() + ".." + range.getEnd() + ", " +
		(forward ? "forward" : "reverse") + "]";
	}
    }
    
    class ContigBoxComparator implements Comparator {
	public int compare(Object o1, Object o2) {
	    ContigBox box1 = (ContigBox)o1;
	    ContigBox box2 = (ContigBox)o2;
	    
	    int diff = box1.getRange().getStart() - box2.getRange().getStart();

	    if (diff != 0)
		return diff;

	    diff = box1.getRange().getEnd() - box2.getRange().getEnd();

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

	public int addRange(Range range) {
	    for (int row = 0; row < rangesets.size(); row++) {
		Set ranges = (Set)rangesets.elementAt(row);

		boolean overlaps = false;

		for (Iterator iterator = ranges.iterator(); iterator.hasNext() && !overlaps;) {
		    Range rangeInRow = (Range)iterator.next();
		    overlaps = range.overlaps(rangeInRow);
		}

		if (!overlaps) {
		    ranges.add(range);
		    return row;
		}
	    }

	    Set ranges = new HashSet();
	    ranges.add(range);

	    rangesets.add(ranges);
	    return rangesets.indexOf(ranges);
	}
    }
}
