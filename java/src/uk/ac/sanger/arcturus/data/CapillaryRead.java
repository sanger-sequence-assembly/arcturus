package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * This class represents a sequence reading.
 */

public class CapillaryRead extends Read {
	/**
	 * A constant representing the forward strand of a sub-clone.
	 */

	public final static int FORWARD = 1;
	
	public final static String FORWARD_STRING = "Forward";

	/**
	 * A constant representing the reverse strand of a sub-clone.
	 */

	public final static int REVERSE = 2;
	
	public final static String REVERSE_STRING = "Reverse";

	/**
	 * A constant representing dye primer chemistry.
	 */

	public final static int DYE_PRIMER = 1;
	
	public final static String DYE_PRIMER_STRING = "Dye_primer";

	/**
	 * A constant representing dye terminator chemistry.
	 */

	public final static int DYE_TERMINATOR = 2;
	
	public final static String DYE_TERMINATOR_STRING = "Dye_terminator";

	/**
	 * A constant representing a universal primer.
	 */

	public final static int UNIVERSAL_PRIMER = 1;
	
	public final static String UNIVERSAL_PRIMER_STRING = "Universal_primer";

	/**
	 * A constant representing a custom primer.
	 */

	public final static int CUSTOM_PRIMER = 2;
	
	public final static String CUSTOM_PRIMER_STRING = "Custom";

	private final static java.text.DateFormat dateformat = new java.text.SimpleDateFormat(
			"yyyy-MM-dd");

	private Template template;
	private java.util.Date asped;
	private int strand;
	private int chemistry;
	private int primer;
	private String basecaller;
	private String status;

	/**
	 * Constructs a CapillaryRead which does not yet have an ID. This constructor will
	 * typically be used to create a CapillaryRead <EM>ab initio</EM> prior to putting
	 * it into an Arcturus database.
	 * 
	 * @param name
	 *            the name of the object.
	 */

	public CapillaryRead(String name) {
		super(name);
	}

	/**
	 * Constructs a CapillaryRead which has a name and an ID.  This constructor may be used by
	 * applications which do not need the other properties of the read object.
	 * 
	 * @param name
	 *            the name of the object.
	 * @param ID
	 *            the ID of the Read.
	 * @param adb
	 *            the Arcturus database to which this CapillaryRead belongs.
	 */

	public CapillaryRead(String name, int ID, ArcturusDatabase adb) {
		super(name, ID, adb);
	}

	/**
	 * Constructs a CapillaryRead which has a name and an ID. This constructor will
	 * typically be used when a CapillaryRead is retrieved from an Arcturus database.
	 * 
	 * @param name
	 *            the name of the Read.
	 * @param ID
	 *            the ID of the Read.
	 * @param template
	 *            the template from which this read was created.
	 * @param asped
	 *            the date on which this read was asped.
	 * @param strand
	 *            the code which represents the strand of this read.
	 * @param primer
	 *            the code which represents the primer of this read.
	 * @param chemistry
	 *            the code which represents the chemistry of this read.
	 * @param adb
	 *            the Arcturus database to which this CapillaryRead belongs.
	 */

	public CapillaryRead(String name, int ID, Template template, java.util.Date asped,
			int strand, int primer, int chemistry, String basecaller, String status, ArcturusDatabase adb) {
		super(name, ID, adb);

		setTemplate(template);

		this.asped = asped;
		this.strand = strand;
		this.primer = primer;
		this.chemistry = chemistry;
		
		this.basecaller = basecaller;
		this.status = status;
	}

	/**
	 * Sets the Template from which this CapillaryRead was sequenced.
	 * 
	 * @param template
	 *            the Template associated with this Read.
	 */

	public void setTemplate(Template template) {
		this.template = template;
		
		if (template != null)
			template.addRead(this);
	}

	/**
	 * Gets the Template from which this CapillaryRead was sequenced.
	 * 
	 * @return the Template associated with this Read.
	 */

	public Template getTemplate() {
		return template;
	}

	/**
	 * Sets the asped date for this read.
	 * 
	 * @param asped
	 *            the date on which this read was asped.
	 */

	public void setAsped(java.util.Date asped) {
		this.asped = asped;
	}

	/**
	 * Returns the asped date for this read.
	 * 
	 * @return the date on which this read was asped.
	 */

	public java.util.Date getAsped() {
		return asped;
	}

