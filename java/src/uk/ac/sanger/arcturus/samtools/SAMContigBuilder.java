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
	
	private boolean scb_testing = true;

	private char fieldSeparator = ';';
	private char recordSeparator = '|';
	
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
	 
	public void addZTagToContig (Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
		
		char samType = 'Z';
		
		String gapTagType = gapTagString.substring(0,4);
		reportProgress("\t\t\taddZTagToContig: read gapTypeTag as " + gapTagType);
	
		int startOfNumeric = 5;
		int endOfNumeric = gapTagString.lastIndexOf('|');
		reportProgress("\t\t\taddZTagToContig: startOfNumeric = " + startOfNumeric + " end = " + endOfNumeric);
		
		String numberString = gapTagString.substring(startOfNumeric, endOfNumeric);
		
		//numberString holds 5|1
		reportProgress("\t\t\taddZTagToContig: built numberString as " + numberString);
		
		int endOfStart = numberString.indexOf('|');
		String startAsString = numberString.substring(0, endOfStart);
		reportProgress("\t\t\taddZTagToContig: read startAsString as " + startAsString);
		int start = Integer.parseInt(startAsString);
	
		String lengthAsString = numberString.substring(endOfStart+1, numberString.length());
		reportProgress("\t\t\taddZTagToContig: read lengthAsString as " + lengthAsString);
		int length = Integer.parseInt(lengthAsString);
		
		String comment = gapTagString.substring(endOfNumeric + 1, gapTagString.length());
		reportProgress("\t\t\taddZTagToContig: read comment as " + comment);
					
		Tag tag = new Tag(samTagType, samType, gapTagType, start, length, comment, sequence_id, strand );
		contig.addTag(tag);
		
		reportProgress("\t\taddZTagToContig: tag stored and retrieved as: " + tag.toZSAMString());
		
	}
	
	/**
	 * @param contig
	 * @param record
	 * Contig tag (was Zc) now
	 * PT:Z:119;128;-;COMM;gff3src=minus-one
	 * 
	 * Note that the third ; separated field is the END not the LENGTH so this is a one position flag not a five position flag
	 * Note that the fourth ; separated field is now the direction which can be +/-/?
	 * Multiple tags are merged into a flattened list
	 * PT:Z:119;128;-;COMM;gff3src=minus-one|105;113;+;COMM;gff3src=zero|39;99;.;HAF3;gff3src=one
	 * 
	 * @return
	 */
	
 	public void addPTTagToContig (Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){

		char samType = 'Z';
		int fs1 = gapTagString.indexOf(fieldSeparator);
		int fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
		int fs3 =  gapTagString.indexOf(fieldSeparator, fs2+1);
		int fs4 =  gapTagString.indexOf(fieldSeparator, fs3+1);
		
		int nextRS = gapTagString.indexOf( recordSeparator, fs4+1);
		int thisRS = nextRS;
		int stringEnd = gapTagString.length()- 1;
		int tagEnd = stringEnd;
		int start = 0;
		int end = 0;
		
		String gapTagType = "";
		
		strand = gapTagString.charAt(fs3-1);
		start = Integer.parseInt(gapTagString.substring(0, fs1));
		end = Integer.parseInt(gapTagString.substring(fs1+1, fs2));
		
		gapTagType = gapTagString.substring(fs3 + 1, fs4); 
		
		nextRS = gapTagString.indexOf( recordSeparator, fs4+1);
			if (nextRS < 0 ) {
			tagEnd = stringEnd + 1;
		}
		else {
			tagEnd = thisRS;
		}
		String thisTagString = gapTagString.substring(fs4 + 1, tagEnd);
				
		Tag newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
		contig.addTag(newTag);
		
		reportProgress("\t\taddPTTagToContig: tag stored and retrieved from Java object as: " + newTag.toPTSAMString());
		
		while (nextRS >fs4) {
			fs1 = gapTagString.indexOf(fieldSeparator, nextRS+1);
			fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
			fs3 = gapTagString.indexOf(fieldSeparator, fs2+1);
			fs4 = gapTagString.indexOf(fieldSeparator, fs3+1);
			
			gapTagType = gapTagString.substring(fs3 + 1, fs4); 
			
			strand = gapTagString.charAt(fs3-1);
			start = Integer.parseInt(gapTagString.substring(nextRS+1, fs1));
			end = Integer.parseInt(gapTagString.substring(fs1+1, fs2));
			
			thisRS = nextRS;
			nextRS = gapTagString.indexOf( recordSeparator, fs4+1);
			
			if (nextRS < 0 ) {
				tagEnd = stringEnd;
			}
			else {
				tagEnd = nextRS;
			}
			thisTagString = gapTagString.substring(fs4 + 1, tagEnd);
			
			newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
			contig.addTag(newTag);
			
			reportProgress("\t\taddPTTagToContig: tag stored and retrieved from Java object as: " + newTag.toPTSAMString());
		}
		
	}
 	/**
	 * @param contig
	 * @param record
	 * Sequence (consensus) tag (was Zc) looks like a fake read with flags 768 or 784 and an CT tag
	 * *	768	Contig1	38	255	17M	*	0	0	CATWTTCACATTASCAA	*	CT:Z:?;COMM;Now has a direction as well as a tag type and comment
	 * No start/end or length
	 **/
 	
 	public void addCTTagToContig(Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
 		
		char samType = 'Z';
		int fs1 = gapTagString.indexOf(fieldSeparator);
		int fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
		
		int stringEnd = gapTagString.length();
		int tagEnd = stringEnd;
		int start = 0;
		int end = 0;
		
		String gapTagType = "";
		
		strand = gapTagString.charAt(0);
		
		gapTagType = gapTagString.substring(fs1 + 1,fs2); 
			
		String thisTagString = gapTagString.substring(fs2 + 1, stringEnd);
	
		Tag newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
		contig.addTag(newTag);
		
		reportProgress("\t\taddCTTagToContig: tag stored and retrieved from Java object as: " + newTag.toCTSAMString());
 	}
 	
 	private boolean isValidGapTagType(String gapTagType){
		return ( (gapTagType.equals("Zc") || gapTagType.equals("Zs") || gapTagType.equals("FS")) || gapTagType.equals("PT") || gapTagType.equals("CT"));
	}
	
	/**
	 * @param contig
	 * @param record
	 * Contig tag (was Zc) now
	 * PT:Z:REPT|5|5|Tag inserted at position 25 at start of AAAA 
	 * 
	 * Note that the third | separated field is the END not the LENGTH so this is a one position flag not a five position flag
	 * Note that the fourth | separated field is now the direction which can be +/-/?
	 * Multiple tags are merged into a flattened list
	 * PT:Z:REPT|5|5|Tag inserted at position 25 at start of AAAA|COMM|25|28
	 * 
	 * @return
	 */
	public void addTagsToContig(Contig contig, SAMRecord record)  throws ArcturusDatabaseException  {
		//reportProgress("\taddTagsToContig: adding tags for contig " + contig.getName() + " from SAMRecord " + record.getReadName());
		
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
		
		//reportProgress("\t\taddTagsToContig: found " + tagCount + " tags: ");
		
		while (count < tagCount ) {	
			SAMRecord.SAMTagAndValue samTag = tagList.get(count);
			
			gapTagType = samTag.tag;
						
			if (isValidGapTagType(gapTagType)){
				gapTagString = record.getStringAttribute(gapTagType);

				if (gapTagString != null) {
					try {
						reportProgress("\taddTagsToContig: adding tag " + count + " of type " + gapTagType + " holding " + gapTagString);	
						if (gapTagType.equals("PT")){
							addPTTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
						}
						else if (gapTagType.equals("CT")){
							addCTTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
						}
						else if ((gapTagType.equals("Zc"))||(gapTagType.equals("Zs"))) {
							addZTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
						}
					}
					catch (Exception e) {
						System.out.println("ERROR: Cannot parse tag " + gapTagString + ": this tag will NOT be stored\n");
					}
				}
				else {
					throw new ArcturusDatabaseException("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
				}		
				count++;
			}
		}
	}
	
	public void addMappingsToContig(Contig contig,SAMFileReader reader) throws ArcturusDatabaseException {
		
		reportProgress("addMappingsToContig: working with contig " + contig.getName() + " which has " + contig.getParentContigCount() + " parents and " + contig.getReadCount() + " reads.");
		
		if (contig.getContigToParentMappings() != null)
			return;

		String referenceName = contig.getName();
		    	    	
	    CloseableIterator<SAMRecord> iterator = reader.query(referenceName, 0, 0, false);
	 		
	 	Vector<SequenceToContigMapping> seqToContigMappings = new Vector<SequenceToContigMapping>();
	 		
	 	if (diagnostics)
	 		t0 = System.currentTimeMillis();
	 	
	 	int count = 0;
	 	while (iterator.hasNext()) {
	 		SAMRecord record = iterator.next();

	 		System.out.println("\tworking with SAMRecord " + record.getReadName() + " flags " + record.getFlags());
	 		SequenceToContigMapping mapping = buildSequenceToContigMapping(record,contig);

	 		try {
	 			seqToContigMappings.add(mapping);
	 			count ++;
	 		}
	 		catch (NullPointerException e){
	 			System.out.println("addMappingsToContig: adding SeqToContig mappings has returned a null pointer so moving on to the next SAMRecord\n");
	 			count ++;
	 		}
	 		catch (Exception e) {
	 			System.out.println("addMappingsToContig: adding SeqToContig mappings has returned an exception so moving on to the next SAMRecord\n");
	 			count ++;
	 		}
	 		
	 		try {
	 			addTagsToContig(contig, record);

	 			if (diagnostics && (count%10000) == 0) {
	 				long dt = System.currentTimeMillis() - t0;
	 				Arcturus.logFine("addMappingsToContig: before adding tags" + format.format(count) + " reads; " +
	 						format.format(dt) + " ms; memory " + memoryUsage());
	 			}

	 			if (diagnostics && (count%10000) == 0) {
	 				long dt = System.currentTimeMillis() - t0;
	 				Arcturus.logFine("addMappingsToContig: after adding tags" + format.format(count) + " reads; " +
	 						format.format(dt) + " ms; memory " + memoryUsage());
	 			}
	 		}
	 		catch (NullPointerException e){
	 			System.out.println("addMappingsToContig: adding tags has returned a null pointer so moving on to the next SAMRecord\n");
	 		}
	 		catch (ArcturusDatabaseException e) {
	 			System.out.println("addMappingsToContig: adding tags has returned a database exception so moving on to the next SAMRecord\n");
	 		}
	 		catch (Exception e) {
	 			System.out.println("addMappingsToContig: adding tags has returned an exception so moving on to the next SAMRecord\n");
	 		}
	    }

	    if (diagnostics) {
	        long dt = System.currentTimeMillis() - t0;
 	        Arcturus.logFine("addMappingsToContig: " + count + " " + dt + " ms");
	    }
	    
	    iterator.close();
	 		
	    contig.setSequenceToContigMappings(seqToContigMappings.toArray(new SequenceToContigMapping[0]));
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
 	    String readGroupIDvalue = "*";
 	    
 	    if (readGroup != null) {
 	    	readGroupIDvalue = readGroup.getId();
 	    }
 	    
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
    	}
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
