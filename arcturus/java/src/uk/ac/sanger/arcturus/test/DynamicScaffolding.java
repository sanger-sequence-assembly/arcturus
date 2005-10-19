import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;

import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.zip.DataFormatException;

import javax.naming.Context;

public class DynamicScaffolding {
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

    protected PucBridgeSet pucbridgeset = new PucBridgeSet();

    public static void main(String args[]) {
	DynamicScaffolding ds = new DynamicScaffolding();
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

	PucBridgeSet pbs = processContigSet(contigset);

	pbs.dump(System.out, minbridges);

	Graph graph = pbs.findGraph(seedcontig, minbridges);

	if (graph != null)
	    System.out.println("Sub-graph containing contig " + seedcontig.getID() + " :\n" + graph);
    }

    protected PucBridgeSet processContigSet(Vector contigset) throws SQLException, DataFormatException {
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

		PreparedStatement pstmt = (iEnd == 0) ? pstmtLeftEndReads : pstmtRightEndReads;

		int limit = (iEnd == 0) ? puclimit : contig.getLength() - puclimit;

		pstmt.setInt(1, contig.getID());
		pstmt.setInt(2, limit);

		ResultSet rs = pstmt.executeQuery();

		while (rs.next()) {
		    int readid = rs.getInt(1);
		    int seqid = rs.getInt(2);
		    int cstart = rs.getInt(3);
		    int cfinish = rs.getInt(4);
		    String direction = rs.getString(5);

		    pstmtTemplate.setInt(1, readid);

		    ResultSet rs2 = pstmtTemplate.executeQuery();

		    int templateid = 0;
		    String strand = null;

		    if (rs2.next()) {
			templateid = rs2.getInt(1);
			strand = rs2.getString(2);
		    }

		    rs2.close();

		    int sihigh = 0;

		    pstmtLigation.setInt(1, templateid);

		    rs2 = pstmtLigation.executeQuery();

		    if (rs2.next())
			sihigh = rs2.getInt(2);

		    rs2.close();

		    int overhang = (iEnd == 0) ? sihigh - cfinish : cstart + sihigh - contiglength;

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

				if (gapsize > 0) {
				    pucbridgeset.addPucBridge(contig, link_contig, myendcode, templateid, readid, link_readid, gapsize);

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
		    if (pucbridgeset.getTemplateCount(contig, link_contig, endcode) >= minbridges &&
			!processed.contains(link_contig))
			contigset.add(link_contig);
	    }
	}

	return pucbridgeset;
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

    class PucBridgeSet {
	private HashMap byContigA = new HashMap();

	public void addPucBridge(Contig contiga, Contig contigb, int endcode, int templateid, int readida,
		       int readidb, int gapsize) {
	    HashMap byContigB = (HashMap)byContigA.get(contiga);

	    if (byContigB == null) {
		byContigB = new HashMap();
		byContigA.put(contiga, byContigB);
	    }

	    HashMap byEndCode = (HashMap)byContigB.get(contigb);

	    if (byEndCode == null) {
		byEndCode = new HashMap();
		byContigB.put(contigb, byEndCode);
	    }

	    Integer intEndCode = new Integer(endcode);

	    HashMap byTemplate = (HashMap)byEndCode.get(intEndCode);
		
	    if (byTemplate == null) {
		byTemplate = new HashMap();
		byEndCode.put(intEndCode, byTemplate);
	    }
		
	    Integer template = new Integer(templateid);
	    
	    PucBridge pucbridge = (PucBridge)byTemplate.get(template);
		
	    if (pucbridge == null) {
		pucbridge = new PucBridge();
		byTemplate.put(template, pucbridge);
	    }

	    pucbridge.addBridge(readida, readidb, gapsize);
	}

	public HashMap getHashMap() { return byContigA; }

	public int getTemplateCount(Contig contiga, Contig contigb, int endcode) {
	    HashMap byContigB = (HashMap)byContigA.get(contiga);

	    if (byContigB == null)
		return 0;

	    HashMap byEndCode = (HashMap)byContigB.get(contigb);

	    if (byEndCode == null)
		return 0;

	    Integer intEndCode = new Integer(endcode);

	    HashMap byTemplate = (HashMap)byEndCode.get(intEndCode);

	    return (byTemplate == null) ? 0 : byTemplate.size();
	}

	public void dump(PrintStream ps, int minsize) {
	    ps.println("PucBridgeSet.dump");

	    Set entries = byContigA.entrySet();

	    for (Iterator iterator = entries.iterator(); iterator.hasNext();) {
		Map.Entry entry = (Map.Entry)iterator.next();

		Contig contiga = (Contig)entry.getKey();
		HashMap byContigB = (HashMap)entry.getValue();

		Set entries2 = byContigB.entrySet();

		for (Iterator iterator2 = entries2.iterator(); iterator2.hasNext();) {
		    Map.Entry entry2 = (Map.Entry)iterator2.next();

		    Contig contigb = (Contig)entry2.getKey();
		    HashMap byEndCode = (HashMap)entry2.getValue();

		    Set entries3 = byEndCode.entrySet();

		    for (Iterator iterator3 = entries3.iterator(); iterator3.hasNext();) {
			Map.Entry entry3 = (Map.Entry)iterator3.next();

			Integer intEndCode = (Integer)entry3.getKey();
			HashMap byTemplate = (HashMap)entry3.getValue();

			int mysize = byTemplate.size();

			GapSize gapsize = new GapSize();

			for (Iterator iterator4 = byTemplate.entrySet().iterator(); iterator4.hasNext();) {
			    Map.Entry entry4 = (Map.Entry)iterator4.next();

			    PucBridge pucbridge = (PucBridge)entry4.getValue();

			    gapsize.add(pucbridge.getGapSize());
			}

			if (mysize >= minsize && contiga.getID() < contigb.getID())
			    ps.println( contiga.getID() + " " + contiga.getLength() + " " +
					contigb.getID() + " " + contigb.getLength() + " " +
					intEndCode + " " + mysize + " " +
					gapsize.getMinimum() + ":" + gapsize.getMaximum());
		    }
		}
	    }	    
	}

	public Graph findGraph(Contig seedcontig, int minbridges) {
	    HashMap subgraphs = new HashMap();

	    Set entries = byContigA.entrySet();

	    for (Iterator iterator = entries.iterator(); iterator.hasNext();) {
		Map.Entry entry = (Map.Entry)iterator.next();

		Contig contiga = (Contig)entry.getKey();
		HashMap byContigB = (HashMap)entry.getValue();

		Set entries2 = byContigB.entrySet();

		for (Iterator iterator2 = entries2.iterator(); iterator2.hasNext();) {
		    Map.Entry entry2 = (Map.Entry)iterator2.next();

		    Contig contigb = (Contig)entry2.getKey();
		    HashMap byEndCode = (HashMap)entry2.getValue();

		    Set entries3 = byEndCode.entrySet();

		    for (Iterator iterator3 = entries3.iterator(); iterator3.hasNext();) {
			Map.Entry entry3 = (Map.Entry)iterator3.next();

			Integer intEndCode = (Integer)entry3.getKey();
			HashMap byTemplate = (HashMap)entry3.getValue();

			int mysize = byTemplate.size();

			GapSize gapsize = new GapSize();

			for (Iterator iterator4 = byTemplate.entrySet().iterator(); iterator4.hasNext();) {
			    Map.Entry entry4 = (Map.Entry)iterator4.next();

			    PucBridge pucbridge = (PucBridge)entry4.getValue();

			    gapsize.add(pucbridge.getGapSize());
			}

			Graph seedgraph = null;

			if (mysize >= minbridges && contiga.getID() < contigb.getID()) {
			    Edge edge = new Edge(contiga, contigb, intEndCode.intValue(), mysize, gapsize);

			    Graph sga = (Graph)subgraphs.get(contiga);
			    Graph sgb = (Graph)subgraphs.get(contigb);

			    if (sga != null && sgb != null) {
				if (sga != sgb)
				    sga = mergeSubGraphs(subgraphs, sga, sgb);

				sga.addEdge(edge);
			    } else if (sga != null) {
				sga.addEdge(edge);
				subgraphs.put(contigb, sga);
			    } else if (sgb != null) {
				sgb.addEdge(edge);
				subgraphs.put(contiga, sgb);
			    } else {
				Graph graph = new Graph();
				graph.addEdge(edge);
				subgraphs.put(contiga, graph);
				subgraphs.put(contigb, graph);
			    }
			}
		    }
		}
	    }	    

	    return (Graph)subgraphs.get(seedcontig);
	}

	private Graph mergeSubGraphs(HashMap subgraphs, Graph sga, Graph sgb) {
	    return (sga.size() < sgb.size()) ? copyGraph(subgraphs, sga, sgb) : copyGraph(subgraphs, sgb, sga);
	}

	private Graph copyGraph(HashMap subgraphs, Graph src, Graph dst) {
	    for (Iterator iterator = src.iterator(); iterator.hasNext();) {
		Edge edge = (Edge)iterator.next();
		Contig contiga = edge.getContigA();
		Contig contigb = edge.getContigB();
		dst.addEdge(edge);
		subgraphs.put(contiga, dst);
		subgraphs.put(contigb, dst);
	    }

	    return dst;
	}
    }

    class PucBridge {
	private Set readSetA = new HashSet();
	private Set readSetB = new HashSet();
	private GapSize gapsize = new GapSize();

	public void addBridge(int readidA, int readidB, int gapsize) {
	    readSetA.add(new Integer(readidA));
	    readSetB.add(new Integer(readidB));

	    this.gapsize.add(gapsize);
	}

	public GapSize getGapSize() { return gapsize; }

	public int getMinimumGapSize() { return gapsize.getMinimum(); }

	public int getMaximumGapSize() { return gapsize.getMaximum(); }

	public Set getReadSetA() { return readSetA; }

	public int getCardinalityA() { return readSetA.size(); }

	public Set getReadSetB() { return readSetB; }

	public int getCardinalityB() { return readSetB.size(); }
    }

    class GapSize {
	private int minsize = -1;
	private int maxsize = -1;

	public GapSize() {}

	public GapSize(int minsize, int maxsize) {
	    this.minsize = minsize;
	    this.maxsize = maxsize;
	}

	public int getMinimum() { return minsize; }

	public int getMaximum() { return maxsize; }

	public void add(int value) {
	    if (minsize < 0 || value < minsize)
		minsize = value;

	    if (maxsize < 0 || value > maxsize)
		maxsize = value;
	}

	public void add(GapSize that) {
	    if (minsize < 0 || (that.minsize >= 0 && that.minsize < minsize))
		minsize = that.minsize;

	    if (maxsize < 0 || (that.maxsize >=0 && that.maxsize > maxsize))
		maxsize = that.maxsize;
	}

	public String toString() { return "GapSize[" + minsize + ":" + maxsize + "]"; }
    }

    class Graph {
	protected Set edges = new HashSet();

	public int size() { return edges.size(); }

	public void addEdge(Edge edge) {
	    edges.add(edge);
	}

	public Set getEdgeSet() { return edges; }

	public Iterator iterator() { return edges.iterator(); }

	public String toString() {
	    StringBuffer sb = new StringBuffer();

	    sb.append("Graph[\n");

	    for (Iterator iterator = edges.iterator(); iterator.hasNext();)
		sb.append("\t" + (Edge)iterator.next() + "\n");

	    sb.append("]");

	    return sb.toString();
	}
    }

    class Edge {
	protected Contig contiga;
	protected Contig contigb;
	protected int endcode;
	protected int nTemplates;
	protected GapSize gapsize;

	public Edge(Contig contiga, Contig contigb, int endcode, int nTemplates, GapSize gapsize) {
	    this.contiga = contiga;
	    this.contigb = contigb;
	    this.endcode = endcode;
	    this.nTemplates = nTemplates;
	    this.gapsize = gapsize;
	}

	public Contig getContigA() { return contiga; }

	public Contig getContigB() { return contigb; }

	public int getEndCode() { return endcode; }

	public int getTemplateCount() { return nTemplates; }

	public GapSize getGapSize() { return gapsize; }

	public String toString() {
	    return "Edge[" + contiga.getID() + ", " + contigb.getID() + ", " + endcode + ", " +
		nTemplates + ", " + gapsize + "]";
	}
    }
}
