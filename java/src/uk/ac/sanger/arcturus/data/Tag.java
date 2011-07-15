package uk.ac.sanger.arcturus.data;

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
	
	public String toSAMString() {
		
		// Zs:Z:REPT|5|1|Tag inserted at position 25 at start of AAAA 
		// Zs:Z:COMM|28|1|Tag inserted at position 48 as a comment at the start of AAAAAA
		
		return gapTagType + ":" + samType + ":" + samTagType + "|" + start + "|" + length
		+ (comment == null ? "" : "|" + comment + "|");
		
	}
	
	public String toCAFString() {
			return "Tag " + gapTagType + " " + start + " " + (start + length)
					+ (comment == null ? "" : " \"" + comment + "\"");
		
	}
}
