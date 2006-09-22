package uk.ac.sanger.arcturus.test;

import java.util.Properties;
import javax.naming.Context;

import java.sql.*;
import java.io.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.*;

public class CompareReads {
    ArcturusDatabase adb1;
    ArcturusDatabase adb2;
    Connection conn1;
    ResultSet rs;

    String instance1;
    String organism1;
    String instance2;
    String organism2;
    String instance;
    String namelike;

    String readname;

    private static final String NULL1 = "NULL1";
    private static final String NULL2 = "NULL2";

    public CompareReads(String[] args) {
	boolean cacheing = true;

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-instance"))
		instance = args[++i];

	    if (args[i].equalsIgnoreCase("-instance1"))
		instance1 = args[++i];

	    if (args[i].equalsIgnoreCase("-instance2"))
		instance2 = args[++i];

	    if (args[i].equalsIgnoreCase("-organism1"))
		organism1 = args[++i];

	    if (args[i].equalsIgnoreCase("-organism2"))
		organism2 = args[++i];

	    if (args[i].equalsIgnoreCase("-namelike"))
		namelike = args[++i];

	    if (args[i].equalsIgnoreCase("-nocache"))
		cacheing = false;
	}

	if (instance != null) {
	    instance1 = instance;
	    instance2 = instance;
	}

