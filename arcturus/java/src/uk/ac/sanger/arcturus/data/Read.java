package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * This class represents a sequence reading.
 */

public class Read extends Core {
    /**
     * A constant representing the forward strand of a sub-clone.
     */

    public final static short FORWARD = 1;

    /**
     * A constant representing the reverse strand of a sub-clone.
     */

    public final static short REVERSE = 2;

    /**
     * A constant representing dye primer chemistry.
     */

    public final static short DYE_PRIMER = 1;

    /**
     * A constant representing dye terminator chemistry.
     */

    public final static short DYE_TERMINATOR = 2;

    /**
     * A constant representing a universal primer.
     */

    public final static short UNIVERSAL_PRIMER = 1;

    /**
     * A constant representing a custom primer.
     */

    public final static short CUSTOM_PRIMER = 2;

    private Template template;
    private java.sql.Date asped;
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
     * @param template the template from which this read was created.
     * @param asped the date on which this read was asped.
     * @param strand the code which represents the strand of this read.
     * @param primer the code which represents the primer of this read.
     * @param chemistry the code which represents the chemistry of this read.
     * @param adb the Arcturus database to which this Read belongs.
     */

    public Read(String name, int ID, Template template, java.sql.Date asped, short strand,
		short primer, short chemistry, ArcturusDatabase adb) {
	super(name, ID, adb);

	this.template = template;
	this.asped = asped;
	this.strand = strand;
	this.primer = primer;
	this.chemistry = chemistry;
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

    public void setAsped(java.sql.Date asped) {
	this.asped = asped;
    }

    public java.sql.Date getAsped() { return asped; }

    public void setStrand(short strand) {
	this.strand = strand;
    }

    public short getStrand() { return strand; }

    public void setPrimer(short primer) {
	this.primer = primer;
    }

    public short getPrimer() { return primer; }

    public void setChemistry(short chemistry) {
	this.chemistry = chemistry;
    }

    public short getChemistry() { return chemistry; }
}
