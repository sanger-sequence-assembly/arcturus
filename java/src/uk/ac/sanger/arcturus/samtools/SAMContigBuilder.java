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
		if (contig.getContigToParentMappings() != null)
			return;
		
		String referenceName = contig.getName();
		    	    	
	    CloseableIterator<SAMRecord> iterator = reader.query(referenceName, 0, 0, false);
	 		
	 	Vector<SequenceToContigMapping> M = new Vector<SequenceToContigMapping>();
	 		
	 	if (diagnostics)
	 		t0 = System.currentTimeMillis();
	 	
	 	int count = 0;
	    while (iterator.hasNext()) {
	 	    SAMRecord record = iterator.next();
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
	  
	
	private SequenceToContigMapping buildSequenceToContigMapping(SAMRecord record, Contig contig) throws ArcturusDatabaseException {	    
	    String cigar = record.getCigarString();
		int contigStartPosition = record.getAlignmentStart();
        int span = record.getAlignmentEnd() - contigStartPosition + 1;
	    
		CanonicalMapping mapping = new CanonicalMapping(0,span,span,cigar);
		CanonicalMapping cached = adb.findOrCreateCanonicalMapping(mapping);

		Sequence sequence = brl.findOrCreateSequence(record);

		sequence.setDNA(null);
		sequence.setQuality(null);

		Direction direction = record.getReadNegativeStrandFlag() ? Direction.REVERSE : Direction.FORWARD;
		
		return new SequenceToContigMapping(sequence,contig,cached,contigStartPosition,1,direction);
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
