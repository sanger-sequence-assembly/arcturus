package uk.ac.sanger.arcturus.utils;

import java.io.File;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import net.sf.samtools.SAMFileReader;
import net.sf.samtools.SAMRecord;
import net.sf.samtools.util.CloseableIterator;

public class BAMReadLoader {
	private ArcturusDatabase adb;
	
	public BAMReadLoader() throws ArcturusDatabaseException {
		adb = Utility.getTestDatabase();
		
		adb.setCacheing(ArcturusDatabase.READ, false);
		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);
	}
	
	public void processFile(File file) throws ArcturusDatabaseException {
		SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);

		SAMFileReader reader = new SAMFileReader(file);

		CloseableIterator<SAMRecord> iterator = reader.iterator();

		int n = 0;
		
		while (iterator.hasNext()) {
			SAMRecord record = iterator.next();
			
			processRecord(record);
			
			n++;
			
			if ((n%10000) == 0)
				reportMemory(n);
		}
	}
	
	private static final int FLAGS_MASK = 128 + 64 + 1;
	
	private void processRecord(SAMRecord record) throws ArcturusDatabaseException {
		String readname = record.getReadName();
		
		int flags = record.getFlags() & FLAGS_MASK;
		
		//System.out.println("Read " + readname + ", flags " + flags);
		
		byte[] dna = record.getReadBases();
		
		byte[] quality = record.getBaseQualities();
		
		Read read = new Read(readname, flags);
		
		Read newRead = adb.findOrCreateRead(read);
		
		Sequence sequence = new Sequence(0, newRead, dna, quality, 0);
		
		Sequence newSequence = adb.findOrCreateSequence(sequence);
		
		//System.out.println("\tStored with ID=" + newRead.getID() +
		//		", sequence ID=" + newSequence.getID());
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
		
		System.err.println("Reads: " + n + " ; Memory used " + usedMemory + " kb, free " + freeMemory +
				" kb, total " + totalMemory + " kb, per read " + perRead);
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
