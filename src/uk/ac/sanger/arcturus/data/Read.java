package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * This class represents a sequence reading.
 */

public class Read extends Core {
    /**
     * A constant representing the forward strand of a sub-clone.
     */

    public final static int FORWARD = 1;

    /**
     * A constant representing the reverse strand of a sub-clone.
     */

    public final static int REVERSE = 2;

    /**
     * A constant representing dye primer chemistry.
     */

    public final static int DYE_PRIMER = 1;

    /**
     * A constant representing dye terminator chemistry.
     */

    public final static int DYE_TERMINATOR = 2;

    /**
     * A constant representing a universal primer.
     */

    public final static int UNIVERSAL_PRIMER = 1;

    /**
     * A constant representing a custom primer.
     */

    public final static int CUSTOM_PRIMER = 2;

    private Template template;
    private short strand;
    private short chemistry;
    private short primer;

    /**
     * Constructs a Read which does not yet have an ID.
     * This constructor will typically be used to create a Read
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     *
     * @param name the name of the object.
     */

    public Read(String name) {
	super(name);
    }

    /**
     * Constructs a Read which has a name and an ID.
     * This constructor will typically be used when a Read
     * is retrieved from an Arcturus database.
     *
     * @param name the name of the Read.
     * @param ID the ID of the Read.
     * @param adb the Arcturus database to which this Read belongs.
     */

    public Read(String name, int ID, ArcturusDatabase adb) {
	super(name, ID, adb);
    }

    /**
     * Sets the Template from which this Read was sequenced.
     *
     * @param template the Template associated with this Read.
     */

    public void setTemplate(Template template) {
	this.template = template;
    }

    /**
     * Gets the Template from which this Read was sequenced.
     *
     * @return the Template associated with this Read.
     */

    public Template getTemplate() { return template; }
}
