package uk.ac.sanger.arcturus.tag;

public class Mapping {
	public static final int NO_MATCH = 0;
	public static final int LEFT_END_OUTSIDE_RANGE = -1;
	public static final int RIGHT_END_OUTSIDE_RANGE = -2;
	
	public static final int WITHIN_SINGLE_SEGMENT = 1;
	public static final int SPANS_MULTIPLE_SEGMENTS = 2;
	public static final int LEFT_END_BETWEEN_SEGMENTS = 3;
	public static final int RIGHT_END_BETWEEN_SEGMENTS = 4;
	public static final int BOTH_ENDS_BETWEEN_SEGMENTS = 5;

	public static String codeToString(int code) {
		switch (code) {
			case NO_MATCH:
				return "NO_MATCH";

			case WITHIN_SINGLE_SEGMENT:
				return "WITHIN_SINGLE_SEGMENT";

			case SPANS_MULTIPLE_SEGMENTS:
				return "SPANS_MULTIPLE_SEGMENTS";

			case LEFT_END_OUTSIDE_RANGE:
				return "LEFT_END_OUTSIDE_RANGE";

			case RIGHT_END_OUTSIDE_RANGE:
				return "RIGHT_END_OUTSIDE_RANGE";

			case LEFT_END_BETWEEN_SEGMENTS:
				return "LEFT_END_BETWEEN_SEGMENTS";

			case RIGHT_END_BETWEEN_SEGMENTS:
				return "RIGHT_END_BETWEEN_SEGMENTS";

			case BOTH_ENDS_BETWEEN_SEGMENTS:
				return "BOTH_ENDS_BETWEEN_SEGMENTS";

			default:
				return "UNKNOWN_CODE(" + code + ")";
		}
	}

	protected int parent_id;
	protected int contig_id;
	protected int cstart;
	protected int cfinish;
	protected int pstart;
	protected int pfinish;
	protected boolean forward;
	protected Segment[] segments;

	public int remapTag(Tag tag) {
		// Test whether tag lies outside this mapping
		if (tag.cfinal < pstart || tag.cstart > pfinish)
			return NO_MATCH;

		if (tag.cstart < pstart)
			return LEFT_END_OUTSIDE_RANGE;

		if (tag.cfinal > pfinish)
			return RIGHT_END_OUTSIDE_RANGE;

		int rc = NO_MATCH;

		int segStart = findParentSegmentNumber(tag.cstart);
		int segFinish = findParentSegmentNumber(tag.cfinal);

		if (segStart >= 0)
			System.err.println("Tag start is in segment " + segStart);

		if (segFinish >= 0)
			System.err.println("Tag end is in segment " + segFinish);

		if (segStart >= 0 && segFinish >= 0) {
			rc = (segStart == segFinish) ? WITHIN_SINGLE_SEGMENT
					: SPANS_MULTIPLE_SEGMENTS;
		} else {
			if (segStart < 0) {
				segStart = findParentSegmentToLeft(tag.cstart);

				if (segStart >= 0) {
					System.err.println("Tag start falls in gap after segment "
							+ segStart);
					rc = LEFT_END_BETWEEN_SEGMENTS;
				}
			}

			if (segFinish < 0) {
				segFinish = findParentSegmentToLeft(tag.cfinal);

				if (segFinish >= 0) {
					System.err.println("Tag end falls in gap after segment "
							+ segFinish);

					rc = (rc == LEFT_END_BETWEEN_SEGMENTS) ? BOTH_ENDS_BETWEEN_SEGMENTS
							: RIGHT_END_BETWEEN_SEGMENTS;
				}
			}
		}

		if (rc != NO_MATCH) {
			tag.contig_id = contig_id;
			tag.parent_id = tag.id;
			tag.id = 0;

			tag.cstart = segments[segStart].mapToChild(tag.cstart, forward,
					true);

			tag.cfinal = segments[segFinish].mapToChild(tag.cfinal, forward,
					true);
		}

		return rc;
	}

	private int findParentSegmentNumber(int pos) {
		if (segments == null)
			return -1;

		for (int i = 0; i < segments.length; i++)
			if (segments[i].pstart <= pos && segments[i].pfinish >= pos)
				return i;
			else if (segments[i].pstart > pos)
				return -1;

		return -1;
	}

	private int findParentSegmentToLeft(int pos) {
		if (segments == null)
			return -1;

		for (int i = 0; i < segments.length - 1; i++)
			if (segments[i].pfinish < pos && segments[i + 1].pstart > pos)
				return i;

		return -1;
	}

	public String toString() {
		return "Mapping[parent_id=" + parent_id + ", contig_id=" + contig_id
				+ ", cstart=" + cstart + ", cfinish=" + cfinish + ", pstart="
				+ pstart + ", pfinish=" + pfinish + ",sense="
				+ (forward ? "forward" : "reverse") + ", "
				+ (segments == null ? "no " : segments.length) + " segments]";
	}

}
