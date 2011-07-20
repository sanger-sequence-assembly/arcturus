package uk.ac.sanger.arcturus.samtools;

import java.util.Iterator;
import java.util.Vector;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Tag;
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
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		
		String samTagType = "Zs";
		String gapTagString = "REPT|5|1|Tag inserted at position 25 at start of AAAA";
		Contig contig = new Contig();
		
		addTagToContig(contig, samTagType, gapTagString, 74294504, 'F');
		
		Vector<Tag> tags = contig.getTags();
		Iterator <Tag> iterator = tags.iterator();
		
		reportProgress("Checking tags for contig: ");
		while (iterator.hasNext() ) {
			reportProgress((iterator.next()).toSAMString() + "\n");
		}
		
	}

}
