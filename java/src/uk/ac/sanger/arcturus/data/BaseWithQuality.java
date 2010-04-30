package uk.ac.sanger.arcturus.data;

public class BaseWithQuality {
	public static final char STAR = '*';
	public static final char DASH = '-';
	
	private char base;
	private int quality;
	
	public BaseWithQuality(char base, int quality) {
		this.base = base;
		this.quality = quality;
	}
	
	public void setBase(char base) {
		this.base = base;
	}
	
	public char getBase() {
		return base;
	}
	
	public void setQuality(int quality) {
		this.quality = quality;
	}
	
	public int getQuality() {
		return quality;
	}
	
	public boolean isPad() {
		return base == STAR || base == DASH;
	}
}
