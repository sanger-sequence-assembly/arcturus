package uk.ac.sanger.arcturus.samtools;

import java.util.*;
import java.text.DecimalFormat;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;

public class SAMContigBuilder {
	protected ArcturusDatabase adb = null;
	protected BAMReadLoader brl = null;
	private boolean diagnostics = false;
	private DecimalFormat format = null;
	protected long t0;
	
	public SAMContigBuilder(ArcturusDatabase adb, BAMReadLoader brl) {
		this.adb = adb;
		this.brl = brl;
	}

	public void setRuntimeDiagnostics() {
	    diagnostics = true;
		format = new DecimalFormat();
	}
	
	public void addMappingsToContig(Contig contig,SAMFileReader reader) throws ArcturusDatabaseException {
		
		reportProgress("addMappingsToContig: working with contig " + contig.getName() + " which has " + contig.getParentContigCount() + " parents and " + contig.getReadCount() + " reads.");
		
		if (contig.getContigToParentMappings() != null)
			return;
		
		reportProgress("addMappingsToContig: adding mappings for contig" + contig.getName());

		String referenceName = contig.getName();
		    	    	
	    CloseableIterator<SAMRecord> iterator = reader.query(referenceName, 0, 0, false);
	 		
	 	Vector<SequenceToContigMapping> M = new Vector<SequenceToContigMapping>();
	 		
	 	if (diagnostics)
	 		t0 = System.currentTimeMillis();
	 	
	 	int count = 0;
	    while (iterator.hasNext()) {
	 	    SAMRecord record = iterator.next();
	 		reportProgress("\taddMappingsToContig: adding sequence for SAMRecord " + record.getReadName());
	 		SequenceToContigMapping mapping = buildSequenceToContigMapping(record,contig);
	 	    M.add(mapping);
	 	    
	 	    count++;
	 	    
	 	    if (diagnostics && (count%10000) == 0) {
	 	    	long dt = System.currentTimeMillis() - t0;
	 	    	Arcturus.logFine("addMappingsToContig: " + format.format(count) + " reads; " +
	 	    			format.format(dt) + " ms; memory " + memoryUsage());
	 	    }
	    }

	    if (diagnostics) {
	        long dt = System.currentTimeMillis() - t0;
 	        Arcturus.logFine("addMappingsToContig: " + count + " " + dt + " ms");
	    }
	    
	    iterator.close();
	 		
	    contig.setSequenceToContigMappings(M.toArray(new SequenceToContigMapping[0]));
    }
	
	private byte[] intToByteArray(int value) {
        return new byte[] {
                (byte)(value >>> 24),
                (byte)(value >>> 16),
                (byte)(value >>> 8),
                (byte)value};
	}
	
	private int byteArrayToInt(byte [] b) {
        return (b[0] << 24)
                + ((b[1] & 0xFF) << 16)
                + ((b[2] & 0xFF) << 8)
                + (b[3] & 0xFF);
	}

	private SequenceToContigMapping buildSequenceToContigMapping(SAMRecord record, Contig contig) throws ArcturusDatabaseException {	    
	    
		reportProgress("\tbuildSequenceToContigMapping: working with SAMRecord " + record.getReadName() + " and contig " + contig.getName());
		
		String cigar = record.getCigarString();
		int contigStartPosition = record.getAlignmentStart();
        int span = record.getAlignmentEnd() - contigStartPosition + 1;
	    
		CanonicalMapping mapping = new CanonicalMapping(0,span,span,cigar);
		CanonicalMapping cached = adb.findOrCreateCanonicalMapping(mapping);

		Sequence sequence = brl.findOrCreateSequence(record);
		if (sequence == null) 
			 throw new ArcturusDatabaseException("buildSequenceToContigMapping: cannot find data for sequence for SAMRecord =" + record.getReadName());	 
		
		//sequence.setDNA(null);
		
		int quality = record.getMappingQuality();
		reportProgress("\t\tbuildSequenceToContigMapping: got quality of " + quality + " from record " + record.getReadName());
		sequence.setQuality(intToByteArray(quality));
		
		int saved_quality = (byteArrayToInt(sequence.getQuality()));
		reportProgress("\t\tbuildSequenceToContigMapping: got quality of " + saved_quality + " from Java object");
		
		Sequence storedSequence = adb.findOrCreateSequence(sequence);
		//Sequence storedSequence = adb.putSequence(sequence);
		int stored_quality = (byteArrayToInt(storedSequence.getQuality()));
		reportProgress("\t\tbuildSequenceToContigMapping: got quality of " + stored_quality + " from database\n");
		
		Direction direction = record.getReadNegativeStrandFlag() ? Direction.REVERSE : Direction.FORWARD;
		
		return new SequenceToContigMapping(sequence,contig,cached,contigStartPosition,1,direction);
	}

    protected void reportProgress(String message) {
    	System.out.println(message);
    	Arcturus.logInfo(message);
	}
	   
    private String memoryUsage() {
    	Runtime rt = Runtime.getRuntime();
    	
    	long totalMemory = rt.totalMemory()/1024;
    	long freeMemory = rt.freeMemory()/1024;
    	
    	long usedMemory = totalMemory - freeMemory;
    	
    	return "used = " + format.format(usedMemory) + " kb, free = " +
    		format.format(freeMemory) + " kb, total = " +
    		format.format(totalMemory) + " kb";
    }
	
}
