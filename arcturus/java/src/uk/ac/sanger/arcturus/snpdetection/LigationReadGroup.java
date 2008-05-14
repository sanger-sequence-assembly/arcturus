package uk.ac.sanger.arcturus.snpdetection;

import uk.ac.sanger.arcturus.data.*;

public class LigationReadGroup extends ReadGroup {
	private int ligation_id = -1;
	private String name;
	
	public LigationReadGroup(Ligation ligation) {
		if (ligation != null) {
			ligation_id = ligation.getID();
			name = ligation.getName();
		}
	}
	
	public boolean belongsTo(Read read) {
		if (read == null)
			return false;
		
		Template template = read.getTemplate();
		
		if (template == null)
			return false;
		
		Ligation ligation = template.getLigation();
		
		return ligation == null ? false : ligation.getID() == ligation_id;
	}

	public String toString() {
		return "LigationReadGroup[name=\"" + name + "\"]";
	}
}
