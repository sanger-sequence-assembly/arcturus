package uk.ac.sanger.arcturus.samtools;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
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
import uk.ac.sanger.arcturus.jdbc.ContigManager;

public class TestSAMRecordTags {
	

	static char fieldSeparator = ';';
	static char recordSeparator = '|';

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
		
		//reportProgress("\t\t\taddPTTagToContig: read next record seperator as " + nextRS + ", bar4 as " + fs4  + " read gapTypeTag as " + gapTagType);
		
		if (nextRS < 0 ) {
			tagEnd = stringEnd + 1;
		}
		else {
			tagEnd = thisRS;
		}
		String thisTagString = gapTagString.substring(fs4 + 1, tagEnd);
		
		//reportProgress("\t\t\taddPTTagToContig: read start as " + start + ", end as " + end + ",comment as " + thisTagString);
		
		Tag newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
		contig.addTag(newTag);
		
		//reportProgress("\t\taddPTTagToContig: tag stored and retrieved from Java object as: " + newTag.toPTSAMString());
		
		while (nextRS >fs4) {
			fs1 = gapTagString.indexOf(fieldSeparator, nextRS+1);
			fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
			fs3 = gapTagString.indexOf(fieldSeparator, fs2+1);
			fs4 = gapTagString.indexOf(fieldSeparator, fs3+1);
			
			gapTagType = gapTagString.substring(fs3 + 1, fs4); 
			
			//reportProgress("\t\t\taddPTTagToContig: field separator1=" + fs1 + " field separator2=" + fs2 + " field separator3=" + fs3 + " field separator4=" + fs4 + " read gapTypeTag as " + gapTagType );
			
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
			
			//reportProgress("\t\t\taddPTTagToContig: read start as " + start + ", end as " + end + ",comment as " + thisTagString + ", nextRS as " + nextRS);
			
			newTag = new Tag(samTagType, samType, gapTagType, start, end, thisTagString, sequence_id, strand );
			contig.addTag(newTag);
			
			reportProgress("\t\taddPTTagToContig: tag stored and retrieved from Java object as: " + newTag.toPTSAMString());
		}
		
	}
 	/**
	 * @param contig
	 * @param record
	 * Sequence (consensus) tag (was Zc) looks like a fake read with flags 768 or 784 and an CT tag
	 * *	768	Contig1	38	255	17M	*	0	0	CATWTTCACATTASCAA	*	CT:Z:?|COMM|Now has a direction as well as a tag type and comment
	 * No start/end or length
	 **/
 	
 	public static void addCTTagToContig(Contig contig, String samTagType, String gapTagString, int sequence_id, char strand){
 		
		char samType = 'Z';
		int fs1 = gapTagString.indexOf(fieldSeparator);
		int fs2 = gapTagString.indexOf(fieldSeparator, fs1+1);
		
		int stringEnd = gapTagString.length();
		int tagEnd = stringEnd;
		int start = 15;
		int length = 25;
		
		String gapTagType = "";
		
		strand = gapTagString.charAt(0);
		
		gapTagType = gapTagString.substring(fs1 + 1,fs2); 
		
		reportProgress("\t\t\taddCTTagToContig: read bar1 as " + fs1  + " read bar2 as " + fs2  + " read gapTypeTag as " + gapTagType);
		
		String thisTagString = gapTagString.substring(fs2 + 1, stringEnd);
		
		reportProgress("\t\t\taddCTTagToContig: read strand as " + strand + ",comment as " + thisTagString);
		
		Tag newTag = new Tag(samTagType, samType, gapTagType, start, length, thisTagString, sequence_id, strand );
		contig.addTag(newTag);
		
		reportProgress("\t\taddCTTagToContig: tag stored and retrieved from Java object as: " + newTag.toCTSAMString());
		
		reportProgress("\t\taddCTTagToContig: length retrieved from Java object as: " + newTag.getLength());
 	}
 	
 	private static boolean isValidGapTagType(String gapTagType){
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
					else if (gapTagType.equals("CT")){
						addCTTagToContig(contig, gapTagType, gapTagString, sequence_id, strand);	
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
		String singleGapTagString = "26;32;-;COMM;gff3src=unique";
		String invalidSingleGapTagString = "banana;32;-;9999;gff3src=unique";
		
		String multiGapTagString = "119;128;-;COMM;gff3src=minus-one|" +
				"105;113;+;COMM;gff3src=zero|" +
				"39;99;.;HAF3;gff3src=one|" +
				"84;90;+;PSHP;gff3src=two|" +
				"65;65;+;SRMr;gff3src=three with a semi-colon ; in the middle of the comment|" +
				"55;55;+;SRMr;gff3src=four with an escaped bar &#124; in the middle of the comment|" +
				"31;31;;R454;gff3src=five with an empty direction field|" +
				"25;25;+;EMPT;|" +
				"13;22;?;Frpr;gff3src=six|" +
				"3;3;+;CRMr;gff3src=seven";
		String invalidMultiGapTagString = "5;5;?;REPT;Tag inserted at postion 25 at start of AAAA|28;28;?;COMM;Tag inserted at position 48 as a comment at the start of AAAAAA";
				//"giraffe;128;-;0.543;gff3src=this one is invalid|" +
				//"105;113;+;COMM;gff3src=this one is OK";
				
	
		String CTTGapTagString = ".;COMM;Note=Looks like a problem here with * as read group and sequence :)";
		String invalidCTTGapTagString = "My tag has no separator";
		
		Contig contig = new Contig();
		int count = 1;
		
		reportProgress("\nTest 1a: single PT tag \n"+ singleGapTagString +"\n");
		
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
		
		reportProgress("\nTest 1b: invalid single PT tag \n"+ singleGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			
			if (invalidSingleGapTagString != null) {
				try {
				reportProgress("\taddTagsToContig: adding tag " + count + " of type " + gapTagType + " holding " + invalidSingleGapTagString);		
				addPTTagToContig(contig, gapTagType, invalidSingleGapTagString, 74294504, 'F');	
				}
				catch (Exception e) {
					System.out.println("ERROR: Cannot parse tag " + invalidSingleGapTagString + "because of the error reported below: this tag will NOT be stored\n");
				}
			}
			else {
				reportProgress("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
			}		
			count++;
		}
		else {
			reportProgress("don't need to process " + gapTagType);
		}
		
		reportProgress("\nTest 2a: multi PT tag\n"+ multiGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			if (multiGapTagString != null) {
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
		
		reportProgress("\nTest 2b: invalid multi PT tag\n"+ multiGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			
			if (invalidMultiGapTagString != null) {
				try {
					reportProgress("\taddTagsToContig: adding multitag " + count + " of type " + gapTagType + " holding " + invalidMultiGapTagString);		
					addPTTagToContig(contig, gapTagType, invalidMultiGapTagString, 74294504, 'F');	
				}
				catch (Exception e) {
					System.out.println("ERROR: Cannot parse tag " + invalidMultiGapTagString + "because of the exception shown below: this tag will NOT be stored\n");
					System.out.println(e.toString());
				}
			}
			else {
				reportProgress("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
			}		
			count++;
		}
		else {
			reportProgress("don't need to process " + gapTagType);
		}
		
		gapTagType = "CT";
		reportProgress("\nTest 3a: CT tag\n"+ CTTGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			
			if (CTTGapTagString != null) {
				reportProgress("\taddTagsToContig: adding CT tag " + count + " of type " + gapTagType + " holding " + CTTGapTagString);		
				addCTTagToContig(contig, gapTagType, CTTGapTagString, 74294504, 'F');	
			}
			else {
				reportProgress("addTagsToContig: unexpectedly found null tag information at position " + count + " for tag type " + gapTagType);
			}		
			count++;
		}
		else {
			reportProgress("don't need to process " + gapTagType);
		}
		
		reportProgress("\nTest 3b: invalid CT tag\n"+ invalidCTTGapTagString +"\n");
		if (isValidGapTagType(gapTagType)){
			
			if (invalidCTTGapTagString != null) {
				try {
					reportProgress("\taddTagsToContig: adding CT tag " + count + " of type " + gapTagType + " holding " + invalidCTTGapTagString);		
					addCTTagToContig(contig, gapTagType, invalidCTTGapTagString, 74294504, 'F');	
				}
				catch (Exception e) {
					System.out.println("ERROR: Cannot parse tag " + invalidSingleGapTagString + ": this tag will NOT be stored\n");
				}
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
		
		if (tags != null) {
			reportProgress("\nTest 4: Printing this tag set with " + tags.size() + " elements: \n" + adb.printTagSet(tags));
			
			Iterator <Tag> iterator = tags.iterator();
			
			while (iterator.hasNext() ){
				Tag tag = iterator.next();
				reportProgress("\t\t\tprinting tag length: " + tag.getLength());
			}
		}
		else {
			reportProgress("no tags to process!");
		}
		reportProgress("\nTest 5: Printing an empty tag set: " + adb.printTagSet(null));
		
		// now try to get it back from the database
		String direction = "Forwards";
		//String testStrand = direction.substring(1,1);
		String testStrand = "";
		testStrand = direction.substring(0,1);
		//String testStrand  = direction.charAt(1);
		
		reportProgress("\nTest 6: store the tags and contig in the database");
		
		try {
			adb.putContig(contig);
		} catch (ArcturusDatabaseException e2) {
			// TODO Auto-generated catch block
			e2.printStackTrace();
		}
		
		reportProgress("\nTest 7: really getting these tags from the database");
		
		String tagString = "";
		String strand = "F";
		int seq_id = 74294853;
		
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
			
		}
		catch (ArcturusDatabaseException e){
			Arcturus.logSevere("writeAlignment: unable to find tags for contig "+ savedContig.getName());
		}
		
		reportProgress("\nTest 8: printing the retrieved tag set: " + adb.printTagSet(tagList));
		
		reportProgress("\nTest 9: printing the first tag " + tagList.firstElement().toSAMString());
		
		reportProgress("TESTS complete");
	}
	
}
