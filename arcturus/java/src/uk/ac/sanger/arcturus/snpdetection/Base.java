package uk.ac.sanger.arcturus.snpdetection;

import uk.ac.sanger.arcturus.data.Read;

public class Base {
	protected Read read;
	protected int sequence_id;
	protected int read_position;
	protected char strand;
	protected int chemistry;
	protected char base;
	protected int quality;

	public Base(Read read, int sequence_id, int read_position, char strand,
			int chemistry, char base, int quality) {
		this.read = read;
		this.sequence_id = sequence_id;
		this.read_position = read_position;
		this.strand = strand;
		this.chemistry = chemistry;
		this.base = Character.toUpperCase(base);
		this.quality = quality;
	}
}
