package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;

/**
 * This class represents a sub-clone or read template.
 */

public class Template extends Core {
	private Ligation ligation;
	private HashSet forwardReads;
	private HashSet reverseReads;

	/**
	 * Constructs a Template which does not yet have an ID. This constructor
	 * will typically be used to create a Template <EM>ab initio</EM> prior to
	 * putting it into an Arcturus database.
	 * 
	 * @param name
	 *            the name of the object.
	 */

	public Template(String name) {
		super(name);
	}

	/**
	 * Constructs a Template which has a name, an ID and a ligation. This
	 * constructor will typically be used when a Template is retrieved from an
	 * Arcturus database.
	 * 
	 * @param name
	 *            the name of the Template.
	 * @param ID
	 *            the ID of the Template.
	 * @param ligation
	 *            the ligation from which this template was created.
	 * @param adb
	 *            the Arcturus database to which this Template belongs.
	 */

	public Template(String name, int ID, Ligation ligation, ArcturusDatabase adb) {
		super(name, ID, adb);

		this.ligation = ligation;

		forwardReads = new HashSet();
		reverseReads = new HashSet();
	}

	/**
	 * Sets the Ligation to which this Template belongs.
	 * 
	 * @param ligation
	 *            the Ligation to which this Template belongs.
	 */

	public void setLigation(Ligation ligation) {
		this.ligation = ligation;
	}

	/**
	 * Gets the Ligation to which this Template belongs.
	 * 
	 * @return the Ligation to which this Template belongs.
	 */

	public Ligation getLigation() {
		return ligation;
	}

	/**
	 * Adds the specified read to the set of forward or reverse reads belonging
	 * to this template.
	 * 
	 * @param read
	 *            the read which is to be added to this template's set.
	 */

	void addRead(Read read) throws IllegalArgumentException {
		Template tmpl = read.getTemplate();

		if (tmpl == null || tmpl != this)
			throw new IllegalArgumentException("Read[name=" + read.getName()
					+ "] does not belong to Template[name=" + name + "]");

		if (read.getStrand() == Read.FORWARD)
			forwardReads.add(read);
		else
			reverseReads.add(read);
	}

	/**
	 * Returns an Iterator for the set of forward reads which belong to this
	 * template.
	 * 
	 * @return an Iterator for the set of forward reads which belong to this
	 *         template.
	 */

	public Iterator getForwardReadsIterator() {
		return forwardReads.iterator();
	}

	/**
	 * Returns an Iterator for the set of reverse reads which belong to this
	 * template.
	 * 
	 * @return an Iterator for the set of reverse reads which belong to this
	 *         template.
	 */

	public Iterator getReverseReadsIterator() {
		return reverseReads.iterator();
	}
}
