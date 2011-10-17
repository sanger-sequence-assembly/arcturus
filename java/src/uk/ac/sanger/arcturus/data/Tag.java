package uk.ac.sanger.arcturus.data;

/**
 * @author kt6
 *
 */
public class Tag extends Core {
	protected int start;
	protected int length;
	protected int sequence_id;
	protected String samTagType;
	protected String gapTagType;
	protected String comment;
	protected char strand;
	protected char samType;

	public Tag(String samTagType, char samType, String gapTagType, int start, int length, 
			String comment, int sequence_id, char strand) {
		this.start = start;
		this.length = length;
		this.samType = samType;
		this.gapTagType = gapTagType;
		this.samTagType = samTagType;
		this.comment = comment;
		this.strand = strand;
		this.sequence_id = sequence_id;
	}

	public int getStart() {
		return start;
	}

	public int getLength() {
		return length;
	}
	
	public int getEnd() {
		return (start + length);
	}
	
	public char getSAMType() {
		return samType;
	}
	
	public String getSAMTypeAsString() {	
		String samTypeString = "" + samType;
		return samTypeString;
	}
	
	public String getSAMTagType() {
		return samTagType;
	}
	
	public String getGAPTagType() {
		return gapTagType;
	}

	public String getComment() {
		return comment;
	}
	
	public char getStrand() {
		return strand;
	}
	
	public String getStrandAsString() {
		return "" + strand;
	}
	
	public int getSequenceId() {
		return sequence_id;
	}
	
	public boolean isContigTag(){
		return (gapTagType.equals("Zc"));
	}
	
	/**
	 * Sequence (consensus) tag looks like Zs:Z:REPT|5|1|Tag inserted at position 25 at start of AAAA 
	 * @return
	 * Contig tag looks like Zc:Z:POLY|31|42|weird Ns
	 */
	public String toSAMString() {
		
		return samTagType + ":" + samType + ":" + gapTagType + "|" + start + "|" + length
		+ (comment == null ? "" : "|" + comment);
		
	}
	
	public String toZSAMString() {
		
		return samTagType + ":" + samType + ":" + gapTagType + "|" + start + "|" + length
		+ (comment == null ? "" : "|" + comment);
		
	}
	
	/**
	 * Sequence (consensus) tag looks like RT:Z:REPT|5|1|Tag inserted at position 25 at start of AAAA 
	 * @return
	 * Contig PT tag looks like PT:Z:26|32|-|COMM|gff3src=GenBankLifter or PT:Z:26|32|-|COMM|gff3src=GenBankLifter|15|25|KATE|+|Here is a KATE type comment
	 */
	public String toPTSAMString() {
		
		return (samTagType + ":" + samType + ":" + comment);
		
	}
	/**
	 * Tag DONE 1945220 1945242 "polymorphisms linked/unique"
	 * @return
	 */
	public String toCAFString() {
		
			return "Tag " + gapTagType + " " + start + " " + (start + length)
					+ (comment == null ? "" : " \"" + comment + "\"");
		
	}
}
