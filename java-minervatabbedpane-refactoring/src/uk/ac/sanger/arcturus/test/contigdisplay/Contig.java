package uk.ac.sanger.arcturus.test.contigdisplay;

public class Contig {
	protected String name;
	protected int length;

	public Contig(String name, int length) {
		this.name = name;
		this.length = length;
	}

	public String getName() {
		return name;
	}

	public int getLength() {
		return length;
	}

	public String toString() {
		return "Contig[name=" + name + ", length=" + length + "]";
	}
}
