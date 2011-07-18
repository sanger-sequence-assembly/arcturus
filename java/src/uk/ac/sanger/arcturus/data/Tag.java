package uk.ac.sanger.arcturus.data;

/**
 * @author kt6
 *
 */
public class Tag extends Core {
	protected int start;
	protected int length;
	protected String samTagType;
	protected String gapTagType;
	protected String comment;
	protected char samType;

	public Tag(String samTagType, char samType, String gapTagType, int start, int length, String comment) {
		this.start = start;
		this.length = length;
		this.samType = samType;
		this.gapTagType = gapTagType;
		this.samTagType = samTagType;
		this.comment = comment;
	}

	public int getStart() {
		return start;
	}

	public int getEnd() {
		return length;
	}

	public char getSAMType() {
		return samType;
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
	
	/**
	 * Sequence (consensus) tag looks like Zs:Z:REPT|5|1|Tag inserted at position 25 at start of AAAA 
	 * @return
	 * Contig tag looks like Zc:Z:POLY|31|42|weird Ns
	 */
	public String toSAMString() {
		
		return gapTagType + ":" + samType + ":" + samTagType + "|" + start + "|" + length
		+ (comment == null ? "" : "|" + comment + "|");
		
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
