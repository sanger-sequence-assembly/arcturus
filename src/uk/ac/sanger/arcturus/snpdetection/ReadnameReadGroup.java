package uk.ac.sanger.arcturus.snpdetection;

import java.util.regex.*;

import uk.ac.sanger.arcturus.data.Read;

public class ReadnameReadGroup extends ReadGroup {
	private String name;
	private Pattern pattern;
	
	public ReadnameReadGroup(String name) {
		this.name = name;
		pattern = Pattern.compile(name);
	}
	
	public boolean belongsTo(Read read) {
		return read == null ? false : pattern.matcher(read.getName()).matches();
	}
	
	public String toString() {
		return "ReadnameReadGroup[pattern=\"" + name + "\"]";
	}
}
