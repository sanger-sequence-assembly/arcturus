package uk.ac.sanger.arcturus.snpdetection;

import uk.ac.sanger.arcturus.data.*;

public class CloneReadGroup extends ReadGroup {
	private int clone_id = -1;
	private String name;
	
	public CloneReadGroup(Clone clone) {
		if (clone != null) {
			clone_id = clone.getID();
			name = clone.getName();
		}
	}
	
	public boolean belongsTo(Read read) {
		if (read == null)
			return false;
		
		Template template = read.getTemplate();
		
		if (template == null)
			return false;
		
		Ligation ligation = template.getLigation();
		
		if (ligation == null)
			return false;
		
		Clone clone = ligation.getClone();
		
		return clone == null ? false : clone.getID() == clone_id;
	}
	
	public String toString() {
		return "CloneReadGroup[name=\"" + name + "\"]";
	}
}
