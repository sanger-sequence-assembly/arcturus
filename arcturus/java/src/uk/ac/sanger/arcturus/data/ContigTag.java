package uk.ac.sanger.arcturus.data;

public class ContigTag extends Core {
	protected int cstart;
	protected int cfinal;
	protected char strand;
	protected String type;
	protected String systematicID;

	public ContigTag(String type, int cstart, int cfinal, char strand,
			String name) {
		super(name);
		this.type = type.intern();
		this.cstart = cstart;
		this.cfinal = cfinal;
		this.strand = strand;
	}

	public int getContigStart() {
		return cstart;
	}

	public int getContigFinish() {
		return cfinal;
	}

	public char getStrand() {
		return strand;
	}

	public String getType() {
		return type;
	}

	public String toString() {
		return "ContigTag[type=" + type + ", name=" + name + ", cstart="
				+ cstart + ", cfinal=" + cfinal + ", strand=" + strand + "]";
	}
}
