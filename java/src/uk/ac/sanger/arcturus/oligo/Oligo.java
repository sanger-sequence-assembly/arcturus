package uk.ac.sanger.arcturus.oligo;

public class Oligo implements Comparable {
	private static int counter = 0;
	
	private String name;
	private String sequence;
	private String revsequence;
	private int hash = -1;
	private int revhash = -1;
	
	public Oligo(String name, String sequence) {
		this.name = name;
		this.sequence = sequence.toUpperCase();
		revsequence = reverseComplement(sequence);
	}
	
	public Oligo(String sequence) {
		name = "ANON." + (++counter);
		this.sequence = sequence.toUpperCase();
		revsequence = reverseComplement(sequence);
	}
	
	public String getName() { return name; }
	
	public String getSequence() { return sequence; }
	
	public String getReverseSequence() { return revsequence; }
	
	public void setHash(int hash) { this.hash = hash; }
	
	public int getHash() { return hash; }
	
	public void setReverseHash(int revhash) { this.revhash = revhash; }
	
	public int getReverseHash() { return revhash; }
	
	public int getLength() { return sequence.length(); }
	
	private String reverseComplement(String str) {
		int strlen = str.length();
		
		char[] revchars = new char[strlen];
		
		for (int i = 0; i < strlen; i++) {
			char src = str.charAt(i);
			
			char dst;
			
			switch (src) {
				case 'a': case 'A': dst = 'T'; break;
				case 'c': case 'C': dst = 'G'; break;
				case 'g': case 'G': dst = 'C'; break;
				case 't': case 'T': dst = 'A'; break;
				default: dst = 'N'; break;
			}
			
			revchars[strlen - 1 - i] = dst;
		}
		
		return new String(revchars);
	}

	public int compareTo(Object o) {
		Oligo that = (Oligo)o;
		
		return name.compareTo(that.getName());
	}
}
