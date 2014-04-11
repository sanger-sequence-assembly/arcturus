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

package uk.ac.sanger.arcturus.contigtransfer;

public class ContigTransferRequestException extends Exception {
	public static final int UNKNOWN = -1;
	public static final int OK = 0;
	public static final int USER_NOT_AUTHORISED = 1;
	public static final int USER_NOT_AUTHORIZED = USER_NOT_AUTHORISED;
	public static final int CONTIG_NOT_CURRENT = 2;
	public static final int NO_SUCH_CONTIG = 3;
	public static final int NO_SUCH_PROJECT = 4;
	public static final int CONTIG_HAS_MOVED = 5;
	public static final int PROJECT_IS_LOCKED = 6;
	public static final int CONTIG_ALREADY_REQUESTED = 7;
	public static final int NO_SUCH_REQUEST = 8;
	public static final int USER_IS_NULL = 9;
	public static final int SQL_INSERT_FAILED = 10;
	public static final int SQL_UPDATE_FAILED = 11;
	public static final int INVALID_STATUS_CHANGE = 13;
	public static final int CONTIG_ALREADY_IN_DESTINATION_PROJECT = 14;
	
	protected int type = UNKNOWN;
	protected ContigTransferRequest request;
	
	public ContigTransferRequestException(int type, String message) {
		super(message);
		this.type = type;
	}
	
	public ContigTransferRequestException(int type) {
		this(type, null);
	}
	
	public ContigTransferRequestException(ContigTransferRequest request, int type, String message) {
		super(message);
		this.type = type;
		this.request = request;
	}
	
	public ContigTransferRequestException(ContigTransferRequest request, int type) {
		this(request, type, null);
	}

	public int getType() {
		return type;
	}
	
	public String getTypeAsString() {
		switch (type) {
			case USER_NOT_AUTHORISED:
				return "User not authorised";
				
			case CONTIG_NOT_CURRENT:
				return "Contig not current";
				
			case NO_SUCH_CONTIG:
				return "No such contig";
				
			case NO_SUCH_PROJECT:
				return "No such project";
				
			case CONTIG_HAS_MOVED:
				return "Contig has moved";
				
			case PROJECT_IS_LOCKED:
				return "Project is locked";
				
			case CONTIG_ALREADY_REQUESTED:
				return "Contig already requested";
				
			case NO_SUCH_REQUEST:
				return "No such request";
				
			case USER_IS_NULL:
				return "User is null";
				
			case SQL_INSERT_FAILED:
				return "SQL INSERT failed";
				
			case SQL_UPDATE_FAILED:
				return "SQL UPDATE failed";
				
			case INVALID_STATUS_CHANGE:
				return "Invalid status change";
				
			case CONTIG_ALREADY_IN_DESTINATION_PROJECT:
				return "Contig already in destination project";
				
			default:
				return "Unknown (code=" + type + ")";
		}
	}
	
	public ContigTransferRequest getRequest() {
		return request;
	}
	
	public void setRequest(ContigTransferRequest request) {
		if (this.request == null)
			this.request = request;
	}
}
