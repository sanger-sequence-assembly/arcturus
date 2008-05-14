package uk.ac.sanger.arcturus.snpdetection;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public abstract class ReadGroup {
	public static final int BY_LIGATION = 1;
	public static final int BY_CLONE = 2;
	public static final int BY_READNAME = 3;
	
	public abstract boolean belongsTo(Read read);
	
	public static ReadGroup createReadGroup(ArcturusDatabase adb, String keyValue) {
		String[] words = keyValue.split("=");
		
		if (words.length == 2) {
			int type = 0;
			
			if (words[0].equalsIgnoreCase("ligation"))
				type = BY_LIGATION;
			else if (words[0].equalsIgnoreCase("clone"))
				type = BY_CLONE;
			else if (words[0].equalsIgnoreCase("readname"))
				type = BY_READNAME;
			else
				throw new IllegalArgumentException("key \"" + words[0] + "\" is invalid");
			
			return createReadGroup(adb, type, words[1]);
		} else
			throw new IllegalArgumentException("Cannot make sense of key-value parameter");
	}
	
	public static ReadGroup createReadGroup(ArcturusDatabase adb, int type, String name) {
		switch (type) {
			case BY_LIGATION:
				Ligation ligation = null;
				try {
					ligation = adb.getLigationByName(name);
				} catch (SQLException e) {
					e.printStackTrace();
				}
				return ligation == null ? null : new LigationReadGroup(ligation);
				
			case BY_CLONE:
				Clone clone = null;
				try {
					clone = adb.getCloneByName(name);
				} catch (SQLException e) {
					e.printStackTrace();
				}
				return clone == null ? null : new CloneReadGroup(clone);
				
			case BY_READNAME:
				return new ReadnameReadGroup(name);
				
			default:
				throw new IllegalArgumentException("Invalid type");
		}
	}
}
