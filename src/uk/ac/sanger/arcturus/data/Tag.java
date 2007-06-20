package uk.ac.sanger.arcturus.data;

public class Tag extends Core {
	protected int start;
	protected int end;
	protected String type;
	protected String comment;

	public Tag(String type, int start, int end, String comment) {
		this.start = start;
		this.end = end;
		this.type = type;
		this.comment = comment;
	}

	public int getStart() {
		return start;
	}

	public int getEnd() {
		return end;
	}

	public String getType() {
		return type;
	}

	public String getComment() {
		return comment;
	}

	public String toCAFString() {
		return "Tag " + type + " " + start + " " + end
				+ (comment == null ? "" : "\"" + comment + "\"") + "\n";
	}
}
