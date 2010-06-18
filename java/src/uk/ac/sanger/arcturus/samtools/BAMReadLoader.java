package uk.ac.sanger.arcturus.samtools;

import java.io.File;
import java.sql.Connection;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.traceserver.TraceServerClient;
import uk.ac.sanger.arcturus.utils.BasicCapillaryReadNameFilter;
import uk.ac.sanger.arcturus.utils.ReadNameFilter;

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

	public BAMReadLoader(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;
		prepareLoader();
	}
	
	private void prepareLoader() {
		
		adb.setCacheing(ArcturusDatabase.READ, false);
		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);
		adb.setCacheing(ArcturusDatabase.TEMPLATE, false);
		
		String baseURL = Arcturus.getProperty("traceserver.baseURL");
		
		if (baseURL != null && !Boolean.getBoolean("skiptraceserver"))
			traceServerClient = new TraceServerClient(baseURL);
	}
	
	public void processFile(SAMFileReader reader) throws ArcturusDatabaseException {

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
			
				findOrCreateSequence(record);
			
				n++;
			
				if ((n%10000) == 0) {
					conn.commit();
					reportMemory(n);
				}
			}
			
			iterator.close();
			
			conn.commit();
			
			conn.setAutoCommit(savedAutoCommit);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An SQL exception occurred when processing a file", conn, this);
		}
	}
	
	public Sequence findOrCreateSequence(SAMRecord record) throws ArcturusDatabaseException {
		String readname = record.getReadName();
		
		int maskedFlags = Utility.maskReadFlags(record.getFlags());
		
		byte[] dna = record.getReadBases();
		
		byte[] quality = record.getBaseQualities();
		
		if (record.getReadNegativeStrandFlag()) {
			dna = Utility.reverseComplement(dna);
			quality = Utility.reverseQuality(quality);
		}
		
		/*
		Read read = adb.getReadByNameAndFlags(readname, maskedFlags);
		
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
				read = new Read(readname, maskedFlags);
		
			read = adb.putRead(read);
		}
		*/
		
		Read read = new Read(readname, maskedFlags);
		
		Sequence sequence = new Sequence(0, read, dna, quality, 0);
		
		Sequence newSequence = adb.findSequenceByReadnameFlagsAndHash(sequence);
		
		return newSequence;
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
			ArcturusDatabase adb = uk.ac.sanger.arcturus.utils.Utility.getTestDatabase();
			
			BAMReadLoader loader = new BAMReadLoader(adb);

			SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);

			SAMFileReader reader = new SAMFileReader(file);
		
			loader.processFile(reader);
		}
		catch (ArcturusDatabaseException e) {
			e.printStackTrace();
			System.exit(1);
		}
		
		System.exit(0);
	}
}
