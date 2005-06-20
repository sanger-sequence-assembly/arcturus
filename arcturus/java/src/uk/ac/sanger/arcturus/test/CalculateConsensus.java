import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;

import java.util.*;
import java.util.zip.*;
import java.io.*;
import java.sql.*;

import javax.naming.Context;

public class CalculateConsensus {
    private long lasttime;
    private Runtime runtime = Runtime.getRuntime();

    private Consensus consensus = new Consensus();
   
    private String instance = null;
    private String organism = null;
    
    private String objectname = null;
    
    private String algname = null;

    private int flags = ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS;

    private ArcturusDatabase adb = null;
    private Connection conn = null;

    private boolean debug = false;
    private boolean lowmem = false;
    private boolean quiet = false;
    private boolean allcontigs = false;
    
    private String assemblyname = null;
    private String projectname = null;
    
    private ConsensusAlgorithm algorithm = null;

    private PreparedStatement insertStmt = null;
    private Deflater compresser = new Deflater(Deflater.BEST_COMPRESSION);

    private String consensustable = null;
 
    public static void main(String args[]) {
	CalculateConsensus cc = new CalculateConsensus();
	cc.execute(args);
    }

    public void execute(String args[]) {
	lasttime = System.currentTimeMillis();

	System.err.println("CalculateConsensus");
	System.err.println("==================");
	System.err.println();

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	String separator = "                    --------------------                    ";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-instance"))
		instance = args[++i];

	    if (args[i].equalsIgnoreCase("-organism"))
		organism = args[++i];

	    if (args[i].equalsIgnoreCase("-algorithm"))
		algname = args[++i];

	    if (args[i].equalsIgnoreCase("-consensustable"))
		consensustable = args[++i];

	    if (args[i].equalsIgnoreCase("-debug"))
		debug = true;

	    if (args[i].equalsIgnoreCase("-lowmem"))
		lowmem = true;

	    if (args[i].equalsIgnoreCase("-quiet"))
		quiet = true;

	    if (args[i].equalsIgnoreCase("-allcontigs"))
		allcontigs = true;
	}

	if (instance == null || organism == null) {
	    printUsage(System.err);
	    System.exit(1);
	}

	if (consensustable == null)
	    consensustable = "CONSENSUS";

	if (algname == null)
	    algname = System.getProperty("arcturus.default.algorithm");

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

	    if (!quiet)
		adb.addContigManagerEventListener(new MyListener());

	    Class algclass = Class.forName(algname);
	    algorithm = (ConsensusAlgorithm)algclass.newInstance();

	    if (debug && algorithm instanceof uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus)
		((Gap4BayesianConsensus)algorithm).setDebugPrintStream(System.out);

	    int sequenceCounter = 0;
	    int nContigs = 0;
	    long peakMemory = 0;

	    String query = allcontigs ? "select contig_id from CONTIG" :
		"select CONTIG.contig_id from CONTIG left join " + consensustable + " using(contig_id) where sequence is null";

	    Statement stmt = conn.createStatement();

	    ResultSet rs = stmt.executeQuery(query);

	    while (rs.next()) {
		int contig_id = rs.getInt(1);
		calculateConsensusForContig(contig_id);
		nContigs++;
	    }

	    System.err.println(nContigs + " contigs were processed");
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    public void calculateConsensusForContig(int contig_id) throws SQLException, DataFormatException {
	long clockStart = System.currentTimeMillis();
	    
	Contig contig = adb.getContigByID(contig_id, flags);

	PrintStream debugps = debug ? System.out : null;
	    
	if (calculateConsensus(contig, algorithm, consensus, debugps)) {
	    long usedMemory = (runtime.totalMemory() - runtime.freeMemory())/1024;
	    long clockStop = System.currentTimeMillis() - clockStart;
	    System.err.println("CONTIG " + contig_id + ": " + contig.getLength() + " bp, " +
			       contig.getReadCount() + " reads, " +  clockStop + " ms, " + usedMemory + " kb");
	    storeConsensus(contig_id, consensus);
	} else
	    System.err.println("Data missing, operation abandoned");
	
	if (lowmem)
	    contig.setMappings(null);
    }

