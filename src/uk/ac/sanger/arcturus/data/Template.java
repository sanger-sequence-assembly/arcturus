package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * This class represents a sub-clone or read template.
 */

public class Template extends Core {
    private Ligation ligation;

    /**
     * Constructs a Template which does not yet have an ID.
     * This constructor will typically be used to create a Template
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     *
     * @param name the name of the object.
     */

    public Template(String name) {
	super(name);
    }

    /**
     * Constructs a Template which has a name and an ID.
     * This constructor will typically be used when a Template
     * is retrieved from an Arcturus database.
     *
     * @param name the name of the Template.
     * @param ID the ID of the Template.
     * @param adb the Arcturus database to which this Template belongs.
     */

    public Template(String name, int ID, ArcturusDatabase adb) {
	super(name, ID, adb);
    }

    /**
     * Sets the Ligation to which this Template belongs.
     *
     * @param ligation the Ligation to which this Template belongs.
     */

    public void setLigation(Ligation ligation) {
	this.ligation =ligation;
    }

    /**
     * Gets the Ligation to which this Template belongs.
     *
     * @return the Ligation to which this Template belongs.
     */

    public Ligation getLigation() { return ligation; }
}
