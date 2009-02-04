package uk.ac.sanger.arcturus.tag;

import java.sql.*;
import java.util.*;

import java.io.PrintStream;
import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigTagChecker {
	private ArcturusDatabase adb;

	private Connection conn = null;

	private List<Integer> contigIDs = null;

	private PreparedStatement pstmtTag;
	private PreparedStatement pstmtParentMapping;
	private PreparedStatement pstmtParentSegment;

	public ContigTagChecker(String[] args) throws NamingException, SQLException {
		String instance = null;
		String organism = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-contigs"))
				contigIDs = parseContigIDs(args[++i]);
		}

		if (instance == null || organism == null || contigIDs == null
				|| contigIDs.isEmpty()) {
			printUsage(System.err);
			System.exit(1);
		}

		System.err.println("Creating an ArcturusInstance for " + instance);
		System.err.println();

		ArcturusInstance ai = null;

		ai = ArcturusInstance.getInstance(instance);

		System.err.println("Creating an ArcturusDatabase for " + organism);
		System.err.println();

		adb = ai.findArcturusDatabase(organism);

		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);

		conn = adb.getConnection();

		if (conn == null) {
			System.err.println("Connection is undefined");
			printUsage(System.err);
			System.exit(1);
		}

		prepareStatements();
	}

	private List<Integer> parseContigIDs(String string) {
		List<Integer> contigs = new Vector<Integer>();

		String[] words = string.split(",");

		for (String word : words) {
			try {
				contigs.add(new Integer(word));
			} catch (NumberFormatException nfe) {
				System.err.println("Not parsable as an integer: \"" + word
						+ "\"");
			}
		}

		return contigs;
	}

	private void prepareStatements() throws SQLException {
		String query = "select TAG2CONTIG.tag_id,cstart,cfinal,strand,tagtype,tagcomment"
				+ " from TAG2CONTIG left join CONTIGTAG using(tag_id)"
				+ " where contig_id = ? and tagtype != 'ASIT' order by cstart asc, cfinal asc";

		pstmtTag = conn.prepareStatement(query);

		query = "select parent_id,mapping_id,cstart,cfinish,pstart,pfinish,direction"
				+ " from C2CMAPPING where contig_id = ? order by cstart asc, cfinish asc";

		pstmtParentMapping = conn.prepareStatement(query);

		query = "select cstart,pstart,length from C2CSEGMENT where mapping_id = ?"
				+ " order by pstart asc";

		pstmtParentSegment = conn.prepareStatement(query);
	}

	private void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-contigs\tComma-separated list of contigs to check");
	}

	public void run() throws SQLException {
		for (int contig_id : contigIDs) {
			analyseContig(contig_id);
		}
	}

	@SuppressWarnings("unchecked")
	private void analyseContig(int contig_id) throws SQLException {
		List<Mapping> mappings = getParentMappings(contig_id);

		if (mappings == null || mappings.isEmpty()) {
			System.err.println("Contig " + contig_id + " has no parents");
			return;
		}

		List<Tag> tags = getContigTags(contig_id);

		Collections.sort(tags);

		List<Tag> remappedTags = new Vector<Tag>();

		for (Mapping mapping : mappings) {
			List<Tag> newtags = analyseParentToChildMapping(mapping, contig_id,
					tags);

			if (newtags != null)
				remappedTags.addAll(newtags);
		}

		Collections.sort(remappedTags);

		System.out
				.println("----------------------------------------------------------------------");

		System.out.println("\nTags in child contig:");

		for (Tag tag : tags)
			System.out.println("\n" + tag);

		System.out.println("\nRemapped tags in parent contigs:");

		for (Tag tag : remappedTags)
			System.out.println("\n" + tag + "\n// From " + tag.parent.contig_id
					+ "\t" + tag.parent.cstart + "\t" + tag.parent.cfinal);
	}

	@SuppressWarnings("unchecked")
	private List<Tag> analyseParentToChildMapping(Mapping mapping,
			int child_id, List<Tag> childTags) throws SQLException {
		List<Tag> parentTags = getContigTags(mapping.parent_id);

		if (parentTags == null || parentTags.size() == 0)
			return null;

		System.out.println("\nTesting mapping from contig " + mapping.parent_id
				+ " to contig " + child_id);

		boolean forward = mapping.direction == Mapping.FORWARD;

		System.out.println("Overall mapping: [" + mapping.pstart + " -- "
				+ mapping.pfinish + "] --> [" + mapping.cstart + " -- "
				+ mapping.cfinish + "] in " + (forward ? "forward" : "reverse")
				+ " sense");

		System.out.println("Segments:");
		for (Segment segment : mapping.segments)
			System.out.println(segment.toString(forward));

		List<Tag> remappedTags = remapParentTags(parentTags, mapping);

		Collections.sort(remappedTags);

		for (Tag remappedTag : remappedTags) {
			System.out.println("\n" + remappedTag.parent + "\n" + remappedTag);
		}

		return remappedTags;
	}

	private List<Tag> remapParentTags(List<Tag> parentTags, Mapping mapping) {
		List<Tag> remappedTags = new Vector<Tag>(parentTags.size());

		for (Tag parentTag : parentTags)
			remappedTags.add(remapParentTag(parentTag, mapping));

		return remappedTags;
	}

	private Tag remapParentTag(Tag parentTag, Mapping mapping) {
		int pstart = parentTag.cstart;
		int pfinal = parentTag.cfinal;

		int cstart = getChildPosition(pstart, mapping);
		int cfinal = getChildPosition(pfinal, mapping);

		boolean forward = mapping.direction == Mapping.FORWARD;

		Tag remappedTag = new Tag();

		remappedTag.contig_id = mapping.contig_id;
		remappedTag.parent = parentTag;

		remappedTag.cstart = forward ? cstart : cfinal;
		remappedTag.cfinal = forward ? cfinal : cstart;
		remappedTag.strand = parentTag.strand;
		remappedTag.tag_id = parentTag.tag_id;
		remappedTag.tagtype = parentTag.tagtype;
		remappedTag.tagcomment = parentTag.tagcomment;

		return remappedTag;
	}

	private int getChildPosition(int p, Mapping mapping) {
		if (p < mapping.pstart || p > mapping.pfinish)
			return -1;

		boolean forward = mapping.direction == Mapping.FORWARD;

		for (Segment segment : mapping.segments) {
			int c = getChildPosition(p, segment, forward);
			if (c > 0)
				return c;
		}

		return -1;
	}

	private int getChildPosition(int p, Segment segment, boolean forward) {
		int pstart = forward ? segment.pstart : segment.pstart - segment.length
				+ 1;
		int pfinish = forward ? segment.pstart + segment.length - 1
				: segment.pstart;

		if (p < pstart || p > pfinish)
			return -1;

		return forward ? segment.cstart + (p - segment.pstart) : segment.cstart
				- (p - segment.pstart);
	}

	private List<Mapping> getParentMappings(int contig_id) throws SQLException {
		List<Mapping> mappings = new Vector<Mapping>();

		pstmtParentMapping.setInt(1, contig_id);

		ResultSet rs = pstmtParentMapping.executeQuery();

		while (rs.next()) {
			Mapping mapping = new Mapping();

			mapping.contig_id = contig_id;
			mapping.parent_id = rs.getInt(1);
			int mapping_id = rs.getInt(2);
			mapping.cstart = rs.getInt(3);
			mapping.cfinish = rs.getInt(4);
			mapping.pstart = rs.getInt(5);
			mapping.pfinish = rs.getInt(6);
			mapping.direction = rs.getString(7).equalsIgnoreCase("Forward") ? Mapping.FORWARD
					: Mapping.REVERSE;

			Segment[] segments = getParentSegments(mapping_id);

			mapping.segments = segments;

			mappings.add(mapping);
		}

		return mappings;
	}

	private Segment[] getParentSegments(int mapping_id) throws SQLException {
		pstmtParentSegment.setInt(1, mapping_id);

		Vector<Segment> segmentv = new Vector<Segment>();

		ResultSet rs = pstmtParentSegment.executeQuery();

		while (rs.next()) {
			Segment segment = new Segment();
			segment.cstart = rs.getInt(1);
			segment.pstart = rs.getInt(2);
			segment.length = rs.getInt(3);

			segmentv.add(segment);
		}

		rs.close();

		Segment[] segments = segmentv.toArray(new Segment[0]);

		return segments;
	}

	private List<Tag> getContigTags(int contig_id) throws SQLException {
		pstmtTag.setInt(1, contig_id);

		Vector<Tag> tagv = new Vector<Tag>();

		ResultSet rs = pstmtTag.executeQuery();

		while (rs.next()) {
			Tag tag = new Tag();

			tag.contig_id = contig_id;

			tag.tag_id = rs.getInt(1);
			tag.cstart = rs.getInt(2);
			tag.cfinal = rs.getInt(3);

			String s = rs.getString(4);

			if (s.equalsIgnoreCase("F"))
				tag.strand = Tag.FORWARD;
			else if (s.equalsIgnoreCase("R"))
				tag.strand = Tag.REVERSE;
			else
				tag.strand = Tag.UNKNOWN;

			tag.tagtype = rs.getString(5);
			tag.tagcomment = rs.getString(6);

			tagv.add(tag);
		}

		rs.close();

		return tagv;
	}

	public static void main(String[] args) {
		try {
			ContigTagChecker checker = new ContigTagChecker(args);
			checker.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
		System.exit(0);
	}

	class Mapping {
		public static final int FORWARD = 1;
		public static final int REVERSE = 2;

		protected int parent_id;
		protected int contig_id;
		protected int cstart;
		protected int cfinish;
		protected int pstart;
		protected int pfinish;
		protected int direction;
		protected Segment[] segments;
	}

	class Segment {
		protected int cstart;
		protected int pstart;
		protected int length;

		public String toString(boolean forward) {
			int pfinish = forward ? pstart + length - 1 : pstart - length + 1;
			int cfinish = cstart + length - 1;

			return "[" + pstart + " -- " + pfinish + "] --> [" + cstart
					+ " -- " + cfinish + "]";
		}
	}

	class Tag implements Comparable {
		public static final int FORWARD = 1;
		public static final int REVERSE = 2;
		public static final int UNKNOWN = 3;

		protected int contig_id;
		protected int tag_id;
		protected int cstart;
		protected int cfinal;
		protected int strand;
		protected String tagtype;
		protected String tagcomment;

		protected Tag parent = null;

		public String toString() {
			return "" + contig_id + "\t" + cstart + "\t" + cfinal + "\t"
					+ tag_id + "\t" + strand + "\t" + tagtype + "\t\""
					+ tagcomment + "\"";
		}

		public int compareTo(Object o) {
			Tag that = (Tag) o;

			int d = this.cstart - that.cstart;

			if (d != 0)
				return d;
			else
				return this.cfinal - that.cfinal;
		}

		public boolean rangeMatches(Tag that) {
			return that != null && this.cstart == that.cstart
					&& this.cfinal == that.cfinal;
		}

		public boolean rangeAndTypeMatches(Tag that) {
			return rangeMatches(that)
					&& this.tagtype.equalsIgnoreCase(that.tagtype);
		}
	}
}
