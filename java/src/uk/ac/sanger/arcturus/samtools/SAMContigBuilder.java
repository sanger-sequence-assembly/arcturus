package uk.ac.sanger.arcturus.samtools;

import java.util.*;
import java.text.DecimalFormat;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

import net.sf.samtools.*;
import net.sf.samtools.SAMRecord.SAMTagAndValue;
import net.sf.samtools.util.CloseableIterator;

public class SAMContigBuilder {
	protected ArcturusDatabase adb = null;
	protected BAMReadLoader brl = null;
	private boolean diagnostics = true;
	private DecimalFormat format = null;
	protected long t0;
	
	private boolean scb_testing = false;
	
	public SAMContigBuilder(ArcturusDatabase adb, BAMReadLoader brl) {
		this.adb = adb;
		this.brl = brl;
	}

	public void setRuntimeDiagnostics() {
	    diagnostics = false;
		format = new DecimalFormat();
	}
	
	/**
	 * @param contig
	 * @param samTagType
	 * @param record
	 * @param gapTagString
	 * holds REPT|5|1|Tag inserted at position 25 at start of AAAA
	 * @throws ArcturusDatabaseException
	 * 
	 */
	public void addTagToContig (Contig contig, String samTagType, String gapTagString, int sequence_id, char strand)  throws ArcturusDatabaseException{
		
		char samType = 'Z';
		
		if (gapTagString.length() < 10) {
			 throw new ArcturusDatabaseException("addTagToContig: tag " + gapTagString + " looks too short so has not been added");
		}
		else
		{
			String gapTagType = gapTagString.substring(0,4);
			reportProgress("\t\t\taddTagToContig: read gapTypeTag as " + gapTagType);
		
			int startOfNumeric = 5;
			int endOfNumeric = gapTagString.lastIndexOf('|');
			
			String numberString = gapTagString.substring(startOfNumeric, endOfNumeric);
			
			int endOfStart = numberString.indexOf('|');
			String startAsString = numberString.substring(0, endOfStart);
			int start = Integer.parseInt(startAsString);
		
			String lengthAsString = numberString.substring(endOfStart+1, numberString.length());
			int length = Integer.parseInt(lengthAsString);
			
			String comment = gapTagString.substring(endOfNumeric + 1, gapTagString.length());
						
			Tag tag = new Tag(samTagType, samType, gapTagType, start, length, comment, sequence_id, strand );
			contig.addTag(tag);
			
			reportProgress("\t\taddTagToContig: tag stored and retrieved as: " + tag.toSAMString());
		}
	}
	
	private boolean isValidGapTagType(String gapTagType){
		return ((gapTagType.equals("Zc")) || (gapTagType.equals("Zs")) ||(gapTagType.equals("FS")));
	}
	
	private class GAPTag {
		/**
		 * holds the Sanger part of the tag e.g. REPT|5|1|Tag inserted at postion 25 at start of AAAA
		 */
		String gapTag = "";
		
		String getGapTag() {
			return(gapTag);
		}
		
		public String toString() {
			return (getGapTag());
		}
	}
	
