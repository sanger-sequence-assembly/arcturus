package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class Read extends Core {
	private int flags = 0;
	
	public Read(String name) {
		this(name, 0);
	}
	
	public Read(String name, int flags) {
		super(name);
		
		this.flags = flags;
	}
	
	public Read(String name, int ID, ArcturusDatabase adb) {
		super(name, ID, adb);
	}

	public void setFlags(int flags) {
		this.flags = flags;
	}
	
	public int getFlags() {
		return flags;
	}
	
	public String getUniqueName() {
		return flags == 0 ? name : name + "/" + flags;
	}
}
