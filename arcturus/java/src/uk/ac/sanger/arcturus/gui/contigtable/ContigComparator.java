package uk.ac.sanger.arcturus.gui.contigtable;

import java.util.Comparator;
import java.util.Date;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

public class ContigComparator implements Comparator {
    public static final int BY_LENGTH = 1;
    public static final int BY_READS = 2;
    public static final int BY_CREATION_DATE = 3;
    public static final int BY_ID = 4;
    public static final int BY_NAME = 5;

    protected boolean ascending;
    protected int type;
    protected boolean groupByProject;

    public ContigComparator() {
	this(BY_LENGTH, true, false);
    }

    public ContigComparator(int type, boolean ascending) {
	this(type, ascending, false);
    }

    public ContigComparator(int type, boolean ascending, boolean groupByProject) {
	this.type = type;
	this.ascending = ascending;
	this.groupByProject = groupByProject;
    }

    public void setType(int type) {
	this.type = type;
    }

    public int getType() { return type; }

    public void setAscending(boolean ascending) {
	this.ascending = ascending;
    }

    public boolean isAscending() { return ascending; }

    public void setGroupByProject(boolean groupByProject) {
	this.groupByProject = groupByProject;
    }

    public boolean isGroupingByProject() { return groupByProject; }

    public boolean equals(Object that) {
	return (that instanceof ContigComparator && (ContigComparator)that == this);
    }

    public int compare(Object o1, Object o2) {
	Contig c1 = (Contig)o1;
	Contig c2 = (Contig)o2;

	if (groupByProject) {
	    Project project1 = c1.getProject();
	    Project project2 = c2.getProject();

	    int project1id = (project1 == null) ? -1 : project1.getID();
	    int project2id = (project2 == null) ? -1 : project2.getID();

	    if (project1id == 0 && project2id != 0)
		return 1;

	    if (project1id != 0 && project2id == 0)
		return -1;

	    int diff = project1id - project2id;

	    if (diff < 0)
	    return -1;

	    if (diff > 0)
	    return 1;
	}

	switch (type) {
	case BY_LENGTH:
	    return compareByLength(c1, c2);

	case BY_READS:
	    return compareByReads(c1, c2);

	case BY_CREATION_DATE:
	    return compareByCreationDate(c1, c2);

	case BY_ID:
	    return compareByID(c1, c2);

	case BY_NAME:
	    return compareByName(c1, c2);

	default:
	    return compareByLength(c1, c2);
	}
    }

    protected int compareByLength(Contig c1, Contig c2) {
	int diff = c1.getLength() - c2.getLength();

	if (!ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByReads(Contig c1, Contig c2) {
	int diff = c1.getReadCount() - c2.getReadCount();

	if (!ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByCreationDate(Contig c1, Contig c2) {
	int diff = c1.getCreated().compareTo(c2.getCreated());

	if (!ascending)
	    diff = -diff;

	return diff;
    }

    protected int compareByID(Contig c1, Contig c2) {
	int diff = c1.getID() - c2.getID();

	if (ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByName(Contig c1, Contig c2) {
	int diff = c1.getName().compareTo(c2.getName());

	if (ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }
}
