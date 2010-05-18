package uk.ac.sanger.arcturus.traceserver;

/**
 * This interface defines the record type mnemonics which appear in a typical
 * experiment file, as defined in the Staden package user manual:
 * {@link http://staden.sourceforge.net/manual/formats_unix_18.html}.
 */

public interface ExperimentFile {
	public static final String KEY_READ_NAME = "ID";
	
	public static final String KEY_ASPED_DATE = "DT";
	
	public static final String KEY_CHEMISTRY = "CH";
	
	public static final String KEY_PRIMER = "PR";
	
	public static final String KEY_DIRECTION = "DR";
	
	public static final String KEY_INSERT_SIZE_RANGE = "SI";
	
	public static final String KEY_LIGATION_NAME = "LG";
	
	public static final String KEY_SEQUENCING_VECTOR_NAME = "SV";
	
	public static final String KEY_CLONE_NAME = "CN";
	
	public static final String KEY_CLONING_VECTOR_NAME = "CV";
	
	public static final String KEY_TEMPLATE_NAME = "TN";
	
	public static final String KEY_QUALITY_CLIP_LEFT = "QL";
	
	public static final String KEY_QUALITY_CLIP_RIGHT = "QR";
	
	public static final String KEY_SEQUENCING_VECTOR_LEFT = "SL";
	
	public static final String KEY_SEQUENCING_VECTOR_RIGHT = "SR";
	
	public static final String KEY_CLONING_VECTOR_LEFT = "CL";
	
	public static final String KEY_CLONING_VECTOR_RIGHT = "CR";
	
	public static final String KEY_SEQUENCE = "SQ";
	
	public static final String KEY_ACCURACY_VALUES = "AV";
	
	public static final String KEY_PROCESSING_STATUS = "PS";

	public static final Object KEY_BASECALLER = "BC";
}
