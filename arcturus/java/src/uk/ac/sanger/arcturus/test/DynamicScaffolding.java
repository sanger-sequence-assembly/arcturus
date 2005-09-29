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

    protected Graph graph = new Graph();

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
	pstmtContigData.setInt(1, seedcontigid);

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

	processContigSet(contigset);
    }

    protected void processContigSet(Vector contigset) throws SQLException, DataFormatException {
	Set processed = new HashSet();

	while (!contigset.isEmpty()) {
	    Contig contig = (Contig)contigset.elementAt(0);
	    contigset.removeElementAt(0);

	    if (processed.contains(contig))
		continue;

	    processed.add(contig);

	    if (contig.getLength() < minlen)
		continue;

	    System.err.println("Processing " + contig);

	    int contiglength = contig.getLength();

	    Set linkedContigs = new HashSet();

	    for (int iEnd = 0; iEnd < 2; iEnd++) {
		//System.err.println((iEnd == 0) ? "LEFT END" : "RIGHT END");

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

		    //System.err.println("Read " + readid + ", sequence " + seqid + " , cstart " + cstart +
		    //		       ", cfinish " + cfinish + ", " + direction);

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

			//System.err.println("\tREADID " + link_readid + " SEQID " + link_seqid);

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
				    //System.err.println("\t\tCONTIG " + link_contigid + " CSTART " + link_cstart +
				    //	       " CFINISH " + link_cfinish + " " + link_direction +
				    //	       " // GAP " + gapsize);

				    //System.err.println(contig.getID() + " " + link_contigid + " " + myendcode +
				    //	       " " + templateid + " " + readid + " " + link_readid + " " + gapsize);

				    graph.addLink(contig, link_contig, myendcode, templateid, readid, link_readid, gapsize);

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
		    if (graph.getTemplateCount(contig, link_contig, endcode) >= minbridges && !processed.contains(link_contig))
			contigset.add(link_contig);
	    }
	}

	graph.dump(System.out, minbridges);
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

    class Graph {
	private HashMap byContigA = new HashMap();

	public void addLink(Contig contiga, Contig contigb, int endcode, int templateid, int readida,
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

	    Link link = (Link)byTemplate.get(template);

	    if (link == null) {
		link = new Link();
		byTemplate.put(template, link);
	    }

	    link.addBridge(readida, readidb, gapsize);
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
	    ps.println("Graph.dump");

	    Set entries = byContigA.entrySet();

	    for (Iterator iterator = entries.iterator(); iterator.hasNext();) {
		Map.Entry entry = (Map.Entry)iterator.next();

		Contig contiga = (Contig)entry.getKey();
		HashMap byContigB = (HashMap)entry.getValue();

		//ps.println("CONTIG A = " + contiga.getID() + " (" + contiga.getName() + ", " + contiga.getLength() + ")");

		Set entries2 = byContigB.entrySet();

		for (Iterator iterator2 = entries2.iterator(); iterator2.hasNext();) {
		    Map.Entry entry2 = (Map.Entry)iterator2.next();

		    Contig contigb = (Contig)entry2.getKey();
		    HashMap byEndCode = (HashMap)entry2.getValue();

		    //ps.println("\tCONTIG B = " + contigb.getID() + " (" + contigb.getName() + ", " + contigb.getLength() + ")");

		    Set entries3 = byEndCode.entrySet();

		    for (Iterator iterator3 = entries3.iterator(); iterator3.hasNext();) {
			Map.Entry entry3 = (Map.Entry)iterator3.next();

			Integer intEndCode = (Integer)entry3.getKey();
			HashMap byTemplate = (HashMap)entry3.getValue();

			int mysize = byTemplate.size();

			if (mysize >= minsize)
			    ps.println( contiga.getID() + " " + contiga.getLength() + " " +
					contigb.getID() + " " + contigb.getLength() + " " +
					intEndCode + " " + mysize);
		    }
		}
	    }	    
	}
    }

    class Link {
	private Set readSetA = new HashSet();
	private Set readSetB = new HashSet();
	private int gapsize = -1;

	public void addBridge(int readidA, int readidB, int gapsize) {
	    readSetA.add(new Integer(readidA));
	    readSetB.add(new Integer(readidB));

	    if (this.gapsize < 0 || this.gapsize > gapsize)
		this.gapsize = gapsize;
	}

	public int getGapSize() { return gapsize; }

	public Set getReadSetA() { return readSetA; }

	public int getCardinalityA() { return readSetA.size(); }

	public Set getReadSetB() { return readSetB; }

	public int getCardinalityB() { return readSetB.size(); }
    }
}
