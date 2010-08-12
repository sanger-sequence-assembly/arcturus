package uk.ac.sanger.arcturus.fasta;

public interface SequenceProcessor {
	public void processSequence(String name, byte[] dna, byte[] quality);
}
