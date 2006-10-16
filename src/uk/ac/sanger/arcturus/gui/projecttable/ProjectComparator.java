package uk.ac.sanger.arcturus.gui.projecttable;

import java.util.Comparator;
import java.util.Date;
import java.util.regex.*;

public class ProjectComparator implements Comparator {
	public static final int BY_TOTAL_LENGTH = 1;
	public static final int BY_CONTIGS = 2;
	public static final int BY_MAXIMUM_LENGTH = 3;
	public static final int BY_READS = 4;
	public static final int BY_CONTIG_CREATED_DATE = 5;
	public static final int BY_OWNER = 6;
	public static final int BY_CONTIG_UPDATED_DATE = 7;
	public static final int BY_PROJECT_UPDATED_DATE = 8;
	public static final int BY_NAME = 9;

	protected boolean ascending;
	protected int type;

	protected Pattern pattern;

	public ProjectComparator() {
		this(BY_TOTAL_LENGTH, true);
	}

	public ProjectComparator(int type, boolean ascending) {
		this.type = type;
		this.ascending = ascending;
		pattern = Pattern.compile("^(.*\\D+)(\\d+)$");
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

	public boolean equals(Object that) {
		return (that instanceof ProjectComparator && (ProjectComparator) that == this);
	}

	public int compare(Object o1, Object o2) {
		ProjectProxy p1 = (ProjectProxy) o1;
		ProjectProxy p2 = (ProjectProxy) o2;

		switch (type) {
			case BY_TOTAL_LENGTH:
				return compareByTotalLength(p1, p2);

			case BY_MAXIMUM_LENGTH:
				return compareByMaximumLength(p1, p2);

			case BY_CONTIGS:
				return compareByContigs(p1, p2);

			case BY_READS:
				return compareByReads(p1, p2);

			case BY_CONTIG_CREATED_DATE:
				return compareByNewestContigCreated(p1, p2);

			case BY_CONTIG_UPDATED_DATE:
				return compareByMostRecentContigUpdated(p1, p2);

			case BY_PROJECT_UPDATED_DATE:
				return compareByProjectUpdated(p1, p2);

			case BY_OWNER:
				return compareByOwner(p1, p2);

			case BY_NAME:
				return compareByName(p1, p2);

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
		Date d1 = (p1 == null) ? null : p1.getNewestContigCreated();
		Date d2 = (p2 == null) ? null : p2.getNewestContigCreated();

		return compareByDate(d1, d2);
	}

	protected int compareByMostRecentContigUpdated(ProjectProxy p1,
			ProjectProxy p2) {
		Date d1 = (p1 == null) ? null : p1.getMostRecentContigUpdated();
		Date d2 = (p2 == null) ? null : p2.getMostRecentContigUpdated();

		return compareByDate(d1, d2);
	}

	protected int compareByProjectUpdated(ProjectProxy p1, ProjectProxy p2) {
		Date d1 = (p1 == null) ? null : p1.getProjectUpdated();
		Date d2 = (p2 == null) ? null : p2.getProjectUpdated();

		return compareByDate(d1, d2);
	}

	protected int compareByDate(Date d1, Date d2) {
		if (d1 == null && d2 == null)
			return 0;

		if (d1 == null)
			return 1;

		if (d2 == null)
			return -1;

		int diff = d1.compareTo(d2);

		if (!ascending)
			diff = -diff;

		return diff;
	}

	protected int compareByOwner(ProjectProxy p1, ProjectProxy p2) {
		if (p1 == null && p2 == null)
			return 0;

		if (p1 == null || p1.getOwner() == null)
			return 1;

		if (p2 == null || p2.getOwner() == null)
			return -1;

		int diff = p2.getOwner().compareTo(p1.getOwner());

		return ascending ? diff : -diff;
	}

	protected int compareByName(ProjectProxy p1, ProjectProxy p2) {
		if (p1 == null && p2 == null)
			return 0;

		if (p1 == null || p1.getName() == null)
			return 1;

		if (p2 == null || p2.getName() == null)
			return -1;

		String name1 = p1.getName();
		String name2 = p2.getName();

		Matcher matcher1 = pattern.matcher(name1);
		Matcher matcher2 = pattern.matcher(name2);

		int diff;

		if (matcher1.find() && matcher2.find()) {
			String stem1 = matcher1.group(1);
			String stem2 = matcher2.group(1);

			diff = stem2.compareTo(stem1);

			if (diff == 0) {
				int suffix1 = Integer.parseInt(matcher1.group(2));
				int suffix2 = Integer.parseInt(matcher2.group(2));

				diff = suffix2 - suffix1;
			}
		} else
			diff = name2.compareTo(name1);

		return ascending ? diff : -diff;
	}
}
