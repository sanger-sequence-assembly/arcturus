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

import uk.ac.sanger.arcturus.jdbc.ArcturusDatabaseImpl;
import uk.ac.sanger.arcturus.jdbc.ContigManager;
import uk.ac.sanger.arcturus.jdbc.SequenceManager;

import uk.ac.sanger.arcturus.samtools.SAMContigBuilder;

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
	
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		
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
		
	    BAMReadLoader brl;
		try {
			brl = new BAMReadLoader(adb);
			SAMContigBuilder contigBuilder = new SAMContigBuilder(adb, brl);
		
		
		
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
		
		Contig contig = new Contig();
		int count = 1;
		
		reportProgress("\nTest 1a: single PT tag \n"+ singleGapTagString +"\n");
		
		if (contigBuilder.isValidGapTagType(gapTagType)){
			
			if (singleGapTagString != null) {
				reportProgress("\taddTagsToContig: adding tag " + count + " of type " + gapTagType + " holding " + singleGapTagString);		
				contigBuilder.addPTTagToContig(contig, gapTagType, singleGapTagString, 74294504, 'F');	
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
		if (contigBuilder.isValidGapTagType(gapTagType)){
			
			if (invalidSingleGapTagString != null) {
				try {
				reportProgress("\taddTagsToContig: adding tag " + count + " of type " + gapTagType + " holding " + invalidSingleGapTagString);		
				contigBuilder.addPTTagToContig(contig, gapTagType, invalidSingleGapTagString, 74294504, 'F');	
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
		if (contigBuilder.isValidGapTagType(gapTagType)){
			if (multiGapTagString != null) {
				reportProgress("\taddTagsToContig: adding multitag " + count + " of type " + gapTagType + " holding " + multiGapTagString);		
				contigBuilder.addPTTagToContig(contig, gapTagType, multiGapTagString, 74294504, 'F');	
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
		if (contigBuilder.isValidGapTagType(gapTagType)){
			
			if (invalidMultiGapTagString != null) {
				try {
					reportProgress("\taddTagsToContig: adding multitag " + count + " of type " + gapTagType + " holding " + invalidMultiGapTagString);		
					contigBuilder.addPTTagToContig(contig, gapTagType, invalidMultiGapTagString, 74294504, 'F');	
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

		String CTTGapTagString = ".;COMM;Note=Looks like a problem here with * as read group and sequence :)";
		String invalidCTTGapTagString = "My tag has no separator";
		
		reportProgress("\nTest 3a: CT tag\n"+ CTTGapTagString +"\n");
		if (contigBuilder.isValidGapTagType(gapTagType)){
			
			if (CTTGapTagString != null) {
				reportProgress("\taddTagsToContig: adding CT tag " + count + " of type " + gapTagType + " holding " + CTTGapTagString);		
				contigBuilder.addCTTagToContig(contig, gapTagType, CTTGapTagString, 74294504, 67, 5);	
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
		if (contigBuilder.isValidGapTagType(gapTagType)){
			
			if (invalidCTTGapTagString != null) {
				try {
					reportProgress("\taddTagsToContig: adding CT tag " + count + " of type " + gapTagType + " holding " + invalidCTTGapTagString);		
					contigBuilder.addCTTagToContig(contig, gapTagType, invalidCTTGapTagString, 74294504, 4, 26);	
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
			e2.getMessage();
			e2.printStackTrace();
		}
		
		reportProgress("\nTest 7: really getting these tags from the database");
		
		String tagString = "";
		String strand = "F";
		int seq_id = 74294853;
		
		Contig savedContig = null;
		
		try {
			savedContig = adb.getContigByID(2048);
		} catch (ArcturusDatabaseException e1) {
			// TODO Auto-generated catch block
			e1.getMessage();
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
			Arcturus.logSevere("Unable to find read tags for contig "+ savedContig.getName());
		}
		
		reportProgress("\nTest 8: printing the retrieved tag set: " + adb.printTagSet(tagList));
		
		reportProgress("\nTest 9: printing the first tag " + tagList.firstElement().toSAMString());
		
		reportProgress("\nTest 10: printing the contig tag set for contig 2048\n");
		
		try {
			savedContig = adb.getContigByID(2048);
		} catch (ArcturusDatabaseException e1) {
			// TODO Auto-generated catch block
			e1.getMessage();
			e1.printStackTrace();
		}
		
		try {
			adb.loadTagsForContig(savedContig);
			reportProgress("\t\t found " + savedContig.getTagCount() + " tags for contig "+ savedContig.getName() + "\n");
		}
		catch (ArcturusDatabaseException e){
				Arcturus.logSevere("Unable to find contig tags for contig "+ savedContig.getName());
		}

		Vector<Tag> savedCTTags = savedContig.getTags();
		
		if (tags != null) {
			reportProgress("\nTest 11: Printing saved contig tag set with " + savedCTTags.size() + " elements: \n" + adb.printTagSet(savedCTTags));
			
			Iterator <Tag> iterator = savedCTTags.iterator();
			
			while (iterator.hasNext() ){
				Tag tag = iterator.next();
				reportProgress("\ttag should be from position 67 for 5 bases\n\tprinting tag from " + tag.getStart() + " length " + tag.getLength() + ": " + tag.toCTSAMString());
			}
		}
		else {
			reportProgress("no tags to process!");
		}
		reportProgress("TESTS complete");
	} catch (ArcturusDatabaseException e3) {
		// TODO Auto-generated catch block
		e3.printStackTrace();
	}
	
}
}