    public void report() {
	long timenow = System.currentTimeMillis();

	System.out.println("******************** REPORT ********************");
	System.out.println("Time: " + (timenow - lasttime));

	System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()/1024 + "/" + runtime.totalMemory()/1024);
	System.out.println("************************************************");
	System.out.println();
    }

    public void printUsage(PrintStream ps) {
	ps.println("MANDATORY PARAMETERS:");
	ps.println("\t-instance\tName of instance");
	ps.println("\t-organism\tName of organism");
	ps.println();
	ps.println("OPTIONAL PARAMETERS");
	ps.println("\t-algorithm\tName of class for consensus algorithm");
	ps.println("\t-consensustable\tName of consensus table");
	ps.println();
	ps.println("OPTIONS");
	String[] options = {"-debug", "-lowmem", "-quiet"};
	for (int i = 0; i < options.length; i++)
	    ps.println("\t" + options[i]);
    }

    public boolean calculateConsensus(Contig contig, ConsensusAlgorithm algorithm, Consensus consensus,
				      PrintStream debugps) {
	if (contig == null || contig.getMappings() == null)
	    return false;

	Mapping[] mappings = contig.getMappings();
	int nreads = mappings.length;
	int cpos, rdleft, rdright, oldrdleft, oldrdright;
	int maxleft = -1, maxright = -1, maxdepth = -1;

	int cstart = mappings[0].getContigStart();
	int cfinal = mappings[0].getContigFinish();

	for (int i = 0; i < mappings.length; i++) {
	    if (mappings[i].getSequence() == null || mappings[i].getSequence().getDNA() == null ||
		mappings[i].getSequence().getQuality() == null || mappings[i].getSegments() == null)
		return false;

	    if (mappings[i].getContigStart() < cstart)
		cstart = mappings[i].getContigStart();
	    
	    if (mappings[i].getContigFinish() > cfinal)
		cfinal = mappings[i].getContigFinish();
	}
	
	int truecontiglength = 1 + cfinal - cstart;

	byte[] sequence = new byte[truecontiglength];
	byte[] quality = new byte[truecontiglength];

	for (cpos = cstart, rdleft = 0, oldrdleft = 0, rdright = -1, oldrdright = -1;
	     cpos <= cfinal;
	     cpos++) {
	    while ((rdleft < nreads) && (mappings[rdleft].getContigFinish() < cpos))
		rdleft++;

	    while ((rdright < nreads - 1) && (mappings[rdright+1].getContigStart() <= cpos))
		rdright++;

	    int depth = 1 + rdright - rdleft;

	    if (rdleft != oldrdleft || rdright != oldrdright) {
		if (depth > maxdepth) {
		    maxdepth = depth;
		    maxleft = cpos;
		}
	    }

	    if (depth == maxdepth)
		maxright = cpos;

	    oldrdleft = rdleft;
	    oldrdright = rdright;

	    if (debugps != null) {
		debugps.println("CONSENSUS POSITION: " + (1 + cpos - cstart));
	    }

	    algorithm.reset();

	    for (int rdid = rdleft; rdid <= rdright; rdid++) {
		int rpos = mappings[rdid].getReadOffset(cpos);
		Read read = mappings[rdid].getSequence().getRead();
		int read_id = read.getID();

		if (rpos >= 0) {
		    char base = mappings[rdid].getBase(rpos);
		    int qual = mappings[rdid].getQuality(rpos);

		    //if (debugps != null)
		    //debugps.println("  MAPPING " + rdid + ", READ " + read_id + " : position=" + rpos +
		    //			", base=" + base + ", quality=" + qual);

		    if (qual > 0)
			algorithm.addBase(base, qual, read.getStrand(), read.getChemistry());
		} else {
		    int qual = mappings[rdid].getPadQuality(cpos);

		    //if (debugps != null)
		    //debugps.println("  MAPPING " + rdid + ", READ " + read_id + " : pad quality=" + qual);

		    if (qual > 0)
			algorithm.addBase('*', qual, read.getStrand(), read.getChemistry());
		}
	    }

	    try {
		sequence[cpos-cstart] = (byte)algorithm.getBestBase();
		if (debugps != null)
		    debugps.print("RESULT --> " + algorithm.getBestBase());
	    }
	    catch (ArrayIndexOutOfBoundsException e) {
		System.err.println("Sequence array overflow: " + cpos + " (base=" + cstart + ")");
	    }

	    try {
		quality[cpos-cstart] = (byte)algorithm.getBestScore();
		if (debugps != null)
		    debugps.println(" [" + algorithm.getBestScore() + "]");
	    }
	    catch (ArrayIndexOutOfBoundsException e) {
		System.err.println("Quality array overflow: " + cpos + " (base=" + cstart + ")");
	    }
	}
	
	consensus.setDNA(sequence);
	consensus.setQuality(quality);

	return true;
    }

    public void storeConsensus(int contig_id, Consensus consensus) throws SQLException {
	if (insertStmt == null)
	    insertStmt = conn.prepareStatement("insert into " + consensustable + " (contig_id,sequence,length,quality)" +
						   " VALUES(?,?,?,?)");

	byte[] sequence = consensus.getDNA();
	byte[] quality = consensus.getQuality();

	int seqlen = sequence.length;

	byte[] buffer = new byte[12 + (5*seqlen)/4];

	compresser.reset();
	compresser.setInput(sequence);
	compresser.finish();
	int compressedSequenceLength = compresser.deflate(buffer);
	byte[] compressedSequence = new byte[compressedSequenceLength];
	for (int i = 0; i < compressedSequenceLength; i++)
	    compressedSequence[i] = buffer[i];

	compresser.reset();
	compresser.setInput(quality);
	compresser.finish();
	int compressedQualityLength = compresser.deflate(buffer);
	byte[] compressedQuality = new byte[compressedQualityLength];
	for (int i = 0; i < compressedQualityLength; i++)
	    compressedQuality[i] = buffer[i];

	insertStmt.setInt(1, contig_id);
	insertStmt.setBytes(2, compressedSequence);
	insertStmt.setInt(3, seqlen);
	insertStmt.setBytes(4, compressedQuality);
	insertStmt.executeUpdate();
    }

    private class Consensus {
	protected byte[] dna = null;
	protected byte[] quality = null;

	public void setDNA(byte[] dna) { this.dna = dna; }

	public byte[] getDNA() { return dna; }

	public void setQuality(byte[] quality) { this.quality = quality; }

	public byte[] getQuality() { return quality; }
    }

    class MyListener implements ManagerEventListener {
	private long clock;
	private Runtime runtime = Runtime.getRuntime();
	
	public void managerUpdate(ManagerEvent event) {
	    switch (event.getState()) {
	    case ManagerEvent.START:
		System.err.println("START -- " + event.getMessage());
		clock = System.currentTimeMillis();
		break;
		
	    case ManagerEvent.WORKING:
		//System.err.print('.');
		break;
		
	    case ManagerEvent.END:
		//System.err.println();
		clock = System.currentTimeMillis() - clock;
		System.err.println("END   -- " + clock + " ms");
		System.err.println("MEM      FREE=" + runtime.freeMemory()/1024 + ", TOTAL=" + runtime.totalMemory()/1024);
		System.err.println();
		break;
	    }
	}
    }
}
