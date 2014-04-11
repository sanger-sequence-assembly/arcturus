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

package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.util.Comparator;
import java.util.Date;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.contigtransfer.*;

public class RequestComparator  implements Comparator {
	protected boolean ascending;
	protected int type;

	public RequestComparator(int mode) {
		this(ContigTransferTableModel.COLUMN_OPENED_DATE,  true);
	}

	public RequestComparator(int type, boolean ascending) {
		this.type = type;
		this.ascending = ascending;
	}

	public void setType(int type) {
		this.type = type;
	}

	public int getType() {
		return type;
	}

	public void setAscending(boolean ascending) {
		this.ascending = ascending;
	}

	public boolean isAscending() {
		return ascending;
	}

	public int compare(Object o1, Object o2) {
		ContigTransferRequest req1 = (ContigTransferRequest)o1;
		ContigTransferRequest req2 = (ContigTransferRequest)o2;
		
		switch (type) {
			case ContigTransferTableModel.COLUMN_REQUEST_ID:
				return compareIntegers(req1.getRequestID(), req2.getRequestID());

			case ContigTransferTableModel.COLUMN_CONTIG_ID:
				return compareIntegers(req1.getContig().getID(), req2.getContig().getID());

			case ContigTransferTableModel.COLUMN_OLD_PROJECT:
				return compareStrings(req1.getOldProject().getName(), req2.getOldProject().getName());

			case ContigTransferTableModel.COLUMN_NEW_PROJECT:
				return compareStrings(req1.getNewProject().getName(), req2.getNewProject().getName());

			case ContigTransferTableModel.COLUMN_REQUESTER:
				return comparePersons(req1.getContigOwner(), req2.getContigOwner());

			case ContigTransferTableModel.COLUMN_OPENED_DATE:
				return compareDates(req1.getOpenedDate(), req2.getOpenedDate());

			case ContigTransferTableModel.COLUMN_REVIEWER:
				return comparePersons(req1.getReviewer(), req2.getReviewer());

			case ContigTransferTableModel.COLUMN_REVIEWED_DATE:
				return compareDates(req1.getReviewedDate(), req2.getReviewedDate());

			case ContigTransferTableModel.COLUMN_STATUS:
				return compareIntegers(req1.getStatus(), req2.getStatus());

			case ContigTransferTableModel.COLUMN_CLOSED_DATE:
				return compareDates(req1.getClosedDate(), req2.getClosedDate());

			default:
				return 0;
		}
	}

	private int compareDates(Date date1, Date date2) {
		if (date1 == null && date2 == null)
			return 0;

		int diff = 0;
		
		if (date1 == null)
			diff = 1;
		else if (date2 == null)
			diff = -1;
		else
			diff = date1.compareTo(date2);

		return ascending ? diff : -diff;
	}

	private int comparePersons(Person person1, Person person2) {
		if (person1 == null && person2 == null)
			return 0;
		
		int diff = 0;
		
		if (person1  == null)
			diff = -1;
		else if (person2 == null)
			diff = 1;
		else
			diff = person2.compareTo(person1);
		
		return ascending ? diff : -diff;
	}

	private int compareStrings(String str1, String str2) {
		if (str1 == null && str2 == null)
			return 0;
		
		int diff = 0;
		
		if (str1 == null)
			diff = 1;
		else if (str2 == null)
			diff = -1;
		else
			diff = str1.compareTo(str2);
		
		return ascending ? diff : -diff;
	}

	private int compareIntegers(int i1, int i2) {
		int diff = i2 - i1;
		
		return ascending ? diff : -diff;
	}

}
