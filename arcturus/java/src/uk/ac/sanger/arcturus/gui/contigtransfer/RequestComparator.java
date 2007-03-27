package uk.ac.sanger.arcturus.gui.contigtransfer;

import java.util.Comparator;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.contigtransfer.*;

public class RequestComparator  implements Comparator {
	protected boolean ascending;
	protected int type;

	public RequestComparator() {
		this(ContigTransferTableModel.COLUMN_OPENED_DATE, true);
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
		
		return 0;
	}

}
