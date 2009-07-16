package uk.ac.sanger.arcturus.data;

import java.util.Vector;

/**
 * An object which represents a read sequence, consisting of a DNA sequence
 * string, a base quality array and a version number.
 */

public class Sequence extends Core {
	protected Read read = null;
	protected byte[] dna = null;
	protected byte[] quality = null;
	protected int length = -1;
	protected int version;
	protected Clipping qualityClip = null;
	protected Clipping cvectorClip = null;
	protected Clipping svectorClipLeft = null;
	protected Clipping svectorClipRight = null;
	protected AlignToSCF[] alignToSCF = null;
	protected Vector<Tag> tags = null;

	/**
	 * Construct a Sequence object for the specified read.
	 * 
	 * @param id
	 *            the unique identifier of this sequence.
	 * @param read
	 *            the Read object to which this sequence belongs.
	 * @param dna
	 *            the DNA sequence string. This may be null.
	 * @param quality
	 *            the base quality array. This may be null.
	 * @param version
	 *            the sequence version number. A read may have several versions
	 *            of its sequence if it is edited during finishing. Each
	 *            sequence for a particular read has a distinct version number.
	 */

	public Sequence(int id, Read read, byte[] dna, byte[] quality, int version) {
		this.ID = id;
		this.read = read;
		this.dna = dna;
		this.quality = quality;
		this.version = version;
	}

	/**
	 * Construct a Sequence object for the specified read.
	 * 
	 * @param id
	 *            the unique identifier of this sequence.
	 * @param read
	 *            the Read object to which this sequence belongs.
	 * @param length
	 *            the sequence length.
	 * @param version
	 *            the sequence version number. A read may have several versions
	 *            of its sequence if it is edited during finishing. Each
	 *            sequence for a particular read has a distinct version number.
	 */

	public Sequence(int id, Read read, int length, int version) {
		this.ID = id;
		this.read = read;
		this.length = length;
		this.version = version;
	}

	/**
	 * Construct a Sequence object for the specified read. The DNA and base
	 * quality are set to null and the version is set to UNKNOWN.
	 * 
	 * @param id
	 *            the unique identifier of this sequence.
	 * @param read
	 *            the Read object to which this sequence belongs.
	 */

	public Sequence(int id, Read read) {
		this(id, read, null, null, UNKNOWN);
	}

	/**
	 * Construct a Sequence object for the specified read. The DNA and base
	 * quality are set to null and the version is set to UNKNOWN.
	 * 
	 * @param id
	 *            the unique identifier of this sequence.
	 * @param read
	 *            the Read object to which this sequence belongs.
	 * @param length
	 *            the length of the sequence.
	 */

	public Sequence(int id, Read read, int length) {
		this(id, read, null, null, UNKNOWN);
		this.length = length;
	}

	/**
	 * Returns the Read object to which this sequence belongs.
	 * 
	 * @return the Read object to which this sequence belongs.
	 */

	public Read getRead() {
		return read;
	}

	/**
	 * Sets the Read object to which this sequence belongs.
	 * 
	 * @param read
	 *            the Read object to which this sequence belongs.
	 */

	public void setRead(Read read) {
		this.read = read;
	}

	/**
	 * Returns the DNA sequence string.
	 * 
	 * @return the DNA sequence string.
	 */

	public byte[] getDNA() {
		return dna;
	}

	/**
	 * Sets the DNA sequence string.
	 * 
	 * @param dna
	 *            the DNA sequence string.
	 */

	public void setDNA(byte[] dna) {
		this.dna = dna;
	}

	/**
	 * Returns the base quality array.
	 * 
	 * @return the base quality array.
	 */

	public byte[] getQuality() {
		return quality;
	}

	/**
	 * Sets the base quality array.
	 * 
	 * @param quality
	 *            the base quality array.
	 */

	public void setQuality(byte[] quality) {
		this.quality = quality;
	}

	/**
	 * Returns the version number of this sequence.
	 * 
	 * @return the version number of this sequence.
	 */

	public int getVersion() {
		return version;
	}

	/**
	 * Sets the version number of this sequence.
	 * 
	 * @param version
	 *            the version number of this sequence.
	 */

	public void setVersion(int version) {
		this.version = version;
	}

	/**
	 * Returns the length of the sequence, or -1 if it is not known.
	 * 
	 * @return the length of the sequence, or -1 if it is not known.
	 */

	public int getLength() {
		if (dna != null)
			return dna.length;

		if (quality != null)
			return quality.length;

		return length;
	}

	/**
	 */

	/**
	 * Sets the quality clipping.
	 * 
	 * @param qualityClip
	 *            the quality clipping.
	 */

	public void setQualityClipping(Clipping qualityClip) {
		this.qualityClip = qualityClip;
	}

	/**
	 * Returns the quality clipping.
	 * 
	 * @return the quality clipping.
	 */

	public Clipping getQualityClipping() {
		return qualityClip;
	}

