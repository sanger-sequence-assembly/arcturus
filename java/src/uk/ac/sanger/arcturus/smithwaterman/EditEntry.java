package uk.ac.sanger.arcturus.smithwaterman;

public class EditEntry {
	public static final char MATCH = 'M';
	public static final char SUBSTITUTION = 'S';
	public static final char INSERTION = 'I';
	public static final char DELETION = 'D';
	public static final char UNKNOWN = '?';
	
	private char type;
	private int count;
	
	public EditEntry(char type, int count) {
		this.type = type;
		this.count = count;
	}
	
	public void setType(char type) {
		this.type = type;
	}
	
	public char getType() {
		return type;
	}
	
	public void setCount(int count) {
		this.count = count;
	}
	
	public int getCount() {
		return count;
	}
	
	public String toString() {
		return "" + type + count;
	}
}
