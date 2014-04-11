// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
