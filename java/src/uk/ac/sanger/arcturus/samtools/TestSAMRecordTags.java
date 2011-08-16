package uk.ac.sanger.arcturus.samtools;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.Vector;

import javax.naming.NamingException;

import net.sf.samtools.SAMRecord;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Tag;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestSAMRecordTags {

	/**
	 * @param contig
	 * @param samTagType
	 * @param record
	 * @param gapTagString
	 * holds REPT|5|1|Tag inserted at position 25 at start of AAAA
	 * @throws ArcturusDatabaseException
	 * 
	 */
	
	protected static void reportProgress(String message) {
	    	
	    System.out.println(message);
	    	
 	}
	 
 	public static void addTagToContig (Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
		
		char samType = 'Z';
		
		String gapTagType = gapTagString.substring(0,4);
		reportProgress("\t\t\taddTagToContig: read gapTypeTag as " + gapTagType);
	
		int startOfNumeric = 5;
		int endOfNumeric = gapTagString.lastIndexOf('|');
		reportProgress("\t\t\taddTagToContig: startOfNumeric = " + startOfNumeric + " end = " + endOfNumeric);
		
		String numberString = gapTagString.substring(startOfNumeric, endOfNumeric);
		
		//numberString holds 5|1
		reportProgress("\t\t\taddTagToContig: built numberString as " + numberString);
		
		int endOfStart = numberString.indexOf('|');
		String startAsString = numberString.substring(0, endOfStart);
		reportProgress("\t\t\taddTagToContig: read startAsString as " + startAsString);
		int start = Integer.parseInt(startAsString);
	
		String lengthAsString = numberString.substring(endOfStart+1, numberString.length());
		reportProgress("\t\t\taddTagToContig: read lengthAsString as " + lengthAsString);
		int length = Integer.parseInt(lengthAsString);
		
		String comment = gapTagString.substring(endOfNumeric + 1, gapTagString.length());
		reportProgress("\t\t\taddTagToContig: read comment as " + comment);
					
		Tag tag = new Tag(samTagType, samType, gapTagType, start, length, comment, sequence_id, strand );
		contig.addTag(tag);
		
		reportProgress("\t\taddTagToContig: tag stored and retrieved as: " + tag.toSAMString());
		
	}
 	
 	private boolean isValidGapTagType(String gapTagType){
		return ((gapTagType.equals("Zc")) || (gapTagType.equals("Zs"))||(gapTagType.equals("FS")));
	}
	
	/**
	 * @param contig
	 * @param record
	 * Sequence (consensus) tag looks like Zs:Z:REPT|5|1|Tag inserted at position 25 at start of AAAA 
	 * @return
	 * Contig tag looks like Zc:Z:POLY|31|42|weird Ns
	 */
	public void addTagsToContig(Contig contig, SAMRecord record)  throws ArcturusDatabaseException  {
		//reportProgress("\taddTagsToContig: adding tags for contig " + contig.getName() + " from SAMRecord " + record.getReadName());
		
		String gapTagType = null;
		String gapTagString = null;
		short count = 1;
		
		/*
		Sequence sequence = brl.findOrCreateSequence(record);
		if (sequence == null) 
			 throw new ArcturusDatabaseException("addTagToContig: cannot find data for sequence for SAMRecord =" + record.getReadName());	 
		int sequence_id = sequence.getID();
		*/
		int sequence_id = 74294853;
		char strand =  record.getReadNegativeStrandFlag() ? 'R': 'F';

		ArrayList<SAMRecord.SAMTagAndValue> tagList= (ArrayList<SAMRecord.SAMTagAndValue>) record.getAttributes();
		int tagCount = tagList.size();
		
		reportProgress("addTagsToContig: found " + tagCount + " tags: ");
		
		while (count < tagCount ) {	
			SAMRecord.SAMTagAndValue samTag = tagList.get(count);
			
			gapTagType = samTag.tag;
						
			if (isValidGapTagType(gapTagType)){
				gapTagString = record.getStringAttribute(gapTagType);
				
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
				throw new ArcturusDatabaseException("addTagsToContig: unexpectedly found null tag or invalid tag (not Zc or Zs or FS) at position " + count + " for contig" + contig.getName() + " from SAMRecord " + record.getReadName());
			}

		}
		
	}
	
static String printTagSet(Vector<Tag> tagSet) {
		
	String text = "";
	
	if (tagSet != null) {
		Iterator<Tag> iterator = tagSet.iterator();
		
		Tag tag = null;
		
		while (iterator.hasNext()) {
			tag = iterator.next();
			text = text + tag.toSAMString();
		}
	}
	else {
		text = "no tags found for this tag set.";
	}
	return text;
	}
	
	/**
	 * @param args
	 */
	public static void main(String[] args) {

		// set up a contig with a tag
		
		String samTagType = "Fs";
		String gapTagString = "REPT|5|1|Tag inserted at position 25 at start of AAAA";
		Contig contig = new Contig();
		
		addTagToContig(contig, samTagType, gapTagString, 74294504, 'F');
		
		Vector<Tag> tags = contig.getTags();
		Iterator <Tag> iterator = tags.iterator();
		
		reportProgress("Checking tags for contig: ");
		while (iterator.hasNext() ) {
			reportProgress((iterator.next()).toSAMString() + "\n");
		}
		
		reportProgress("Printing this tag set: " + printTagSet(tags));
		
		reportProgress("Printing an empty tag set: " + printTagSet(null));
		
		// now try to get it back from the database
		String direction = "Forwards";
		//String testStrand = direction.substring(1,1);
		String testStrand = "";
		testStrand = direction.substring(0,1);
		//String testStrand  = direction.charAt(1);
		
		reportProgress("Test strand is "+ testStrand);
		
		String tagString = "";
		String strand = "F";
		int seq_id = 74294853;
		
		ArcturusInstance ai = null;
		try {
			ai = ArcturusInstance.getInstance("test");
		} catch (NamingException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		ArcturusDatabase adb = null;
		try {
			adb = ai.findArcturusDatabase("TESTCHURIS");
		} catch (ArcturusDatabaseException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		
		Contig savedContig = null;
		
		try {
			savedContig = adb.getContigByID(2012);
		} catch (ArcturusDatabaseException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
	
		Vector<Tag> tagList = null;
		
		Sequence seq = null;
		try {
			seq = adb.getSequenceBySequenceID(seq_id);
		} catch (ArcturusDatabaseException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		
		try {
			adb.loadTagsForSequence(seq);
			reportProgress("Tags retrieved successfully");
			
			tagList = seq.getTags();
			if (tagList !=null) {
				Iterator<Tag> search_iterator = tagList.iterator();	
				
				
				while (search_iterator.hasNext()) {
					tagString = tagString + (search_iterator.next()).toSAMString() + " ";
				}
			}
		}
		catch (ArcturusDatabaseException e){
			Arcturus.logSevere("writeAlignment: unable to find tags for contig "+ savedContig.getName());
		}
		
		reportProgress("Printing the retrieved tag set: " + printTagSet(tagList));
		
	}

}
