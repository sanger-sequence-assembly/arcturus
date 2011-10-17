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
	 
	public static void addZTagToContig (Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
		
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
	 * PT:Z:REPT|5|5|Tag inserted at position 25 at start of AAAA 
	 * 
	 * Note that the third | separated field is the END not the LENGTH so this is a one position flag not a five position flag
	 * Note that the fourth | separated field is now the direction which can be +/-/?
	 * Multiple tags are merged into a flattened list
	 * PT:Z:REPT|5|5|Tag inserted at position 25 at start of AAAA|COMM|25|28
	 * 
	 * @return
	 */
	
 	public static void addPTTagToContig (Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
		//	String singleGapTagString = "26|32|-|COMM|gff3src=GenBankLifter";
 		
 		char fieldSeparator = '|';
 		char recordSeparator = '|';
 		
		char samType = 'Z';
		int fs1 = gapTagString.indexOf(fieldSeparator);
		int fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
		int fs3 =  gapTagString.indexOf(fieldSeparator, fs2+1);
		int fs4 =  gapTagString.indexOf(fieldSeparator, fs3+1);
		
		// check if there is more..
		// String multiGapTagString = "119|128|-|COMM|gff3src=GenBankLifter|" +
		//"105|113|+|COMM|gff3src=GenBankLifter|"
		
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
		
		reportProgress("\t\t\taddPTTagToContig: read next record seperator as " + nextRS + ", bar4 as " + fs4  + " read gapTypeTag as " + gapTagType);
		
		if (nextRS < 0 ) {
			tagEnd = stringEnd + 1;
		}
		else {
			tagEnd = thisRS;
		}
		String thisTagString = gapTagString.substring(fs4 + 1, tagEnd);
		
		reportProgress("\t\t\taddPTTagToContig: read start as " + start + ", end as " + end + ",comment as " + thisTagString);
		
		Tag newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
		contig.addTag(newTag);
		
		reportProgress("\t\taddPTTagToContig: tag stored and retrieved as: " + newTag.toPTSAMString());
		
		while (nextRS >fs4) {
			fs1 = gapTagString.indexOf(fieldSeparator, nextRS+1);
			fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
			fs3 = gapTagString.indexOf(fieldSeparator, fs2+1);
			fs4 = gapTagString.indexOf(fieldSeparator, fs3+1);
			
			gapTagType = gapTagString.substring(fs3 + 1, fs4); 
			
			reportProgress("\t\t\taddPTTagToContig: field separator1=" + fs1 + " field separator2=" + fs2 + " field separator3=" + fs3 + " field separator4=" + fs4 + " read gapTypeTag as " + gapTagType );
			
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
			
			reportProgress("\t\t\taddPTTagToContig: read start as " + start + ", end as " + end + ",comment as " + thisTagString + ", nextRS as " + nextRS);
			
			newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
			contig.addTag(newTag);
			
			reportProgress("\t\taddPTTagToContig: tag stored and retrieved as: " + newTag.toPTSAMString());
		}
		
	}
 	/**
	 * @param contig
	 * @param record
	 * Sequence (consensus) tag (was Zc) looks like a fake read with flags 768 or 784 and an RT tag
	 * *	768	Contig1	38	255	17M	*	0	0	CATWTTCACATTASCAA	*	RT:Z:COMM|Note=Looks like a problem here;gff3str=.;gff3src=gap4
	 * No start/end or length
	 **/
 	
 	public static void addRTTagToContig(Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
 	}
 	
 	private static boolean isValidGapTagType(String gapTagType){
		return ( (gapTagType.equals("Zc") || gapTagType.equals("Zs") || gapTagType.equals("FS")) || gapTagType.equals("PT") || gapTagType.equals("RT"));
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
					if (gapTagType.equals("PT")){
						addPTTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
					}
					else if (gapTagType.equals("RT")){
						addRTTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
					}
					else if ((gapTagType.equals("Zc"))||(gapTagType.equals("Zs"))) {
						addZTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
					}
				}
				else {
					throw new ArcturusDatabaseException("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
				}		
				count++;
			}
			else
			{
				//throw new ArcturusDatabaseException("addTagsToContig: unexpectedly found null tag or invalid tag (not Zc or Zs or FS) at position " + count + " for contig" + contig.getName() + " from SAMRecord " + record.getReadName());
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
		
		//  CELERA test case for RT 233 292 AS tags
		//  1 @SQ SN:00076.7180000830927  LN:7163
		//  2 @RG ID:4017_2_and_4149_3  SM:unknown  LB:4017_2_and_4149_3
		//  3 IL21_4017:2:85:786:1676 99  00076.7180000830927 1 24  6S70M = 92  173 TTTCAGCATCTCGCTGACAACGGAATCAGTCGATTCCGAAAGCTACGAAATAAACGATCGCACGTTCACTGTTTGC  AAA>A@>A@?@=>??>@<@@>9<>>=<@?::9;<>;:;;=>979=<8<<<>;;<;3<450.9---80;833200/7  AS:i:70 RG:Z:4017_2_and_4149_3
		//  4 IL21_4017:2:85:786:1676 147 00076.7180000830927 92  32  76M = 1 -173  CAATCAACTAGCCATTGGTTAGGTTGCTTCGGTGTTCTTACAGGGAACGGTAGATAGAACTCAACGGGTGCTCAAC  32(//3)/0-1/0729'5=:=;=8=9:9<7-7>>?<67=478;;729;==?<<<?:9:=<?>=?==<>?=?@>???  AS:i:76 RG:Z:4017_2_and_4149_3


		// set up a contig with a single tag
		String gapTagType = "PT";
		String singleGapTagString = "26|32|-|COMM|gff3src=GenBankLifter";
		String multiGapTagString = "119|128|-|COMM|gff3src=GenBankLifter|" +
				"105|113|+|COMM|gff3src=GenBankLifter|" +
				"39|99|.|HAF3|gff3src=MIRA|" +
				"84|90|+|PSHP|gff3src=MIRA|" +
				"65|65|+|SRMr|gff3src=MIRA|" +
				"55|55|+|SRMr|gff3src=MIRA|" +
				"31|31|+|R454|gff3src=MIRA|" +
				"25|25|+|WRMr|gff3src=MIRA|" +
				"13|22|?|Frpr|gff3src=GenBankLifter|" +
				"3|3|+|CRMr|gff3src=MIRA";
		Contig contig = new Contig();
		int count = 1;
		
		reportProgress("\nTest 1: single PT tag \n"+ singleGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			
			if (singleGapTagString != null) {
				reportProgress("\taddTagsToContig: adding tag " + count + " of type " + gapTagType + " holding " + singleGapTagString);		
				addPTTagToContig(contig, gapTagType, singleGapTagString, 74294504, 'F');	
			}
			else {
				reportProgress("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
			}		
			count++;
		}
		else {
			reportProgress("don't need to process " + gapTagType);
		}
		
		reportProgress("\nTest 2: multi PT tag\n"+ multiGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			
			if (singleGapTagString != null) {
				reportProgress("\taddTagsToContig: adding multitag " + count + " of type " + gapTagType + " holding " + multiGapTagString);		
				addPTTagToContig(contig, gapTagType, multiGapTagString, 74294504, 'F');	
			}
			else {
				reportProgress("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
			}		
			count++;
		}
		else {
			reportProgress("don't need to process " + gapTagType);
		}
		
		Vector<Tag> tags = contig.getTags();
		Iterator <Tag> iterator = null;
		
		if (tags != null) {
			iterator = tags.iterator();
			reportProgress("Checking tags for contig: ");
			while (iterator.hasNext() ) {
				reportProgress((iterator.next()).toSAMString() + "\n");
			}
			reportProgress("Printing this tag set: " + printTagSet(tags));
		}
		else {
			reportProgress("no tags to process!");
		}
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
