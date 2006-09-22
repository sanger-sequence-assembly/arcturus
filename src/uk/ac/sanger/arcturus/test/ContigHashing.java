package uk.ac.sanger.arcturus.test;

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

	int option = ArcturusDatabase.CONTIG_CONSENSUS;

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

	int cutoff = Integer.getInteger("cutoff", 20).intValue();

	Connection conn = null;
	PreparedStatement pstmt = null;

	HashMap kmers = new HashMap(2 << kmersize);

	try {
	    System.out.println("Creating an ArcturusInstance for " + instance);
	    System.out.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.out.println("Creating an ArcturusDatabase for " + organism);
	    System.out.println();

	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	    int[] contigIdList = adb.getCurrentContigIDList();

	    for (int i = 0; i < contigIdList.length; i++) {
		int id = contigIdList[i];

		Contig contig = adb.getContigByID(id, option);

		byte[] dna = contig.getDNA();

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
		}
	    }

	    report("GENERATED KMERS");

	    Set entries = kmers.entrySet();

	    Iterator iter = entries.iterator();

	    int nEntries = 0;
	    int maxCount = 0;
	    int sumCount = 0;
	    int nTrimmedEntries = 0;

	    while (iter.hasNext()) {
		Map.Entry mapentry = (Map.Entry)iter.next();

		Integer iKmer = (Integer)mapentry.getKey();

		Kmer head = (Kmer)mapentry.getValue();

		int headCount = 0;

		while (head != null) {
		    headCount++;
		    head = head.getNext();
		}

		if (headCount > 0) {
		    nEntries++;
		    sumCount += headCount;
		    if (headCount > maxCount)
			maxCount = headCount;

		    if (headCount > cutoff) {
			iter.remove();
		    } else {
			nTrimmedEntries++;
		    }
		}
	    }

	    float average = (float)sumCount/(float)nEntries;

	    System.err.println("There are " + nEntries + " distinct kmers, and " + nTrimmedEntries +
			       " after trimming to " + cutoff);
	    System.err.println("The average cardinality is " + average);
	    System.err.println("The maximum cardinality is " + maxCount);

	    report("ANALYSED KMER STATISTICS");

	    int[] readIdList = adb.getUnassembledReadIDList();

	    System.out.println("There are " + readIdList.length + " unassembled reads");

	    report("LOADED UNASSEMBLED READS");

	    int hits = 0;

	    for (int i = 0; i < readIdList.length; i++) {
		if (i%1000 == 0)
		    report("HASHED " + i + " READS");

		int readid = readIdList[i];
		Sequence seq = adb.getFullSequenceByReadID(readid);

		byte[] dna = seq.getDNA();

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

		    while (head != null) {
			int contigid = head.getContigID();
			int contigoffset = head.getOffset();
			hits++;
			//System.out.println(kmer + " " + contigid + " " + contigoffset + " " + readid + " " + offset);
			head = head.getNext();
		    }
		}
	    }

	    System.err.println("Found " + hits + " kmer matches between contigs and reads");

	    report("FINISHED");
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }


    public static void report(String message) {
	long timenow = System.currentTimeMillis();

	System.out.println("******************** REPORT ********************");
	System.out.println("Message: " + message);
	System.out.println("Time: " + (timenow - lasttime));

	lasttime = timenow;

	Runtime runtime = Runtime.getRuntime();

	System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()/1024 + "/" + runtime.totalMemory()/1024);
	System.out.println("************************************************");
	System.out.println();
    }

    byte[] KmerToSequence(int kmer, int kmerlength) {
	byte[] alphabet = {'A','C','G','T'};
	byte[] chars = new byte[kmerlength];

	for (int i = 0; i < kmerlength; i++) {
	    int code = kmer % 4;
	    chars[kmerlength - i] = (byte)code;
	    kmer >>>= 2;
	}

	return chars;
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
