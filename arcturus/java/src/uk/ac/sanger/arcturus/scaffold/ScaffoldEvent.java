package uk.ac.sanger.arcturus.scaffold;

import java.util.EventObject;

public class ScaffoldEvent extends EventObject {
    public static final int START = 0;
    public static final int FINISH = 9999;
    public static final int BEGIN_CONTIG = 1;

    protected int mode;
    protected String description;
    
    ScaffoldEvent(Object source, int mode, String description) {
        super(source);
        this.mode = mode;
	this.description = description;
    }

    public int getMode() { return mode; }

    public String getDescription() { return description; }
}
