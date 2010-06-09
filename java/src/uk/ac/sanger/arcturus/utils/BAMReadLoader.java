package uk.ac.sanger.arcturus.utils;

import java.io.File;
import java.sql.Connection;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.traceserver.TraceServerClient;

import net.sf.samtools.SAMFileReader;
import net.sf.samtools.SAMRecord;
import net.sf.samtools.util.CloseableIterator;

public class BAMReadLoader {
	private ArcturusDatabase adb;
	private TraceServerClient traceServerClient = null;
	private ReadNameFilter readNameFilter = new BasicCapillaryReadNameFilter();
	
	private int tsLookups;
	private int tsFailures;
	
	private long T0;
	
	public BAMReadLoader() throws ArcturusDatabaseException {
		adb = Utility.getTestDatabase();
		
		adb.setCacheing(ArcturusDatabase.READ, false);
		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);
		adb.setCacheing(ArcturusDatabase.TEMPLATE, false);
		
		String baseURL = Arcturus.getProperty("traceserver.baseURL");
		
		if (baseURL != null && !Boolean.getBoolean("skiptraceserver"))
			traceServerClient = new TraceServerClient(baseURL);
	}
	
	public void processFile(File file) throws ArcturusDatabaseException {
		SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);

		SAMFileReader reader = new SAMFileReader(file);

		CloseableIterator<SAMRecord> iterator = reader.iterator();

		int n = 0;
		
		tsLookups = 0;
		tsFailures = 0;
		
		Connection conn = adb.getDefaultConnection();
		
		try {
			boolean savedAutoCommit = conn.getAutoCommit();
			conn.setAutoCommit(false);
			
			T0 = System.currentTimeMillis();
			
			while (iterator.hasNext()) {
				SAMRecord record = iterator.next();
			
				processRecord(record);
			
				n++;
			
				if ((n%10000) == 0) {
					conn.commit();
					reportMemory(n);
				}
			}
			
			conn.commit();
			
			conn.setAutoCommit(savedAutoCommit);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An SQL exception occurred when processing a file", conn, this);
		}
	}
	
	private static final int FLAGS_MASK = 128 + 64 + 1;
	
	private void processRecord(SAMRecord record) throws ArcturusDatabaseException {
		String readname = record.getReadName();
		
		int flags = record.getFlags() & FLAGS_MASK;
		
		//System.out.println("Read " + readname + ", flags " + flags);
		
		byte[] dna = record.getReadBases();
		
		byte[] quality = record.getBaseQualities();
		
		if (record.getReadNegativeStrandFlag()) {
			dna = reverseComplement(dna);
			quality = reverseQuality(quality);
		}
		
		Read read = adb.getReadByNameAndFlags(readname, flags);
		
		if (read == null) {
			if (traceServerClient != null && readNameFilter.accept(readname)) {
				Sequence storedSequence = traceServerClient.fetchRead(readname);
				
				tsLookups++;
				
				if (storedSequence != null)
					read = storedSequence.getRead();
				else
					tsFailures++;
			}
			
			if (read == null)
				read = new Read(readname, flags);
		
			read = adb.putRead(read);
		}
		
		Sequence sequence = new Sequence(0, read, dna, quality, 0);
		
		Sequence newSequence = adb.findOrCreateSequence(sequence);
		
		//System.out.println("\tStored with ID=" + newRead.getID() +
		//		", sequence ID=" + newSequence.getID());
	}
	
	private byte[] reverseComplement(byte[] src) {
		if (src == null)
			return null;
		
		int srclen = src.length;
		
		byte[] dst = new byte[srclen];
		
		int j = srclen - 1;
		
		for (int i = 0; i < srclen; i++)
			dst[j--] = reverseComplement(src[i]);
		
		return dst;
	}
	
	private byte reverseComplement(byte c) {
		switch (c) {
			case 'a': return 't';
			case 'A': return 'T';
			
			case 'c': return 'g';
			case 'C': return 'G';
			
			case 'g': return 'c';
			case 'G': return 'C';
			
			case 't': return 'a';
			case 'T': return 'A';
			
			default: return c;
		}
	}
	
	private byte[] reverseQuality(byte[] src) {
		if (src == null)
			return null;
		
		int srclen = src.length;
		
		byte[] dst = new byte[srclen];
		
		int j = srclen - 1;
		
		for (int i = 0; i < srclen; i++)
			dst[j--] = src[i];
		
		return dst;
	}

	private void reportMemory(int n) {
		Runtime rt = Runtime.getRuntime();
		
		long freeMemory = rt.freeMemory();
		long totalMemory = rt.totalMemory();
		
		long usedMemory = totalMemory - freeMemory;
		
		long perRead = n == 0 ? 0 : usedMemory/n;
		
		freeMemory /= 1024;
		totalMemory /= 1024;
		usedMemory /= 1024;
		
		long dt = System.currentTimeMillis() - T0;
		
		System.err.println("Reads: " + n + " ; Memory used " + usedMemory + " kb, free " + freeMemory +
				" kb, total " + totalMemory + " kb, per read " + perRead + "; time = " + dt + " ms" +
				"; traceserver lookups = " + tsLookups + ", failures = " + tsFailures);
	}

	public static void main(String[] args) {
		if (args.length == 0) {
			System.err.println("You must supply a BAM file name");
			System.exit(1);
		}
		
		File file = new File(args[0]);
		
		try {
			BAMReadLoader loader = new BAMReadLoader();
		
			loader.processFile(file);
		}
		catch (ArcturusDatabaseException e) {
			e.printStackTrace();
			System.exit(1);
		}
		
		System.exit(0);
	}
}
