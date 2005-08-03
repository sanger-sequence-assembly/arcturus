package uk.ac.sanger.arcturus.gui.projecttable;

import java.util.Comparator;
import java.util.Date;

public class ProjectComparator implements Comparator {
    public static final int BY_TOTAL_LENGTH = 1;
    public static final int BY_CONTIGS = 2;
    public static final int BY_MAXIMUM_LENGTH = 3;
    public static final int BY_READS = 4;
    public static final int BY_DATE = 5;

    protected boolean ascending;
    protected int type;

    public ProjectComparator() {
	this(BY_TOTAL_LENGTH, true);
    }

    public ProjectComparator(int type, boolean ascending) {
	this.type = type;
	this.ascending = ascending;
    }

    public void setType(int type) {
	this.type = type;
    }

    public int getType() { return type; }

    public void setAscending(boolean ascending) {
	this.ascending = ascending;
    }

    public boolean isAscending() { return ascending; }

    public boolean equals(Object that) {
	return (that instanceof ProjectComparator && (ProjectComparator)that == this);
    }

    public int compare(Object o1, Object o2) {
	ProjectProxy p1 = (ProjectProxy)o1;
	ProjectProxy p2 = (ProjectProxy)o2;


	switch (type) {
	case BY_TOTAL_LENGTH:
	    return compareByTotalLength(p1, p2);

	case BY_MAXIMUM_LENGTH:
	    return compareByMaximumLength(p1, p2);

	case BY_CONTIGS:
	    return compareByContigs(p1, p2);

	case BY_READS:
	    return compareByReads(p1, p2);

	case BY_DATE:
	    return compareByNewestContigCreated(p1, p2);

	default:
	    return compareByMaximumLength(p1, p2);
	}
    }

    protected int compareByTotalLength(ProjectProxy p1, ProjectProxy p2) {
	int diff = p1.getTotalLength() - p2.getTotalLength();

	if (!ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByMaximumLength(ProjectProxy p1, ProjectProxy p2) {
	int diff = p1.getMaximumLength() - p2.getMaximumLength();

	if (!ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByContigs(ProjectProxy p1, ProjectProxy p2) {
	int diff = p1.getContigCount() - p2.getContigCount();

	if (!ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByReads(ProjectProxy p1, ProjectProxy p2) {
	int diff = p1.getReadCount() - p2.getReadCount();

	if (!ascending)
	    diff = -diff;

	if (diff < 0)
	    return -1;

	if (diff > 0)
	    return 1;

	return 0;
    }

    protected int compareByNewestContigCreated(ProjectProxy p1, ProjectProxy p2) {
	int diff = p1.getNewestContigCreated().compareTo(p2.getNewestContigCreated());

	if (!ascending)
	    diff = -diff;

	return diff;
    }
}
