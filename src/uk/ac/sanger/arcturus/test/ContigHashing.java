import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;
import java.io.*;
import java.sql.*;

import javax.naming.Context;

public class ContigHashing {
    private static long lasttime;

    public static void main(String args[]) {
	lasttime = System.currentTimeMillis();

	int mappingOption = ArcturusDatabase.CONTIG_NO_MAPPING;

	int consensusOption = ArcturusDatabase.CONTIG_CONSENSUS;

	System.out.println("ContigHashing");
	System.out.println("=============");
	System.out.println();

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	String separator = "                    --------------------                    ";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	String instance = null;
	String organism = null;
	String objectname = null;

	if (args.length < 3) {
	    System.out.println("Argument(s) missing: instance organism kmer-size");
	    System.exit(1);
	}

	instance = args[0];
	organism = args[1];
	int kmersize = Integer.parseInt(args[2]);

	boolean storeKmers = Boolean.getBoolean("storeKmers");

	Connection conn = null;
	PreparedStatement pstmt = null;

	HashMap kmers = new HashMap();

	try {
	    System.out.println("Creating an ArcturusInstance for " + instance);
	    System.out.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.out.println("Creating an ArcturusDatabase for " + organism);
	    System.out.println();

	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	    if (storeKmers) {
		conn = adb.getConnection();
		pstmt = conn.prepareStatement("INSERT INTO KMER(contig_id,offset,kmer) VALUES(?,?,?)");
	    }

	    int[] contigIdList = adb.getCurrentContigIDList();

	    for (int i = 0; i < contigIdList.length; i++) {
		int id = contigIdList[i];

		Contig contig = adb.getContigByID(id, consensusOption, mappingOption);

		byte[] dna = contig.getConsensus();

		int maxoffset = dna.length - kmersize;

		for (int offset = 0; offset < maxoffset; offset += kmersize) {
		    int kmer = 0;

		    for (int j = 0; j < kmersize; j++) {
			int val = 0;

			switch (dna[offset + j]) {
			case 'a': case 'A': val = 0; break;
			case 'c': case 'C': val = 1; break;
			case 'g': case 'G': val = 2; break;
			case 't': case 'T': val = 3; break;
			default: val = 0; break;
			}

			kmer <<= 2;
			kmer |= val;
		    }

		    Integer iKmer = new Integer(kmer);

		    Kmer head = (Kmer)kmers.get(iKmer);

		    Kmer newHead = new Kmer(offset, kmer, head);

		    kmers.put(iKmer, newHead);

		    if (storeKmers) {
			pstmt.setInt(1, id);
			pstmt.setInt(2, offset);
			pstmt.setInt(3, kmer);

			pstmt.executeUpdate();
		    }
		}
	    }

	    if (storeKmers) {
		pstmt.close();
	    }

	    report();

	    int[] readIdList = adb.getUnassembledReadIDList();

	    System.out.println("There are " + readIdList.length + " unassembled reads");

	    report();
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }


    public static void report() {
	long timenow = System.currentTimeMillis();

	System.out.println("******************** REPORT ********************");
	System.out.println("Time: " + (timenow - lasttime));

	lasttime = timenow;

	Runtime runtime = Runtime.getRuntime();

	System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()/1024 + "/" + runtime.totalMemory()/1024);
	System.out.println("************************************************");
	System.out.println();
    }

}

class Kmer {
    Kmer next;
    int contig_id;
    int offset;

    public Kmer(int contig_id, int offset, Kmer next) {
	this.contig_id = contig_id;
	this.offset = offset;
	this.next = next;
    }

    public int getContigID() { return contig_id; }

    public int getOffset() { return offset; }

    public Kmer getNext() { return next; }
}
