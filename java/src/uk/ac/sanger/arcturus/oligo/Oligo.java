package uk.ac.sanger.arcturus.oligo;

import java.util.regex.Pattern;

public class Oligo implements Comparable {
	private static int counter = 0;
	
	private static final String SPACES = "[\\-]*";
	
	private String name;
	private String sequence;
	private String revsequence;
	private int hash = -1;
	private int revhash = -1;
	
	private boolean palindrome = false;
	
	private Pattern fwdPattern;
	private Pattern revPattern;
	
	public Oligo(String name, String sequence) {
		this.name = name;
		this.sequence = sequence.toUpperCase();
		revsequence = reverseComplement(sequence);
		
		palindrome = sequence.equalsIgnoreCase(revsequence);
	}
	
	public Oligo(String sequence) {
		this("ANON." + (++counter), sequence);
	}
	
	public String getName() { return name; }
	
	public String getSequence() { return sequence; }
	
	public String getReverseSequence() { return revsequence; }
	
	public void setHash(int hash) { this.hash = hash; }
	
	public int getHash() { return hash; }
	
	public void setReverseHash(int revhash) { this.revhash = revhash; }
	
	public int getReverseHash() { return revhash; }
	
	public int getLength() { return sequence.length(); }
	
	public boolean isPalindrome() {
		return palindrome;
	}
	
	public Pattern getForwardPattern() {
		if (fwdPattern == null)
			fwdPattern = preparePattern(sequence);
		
		return fwdPattern;
	}
	
	public Pattern getReversePattern() {
		if (revPattern == null && !palindrome)
			revPattern = preparePattern(revsequence);
		
		return revPattern;
	}
	
	private Pattern preparePattern(String seq) {
		StringBuilder sb = new StringBuilder();
		
		sb.append("(");
		sb.append(seq.charAt(0));
		
		for (int i = 1; i < seq.length(); i++) {
			sb.append(SPACES);
			sb.append(seq.charAt(i));
		}
		
		sb.append(")");
		
		return Pattern.compile(sb.toString());
	}
	
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