	/**
	 * Sets the strand for this read.
	 * 
	 * @param strand
	 *            the strand, which should be one of FORWARD, REVERSE or
	 *            UNKNOWN.
	 */

	public void setStrand(int strand) {
		this.strand = strand;
	}

	/**
	 * Returns the strand of this read.
	 * 
	 * @return the strand of this read, which is one of FORWARD, REVERSE or
	 *         UNKNOWN.
	 */

	public int getStrand() {
		return strand;
	}

	/**
	 * Sets the primer for this read.
	 * 
	 * @param primer
	 *            the primer, which should be one of UNIVERSAL_PRIMER,
	 *            CUSTOM_PRIMER or UNKNOWN.
	 */

	public void setPrimer(int primer) {
		this.primer = primer;
	}

	/**
	 * Returns the primer of this read.
	 * 
	 * @return the primer, which is one of UNIVERSAL_PRIMER, CUSTOM_PRIMER or
	 *         UNKNOWN.
	 */

	public int getPrimer() {
		return primer;
	}

	/**
	 * Sets the chemistry of this read.
	 * 
	 * @param chemistry
	 *            the chemistry of this read, which should be one of
	 *            DYE_TERMINATOR, DYE_PRIMER or UNKNOWN.
	 */

	public void setChemistry(int chemistry) {
		this.chemistry = chemistry;
	}

	/**
	 * Returns the chemistry of this read.
	 * 
	 * @return the chemistry of this read, which is one of DYE_TERMINATOR,
	 *         DYE_PRIMER or UNKNOWN.
	 */

	public int getChemistry() {
		return chemistry;
	}
	
	/**
	 * Sets the basecaller of this read.
	 * 
	 * @param basecaller the name of the basecaller of this read.
	 */
	
	public void setBasecaller(String basecaller) {
		this.basecaller = basecaller;
	}
	
	/**
	 * Returns the basecaller of this read.
	 * 
	 * @return the basecaller of this read.
	 */
	
	public String getBasecaller() {
		return basecaller;
	}
	
	/**
	 * Sets the status of this read.
	 * 
	 * @param status the status of this read.
	 * 
	 */
	
	public void setStatus(String status) {
		this.status = status;
	}
	
	/**
	 * Returns the status of this read.
	 * 
	 * @return the status of this read.
	 */
	
	public String getStatus() {
		return status;
	}

	/**
	 * Returns a string representing this read in CAF format. The string is
	 * terminated by a newline.
	 * 
	 * @return a string representing this read in CAF format. The string is
	 *         terminated by a newline.
	 */

	public String toCAFString() {
		StringBuffer buffer = new StringBuffer();

		buffer.append("Sequence : " + name + "\n");
		buffer.append("Is_read\n");
		buffer.append("Unpadded\n");

		if (template != null) {
			buffer.append("Template " + template.getName() + "\n");
			Ligation ligation = template.getLigation();

			if (ligation != null) {
				buffer.append("Ligation " + ligation.getName() + "\n");
				buffer.append("Insert_size " + ligation.getInsertSizeLow()
						+ " " + ligation.getInsertSizeHigh() + "\n");

				Clone clone = ligation.getClone();

				if (clone != null)
					buffer.append("Clone " + clone.getName() + "\n");
			}
		}

		if (asped != null)
			buffer.append("Asped " + dateformat.format(asped) + "\n");

		switch (strand) {
			case FORWARD:
				buffer.append("Strand Forward\n");
				break;
			case REVERSE:
				buffer.append("Strand Reverse\n");
				break;
		}

		switch (primer) {
			case UNIVERSAL_PRIMER:
				buffer.append("Primer Universal_primer\n");
				break;
			case CUSTOM_PRIMER:
				buffer.append("Primer Custom\n");
				break;
			case UNKNOWN:
				buffer.append("Primer Unknown_primer\n");
				break;
		}

		switch (chemistry) {
			case DYE_TERMINATOR:
				buffer.append("Dye Dye_terminator\n");
				break;
			case DYE_PRIMER:
				buffer.append("Dye Dye_primer\n");
				break;
		}

		if (status != null)
			buffer.append("ProcessStatus " + status + "\n");
		else
			buffer.append("ProcessStatus PASS\n");
		
		if (basecaller != null)
			buffer.append("BaseCaller " + basecaller + "\n");

		return buffer.toString();
	}
}
