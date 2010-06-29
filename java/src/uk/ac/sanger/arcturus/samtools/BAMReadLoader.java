package uk.ac.sanger.arcturus.samtools;

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
	private TraceServerClient traceServerClient;
	private ReadNameFilter readNameFilter;
	
	private int tsLookups;
	private int tsFailures;
	
	private long T0;

	public BAMReadLoader(ArcturusDatabase adb, TraceServerClient traceServerClient, ReadNameFilter readNameFilter) throws ArcturusDatabaseException {
		this.adb = adb;
		this.traceServerClient = traceServerClient;
		this.readNameFilter = readNameFilter;
		
		prepareLoader();
	}
	
	public BAMReadLoader(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this(adb, null, null);
	}
	
	private void prepareLoader() {		
		adb.setCacheing(ArcturusDatabase.READ, false);
		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);
		adb.setCacheing(ArcturusDatabase.TEMPLATE, false);
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
				
		Read read = adb.getReadByNameAndFlags(readname, maskedFlags);
		
		if (read == null && traceServerClient != null && readNameFilter != null
				&& readNameFilter.accept(readname)) {
			Sequence storedSequence = traceServerClient.fetchRead(readname);
				
			tsLookups++;
				
			if (storedSequence != null) {
				read = storedSequence.getRead();
				adb.findSequenceByReadnameFlagsAndHash(storedSequence);
			} else
				tsFailures++;
		}
		
		if (read == null)
			read = new Read(readname, maskedFlags);
		
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
}