	if (instance1 == null || organism1 == null ||
	    instance2 == null || organism2 == null) {
	    System.err.println("One or more arguments is missing");
	    System.exit(1);
	}

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, env.get(Context.PROVIDER_URL));

	System.err.println("Cacheing is " + (cacheing ? "ON" : "OFF"));

	try {
	    System.err.println("Creating an ArcturusInstance for " + instance1);
	    System.err.println();

	    ArcturusInstance ai1 = new ArcturusInstance(props, instance1);

	    System.err.println("Creating an ArcturusDatabase for " + organism1);
	    System.err.println();

	    adb1 = ai1.findArcturusDatabase(organism1);

	    adb1.setReadCacheing(cacheing);
	    adb1.setSequenceCacheing(cacheing);

	    ArcturusInstance ai2;

	    if (instance1.equalsIgnoreCase(instance2)) {
		ai2 = ai1;
	    } else {
		System.err.println("Creating an ArcturusInstance for " + instance2);
		System.err.println();

		ai2 = new ArcturusInstance(props, instance2);
	    }

	    System.err.println("Creating an ArcturusDatabase for " + organism2);
	    System.err.println();

	    adb2 = ai2.findArcturusDatabase(organism2);

	    adb2.setReadCacheing(cacheing);
	    adb2.setSequenceCacheing(cacheing);

	    conn1 = adb1.getConnection();
	    
	    String query = "select readname from READS";

	    if (namelike != null)
		query += " where readname like ?";

	    PreparedStatement pstmt = conn1.prepareStatement(query);

	    if (namelike != null)
		pstmt.setString(1, namelike);

	    rs = pstmt.executeQuery();
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    public void run() {
	int nreads = 0;

	try {
	    while (rs.next()) {
		readname = rs.getString(1);

		Read read1 = adb1.getReadByName(readname);
		Read read2 = adb2.getReadByName(readname);

		if (read1 != null && read2 != null) {
		    compareReads(read1, read2, System.out);
		    nreads++;
		} else {
		    if (read2 == null)
			System.out.println("*** Read " + readname + " not present in " +
					   instance2 + "/" + organism2);
		    
		    if (read1 == null)
			System.err.println("*** Read " + readname + " not present in primary database");
		}
	    }
	    
	    System.out.println("Compared " + nreads + " reads");

	    rs.close();
	}
	catch (SQLException sqle) {
	    sqle.printStackTrace();
	    System.exit(1);
	}
    }

    private void compareReads(Read read1, Read read2, PrintStream ps) throws SQLException {
	int strand1 = read1.getStrand();
	int strand2 = read2.getStrand();

	if (strand1 != strand2)
	    reportMismatch(ps, "Strand mismatch: " + strand1 + " vs " + strand2);

	int chemistry1 = read1.getChemistry();
	int chemistry2 = read2.getChemistry();

	if (chemistry1 != chemistry2)
	    reportMismatch(ps, "Chemistry mismatch: " + chemistry1 + " vs " + chemistry2);

	int primer1 = read1.getPrimer();
	int primer2 = read2.getPrimer();

	if (primer1 != primer2)
	    reportMismatch(ps, "Primer mismatch: " + primer1 + " vs " + primer2);

	Template template1 = read1.getTemplate();
	Template template2 = read2.getTemplate();

	compareTemplates(template1, template2, ps);

	Sequence seq1 = adb1.getSequenceByReadID(read1.getID());
	Sequence seq2 = adb2.getSequenceByReadID(read2.getID());

	compareSequences(seq1, seq2, ps);
    }

    private void compareTemplates(Template template1, Template template2, PrintStream ps) {
	String tname1 = template1 == null ? NULL1 : template1.getName();
	String tname2 = template2 == null ? NULL2 : template2.getName();

	if (!tname1.equalsIgnoreCase(tname2))
	    reportMismatch(ps, "Template name mismatch: " + tname1 + " vs " + tname2);

	if (template1 == null || template2 == null)
	    return;

	Ligation ligation1 = template1.getLigation();
	Ligation ligation2 = template2.getLigation();

	compareLigations(ligation1, ligation2, ps);
    }

    private void compareLigations(Ligation ligation1, Ligation ligation2, PrintStream ps) {
	String lname1 = ligation1 == null ? NULL1 : ligation1.getName();
	String lname2 = ligation2 == null ? NULL2 : ligation2.getName();

	if (!lname1.equalsIgnoreCase(lname2))
	    reportMismatch(ps, "Ligation name mismatch: " + lname1 + " vs " + lname2);

	if (ligation1 == null || ligation2 == null)
	    return;

	int sihigh1 = ligation1.getInsertSizeHigh();
	int sihigh2 = ligation2.getInsertSizeHigh();

	if (sihigh1 != sihigh2)
	    reportMismatch(ps, "Upper insert size mismatch: " + sihigh1 + " vs " + sihigh2);


	int silow1 = ligation1.getInsertSizeLow();
	int silow2 = ligation2.getInsertSizeLow();

	if (silow1 != silow2)
	    reportMismatch(ps, "Lower insert size mismatch: " + silow1 + " vs " + silow2);

	Clone clone1 = ligation1.getClone();
	Clone clone2 = ligation2.getClone();

	compareClones(clone1, clone2, ps);
    }

    private void compareClones(Clone clone1, Clone clone2, PrintStream ps) {
	String cname1 = clone1 == null ? NULL1 : clone1.getName();
	String cname2 = clone2 == null ? NULL2 : clone2.getName();

	if (!cname1.equalsIgnoreCase(cname2))
	    reportMismatch(ps, "Clone name mismatch: " + cname1 + " vs " + cname2);
    }

    private void compareSequences(Sequence seq1, Sequence seq2, PrintStream ps) {
	int seqlen1 = seq1.getLength();
	int seqlen2 = seq2.getLength();

	if (seqlen1 != seqlen2)
	    reportMismatch(ps, "Sequence length: " + seqlen1 + " vs " + seqlen2);

	Clipping qclip1 = seq1.getQualityClipping();
	Clipping qclip2 = seq2.getQualityClipping();

	if (qclip1 != null || qclip2 != null)
	    compareClipping(qclip1, qclip2, "Quality", ps);

	Clipping cvclip1 = seq1.getCloningVectorClipping();
	Clipping cvclip2 = seq2.getCloningVectorClipping();

	if (cvclip1 != null || cvclip2 != null)
	    compareClipping(cvclip1, cvclip2, "Cloning Vector", ps);

	Clipping svclip1 = seq1.getSequenceVectorClippingLeft();
	Clipping svclip2 = seq2.getSequenceVectorClippingLeft();

	if (svclip1 != null || svclip2 != null)
	    compareClipping(svclip1, svclip2, "Sequence Vector Left", ps);

	svclip1 = seq1.getSequenceVectorClippingRight();
	svclip2 = seq2.getSequenceVectorClippingRight();

	if (svclip1 != null || svclip2 != null)
	    compareClipping(svclip1, svclip2, "Sequence Vector Right", ps);
    }

    private void compareClipping(Clipping clip1, Clipping clip2, String type, PrintStream ps) {
	if (clip1 == null)
	    reportMismatch(ps, type + " clipping missing from primary sequence");
	else if (clip2 == null)
	    reportMismatch(ps, type + " clipping missing from secondary sequence");
	else if (!clip1.equals(clip2))
	    reportMismatch(ps, type + " clipping mismatch: " + clip1 + " vs " + clip2);
    }

    private void reportMismatch(PrintStream ps, String message) {
	ps.print(readname);
	ps.print('\t');
	ps.println(message);
    }

    public static void main(String[] args) {
	CompareReads cr = new CompareReads(args);

	cr.run();
    }
}
