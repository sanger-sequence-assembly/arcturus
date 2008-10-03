package uk.ac.sanger.arcturus.tag;

public class Tag {
	public static final int FORWARD = 1;
	public static final int REVERSE = 2;
	public static final int UNKNOWN = 3;

	protected int id;
	protected int contig_id;
	protected int parent_id;
	protected int tag_id;
	protected int cstart;
	protected int cfinal;
	protected int strand;
	protected String tagtype;
	protected String tagcomment;

	public void setStrand(String s) {
		if (s == null)
			strand = UNKNOWN;
		else if (s.equalsIgnoreCase("F"))
			strand = FORWARD;
		else if (s.equalsIgnoreCase("R"))
			strand = REVERSE;
		else
			strand = UNKNOWN;
	}

	public String toString() {
		return "Tag[id=" + id + ", parent_id=" + parent_id + ", contig_id="
				+ contig_id + ", tag_id=" + tag_id + ", cstart=" + cstart
				+ ", cfinal=" + cfinal + "]";
	}

}
