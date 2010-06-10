package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class Read extends Core {
	private int flags = 0;
	
	public Read(String name) {
		this(name, 0);
	}
	
	public Read(String name, int flags) {
		super(name);
		
		setFlags(flags);
	}
	
	public Read(String name, int ID, ArcturusDatabase adb) {
		super(name, ID, adb);
	}

	public Read(int id, String name, int flags) {
		super(name, id, null);
		
		setFlags(flags);
	}

	public void setFlags(int flags) {
		this.flags = flags;
	}
	
	public int getFlags() {
		return flags;
	}

	static final int FLAG_MASK= 128 + 64 + 1;
	
	public String getUniqueName() {
		int masked_flags = flags & FLAG_MASK;
		return masked_flags == 0 ? name : name + "/" + masked_flags;
	}
}