	/**
	 * @param contig
	 * @param record
	 * Sequence (consensus) tag looks like Zs:Z:REPT|5|1|Tag inserted at position 25 at start of AAAA 
	 * @return
	 * Contig tag looks like Zc:Z:POLY|31|42|weird Ns
	 */
	public void addTagsToContig(Contig contig, SAMRecord record)  throws ArcturusDatabaseException  {
		reportProgress("\taddTagsToContig: adding tags for contig " + contig.getName() + " from SAMRecord " + record.getReadName());
		
		String gapTagType = null;
		String gapTagString = null;
		short count = 1;
		
		Sequence sequence = brl.findOrCreateSequence(record);
		if (sequence == null) 
			 throw new ArcturusDatabaseException("addTagToContig: cannot find data for sequence for SAMRecord =" + record.getReadName());	 
		int sequence_id = sequence.getID();
		char strand =  record.getReadNegativeStrandFlag() ? 'R': 'F';

		ArrayList<SAMRecord.SAMTagAndValue> tagList= (ArrayList<SAMRecord.SAMTagAndValue>) record.getAttributes();
		int tagCount = tagList.size();
		
		reportProgress("addTagsToContig: found " + tagCount + " tags from tag list " + tagList.toString());
		
		while (count < tagCount ) {	
			SAMRecord.SAMTagAndValue samTag = tagList.get(count);

			gapTagType = samTag.tag;
							
			if (isValidGapTagType(gapTagType)){
				gapTagString = (String) samTag.value;
				
				if (gapTagString != null) {
					reportProgress("\taddTagsToContig: adding tag " + count + " of type " + gapTagType + " holding " + gapTagString);		
					addTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
				}
				else {
					throw new ArcturusDatabaseException("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
				}		
				count++;
			}
			else
			{
				count++;
				//throw new ArcturusDatabaseException("addTagsToContig: unexpectedly found null tag or invalid tag (not Zc or Zs or FS) at position " + count + " for contig" + contig.getName() + " from SAMRecord " + record.getReadName());
			}

		}

		if (diagnostics)
			t0 = System.currentTimeMillis();

		if (diagnostics && (count%10000) == 0) {
			long dt = System.currentTimeMillis() - t0;
			Arcturus.logFine("addTagsToContig: " + format.format(count) + " reads; " +
					format.format(dt) + " ms; memory " + memoryUsage());
		}

		if (diagnostics) {
			long dt = System.currentTimeMillis() - t0;
			Arcturus.logFine("addTagsToContig: " + count + " " + dt + " ms");
		}
	}
	
	public void addMappingsToContig(Contig contig,SAMFileReader reader) throws ArcturusDatabaseException {
		
		reportProgress("addMappingsToContig: working with contig " + contig.getName() + " which has " + contig.getParentContigCount() + " parents and " + contig.getReadCount() + " reads.");
		
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
	 	    
	 		System.out.println("\taddMappingsToContig: adding sequence for SAMRecord " + record.getReadName());
	 		SequenceToContigMapping mapping = buildSequenceToContigMapping(record,contig);
	 	    M.add(mapping);
	 	   
	 	    count++;
	 	    
	 	    if (diagnostics && (count%10000) == 0) {
	 	    	long dt = System.currentTimeMillis() - t0;
	 	    	Arcturus.logFine("addMappingsToContig: before adding tags" + format.format(count) + " reads; " +
	 	    			format.format(dt) + " ms; memory " + memoryUsage());
	 	    }
	 	    
	 	   addTagsToContig(contig, record);
	 	   
	 	  if (diagnostics && (count%10000) == 0) {
	 	    	long dt = System.currentTimeMillis() - t0;
	 	    	Arcturus.logFine("addMappingsToContig: after adding tags" + format.format(count) + " reads; " +
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
	    
		reportProgress("\tbuildSequenceToContigMapping: working with SAMRecord " + record.getReadName() + " and contig " + contig.getName());
		
		String cigar = record.getCigarString();
		int contigStartPosition = record.getAlignmentStart();
        int span = record.getAlignmentEnd() - contigStartPosition + 1;
        
	    
		
		Sequence sequence = brl.findOrCreateSequence(record);
		if (sequence == null) 
			 throw new ArcturusDatabaseException("buildSequenceToContigMapping: cannot find data for sequence for SAMRecord =" + record.getReadName());	 
		
		//sequence.setDNA(null);
		
		int mapping_quality = record.getMappingQuality();
		reportProgress("\t\tbuildSequenceToContigMapping: got mapping quality of " + mapping_quality + " from record " + record.getReadName());
		
	   
 	    SAMReadGroupRecord readGroup = record.getReadGroup();
 	    String readGroupIDvalue = readGroup.getId();
 	    reportProgress("\taddMappingsToContig: adding ID " + readGroupIDvalue + " for read group " + readGroup + " for contig " + contig.getName());
		
		CanonicalMapping mapping = new CanonicalMapping(0,span,span,cigar, mapping_quality, readGroupIDvalue);
		CanonicalMapping cached = adb.findOrCreateCanonicalMapping(mapping);
		
		int stored_quality = cached.getMappingQuality();
		
		reportProgress("\t\tbuildSequenceToContigMapping: got mapping quality of " + stored_quality + " from database\n");
		
		Direction direction = record.getReadNegativeStrandFlag() ? Direction.REVERSE : Direction.FORWARD;
		
		return new SequenceToContigMapping(sequence,contig,cached,contigStartPosition,1,direction);
	}

    protected void reportProgress(String message) {
    	if (scb_testing) {
    		System.out.println(message);
    		Arcturus.logInfo(message);
    	}
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
