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
    private java.util.Date asped;
    private int strand;
    private int chemistry;
    private int primer;

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

    public Read(String name, int ID, Template template, java.util.Date asped, int strand,
		int primer, int chemistry, ArcturusDatabase adb) {
	super(name, ID, adb);

	setTemplate(template);

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
	template.addRead(this);
    }

    /**
     * Gets the Template from which this Read was sequenced.
     *
     * @return the Template associated with this Read.
     */

    public Template getTemplate() { return template; }

    /**
     * Sets the asped date for this read.
     *
     * @param asped the date on which this read was asped.
     */

    public void setAsped(java.util.Date asped) {
	this.asped = asped;
    }

    /**
     * Returns the asped date for this read.
     *
     * @return the date on which this read was asped.
     */

    public java.util.Date getAsped() { return asped; }

    /**
     * Sets the strand for this read.
     *
     * @param strand the strand, which should be one of FORWARD, REVERSE or UNKNOWN.
     */

    public void setStrand(int strand) {
	this.strand = strand;
    }

    /**
     * Returns the strand of this read.
     *
     * @return the strand of this read, which is one of FORWARD, REVERSE or UNKNOWN.
     */

    public int getStrand() { return strand; }

    /**
     * Sets the primer for this read.
     *
     * @param primer the primer, which should be one of UNIVERSAL_PRIMER,
     * CUSTOM_PRIMER or UNKNOWN.
     */

    public void setPrimer(int primer) {
	this.primer = primer;
    }

    /**
     * Returns the primer of this read.
     *
     * @return the primer, which is one of UNIVERSAL_PRIMER,
     * CUSTOM_PRIMER or UNKNOWN.
     */

    public int getPrimer() { return primer; }

    /**
     * Sets the chemistry of this read.
     *
     * @param chemistry the chemistry of this read, which should be one of
     * DYE_TERMINATOR, DYE_PRIMER or UNKNOWN.
     */

    public void setChemistry(int chemistry) {
	this.chemistry = chemistry;
    }

    /**
     * Returns the chemistry of this read.
     *
     * @return the chemistry of this read, which is one of
     * DYE_TERMINATOR, DYE_PRIMER or UNKNOWN.
     */

    public int getChemistry() { return chemistry; }
}