	/**
	 * Sets the cloning vector clipping.
	 * 
	 * @param cvectorClip
	 *            the cloning vector clipping.
	 */

	public void setCloningVectorClipping(Clipping cvectorClip) {
		this.cvectorClip = cvectorClip;
	}

	/**
	 * Returns the cloning vector clipping.
	 * 
	 * @return the cloning vector clipping.
	 */

	public Clipping getCloningVectorClipping() {
		return cvectorClip;
	}

	/**
	 * Sets the left sequence vector clipping.
	 * 
	 * @param svectorClipLeft
	 *            the left sequence vector clipping.
	 */

	public void setSequenceVectorClippingLeft(Clipping svectorClipLeft) {
		this.svectorClipLeft = svectorClipLeft;
	}

	/**
	 * Returns the left sequence vector clipping.
	 * 
	 * @return the left sequence vector clipping.
	 */

	public Clipping getSequenceVectorClippingLeft() {
		return svectorClipLeft;
	}

	/**
	 * Sets the right sequence vector clipping.
	 * 
	 * @param svectorClipRight
	 *            the right sequence vector clipping.
	 */

	public void setSequenceVectorClippingRight(Clipping svectorClipRight) {
		this.svectorClipRight = svectorClipRight;
	}

	/**
	 * Returns the right sequence vector clipping.
	 * 
	 * @return the right sequence vector clipping.
	 */

	public Clipping getSequenceVectorClippingRight() {
		return svectorClipRight;
	}

	/**
	 * Sets all of the clippings.
	 * 
	 * @param qualityClip
	 *            the quality clipping.
	 * @param svectorClipLeft
	 *            the left sequence vector clipping.
	 * @param svectorClipRight
	 *            the right sequence vector clipping.
	 * @param cvectorClip
	 *            the cloning vector clipping.
	 */

	public void setClipping(Clipping qualityClip, Clipping svectorClipLeft,
			Clipping svectorClipRight, Clipping cvectorClip) {
		this.qualityClip = qualityClip;
		this.svectorClipLeft = svectorClipLeft;
		this.svectorClipRight = svectorClipRight;
		this.cvectorClip = cvectorClip;
	}

	/**
	 * Sets the quality and sequencing vector clippings. The cloning vector
	 * clipping is set to null.
	 * 
	 * @param qualityClip
	 *            the quality clipping.
	 * @param svectorClipLeft
	 *            the left sequence vector clipping.
	 * @param svectorClipRight
	 *            the right sequence vector clipping.
	 */

	public void setClipping(Clipping qualityClip, Clipping svectorClipLeft,
			Clipping svectorClipRight) {
		setClipping(qualityClip, svectorClipLeft, svectorClipRight, null);
	}

	/**
	 * Sets the array of AlignToSCF records.
	 * 
	 * @param alignToSCF
	 *            the array of AlignToSCF records.
	 */

	public void setAlignToSCF(AlignToSCF[] alignToSCF) {
		this.alignToSCF = alignToSCF;
	}

	/**
	 * Returns the array of AlignToSCF records.
	 * 
	 * @return the array of AlignToSCF records.
	 */

	public AlignToSCF[] getAlignToSCF() {
		return alignToSCF;
	}

	/**
	 * Adds a tag to this sequence.
	 * 
	 * @param tag the tag to be added to the sequence.
	 */
	
	public void addTag(Tag tag) {
		if (tags == null)
			tags = new Vector<Tag>();
		
		tags.add(tag);
	}

	/**
	 * Returns the vector of tags which belong to this sequence, or null
	 * if there are no tags.
	 * 
	 * @returnthe vector of tags which belong to this sequence, or null
	 * if there are no tags.
	 */
	
	public Vector<Tag> getTags() {
		return tags;
	}

	/**
	 * Returns a string representing the clipping and AligntoSCF data in CAF
	 * format. The string is terminated by a newline.
	 * 
	 * @return a string representing the clipping and AligntoSCF data in CAF
	 *         format. The string is terminated by a newline.
	 */

	public String toCAFString() {
		StringBuffer buffer = new StringBuffer();

		if (qualityClip != null)
			buffer.append(qualityClip.toCAFString() + "\n");

		if (svectorClipLeft != null)
			buffer.append(svectorClipLeft.toCAFString() + "\n");

		if (svectorClipRight != null)
			buffer.append(svectorClipRight.toCAFString() + "\n");

		if (cvectorClip != null)
			buffer.append(cvectorClip.toCAFString() + "\n");

		if (alignToSCF == null) {
			int seqlen = getLength();
			if (seqlen > 0)
				buffer.append("Align_to_SCF 1 " + seqlen + " 1 " + seqlen
						+ "\n");
		} else {
			for (int i = 0; i < alignToSCF.length; i++)
				buffer.append(alignToSCF[i].toCAFString() + "\n");
		}
		
		if (tags != null) {
			for (Tag tag : tags)
				buffer.append(tag.toCAFString() + "\n");
		}

		return buffer.toString();
	}
}
