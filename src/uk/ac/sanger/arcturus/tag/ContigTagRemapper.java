package uk.ac.sanger.arcturus.tag;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.io.PrintStream;
import java.sql.*;
import java.util.Vector;

public class ContigTagRemapper {
	protected ArcturusDatabase adb;
	protected Connection conn;
	protected PreparedStatement pstmtGetMapping;
	protected PreparedStatement pstmtGetSegments;
	protected PreparedStatement pstmtGetParentTags;
	protected PreparedStatement pstmtPutChildTag;

	public ContigTagRemapper(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;

		prepareStatements();
	}

	protected void prepareStatements() throws SQLException {
		conn = adb.getPooledConnection(this);

		String sql = "select mapping_id,cstart,cfinish,pstart,pfinish,direction"
				+ " from C2CMAPPING where parent_id = ? and contig_id = ?";

		pstmtGetMapping = conn.prepareStatement(sql);

		sql = "select cstart,pstart,length from C2CSEGMENT where mapping_id = ?"
				+ " order by pstart asc";

		pstmtGetSegments = conn.prepareStatement(sql);

		sql = "select id,parent_id,TAG2CONTIG.tag_id,cstart,cfinal,strand"
				+ " from TAG2CONTIG left join CONTIGTAG using(tag_id)"
				+ " where contig_id = ? and tagtype = ?";

		pstmtGetParentTags = conn.prepareStatement(sql);

		sql = "insert into TAG2CONTIG(parent_id,contig_id,tag_id,cstart,cfinal,strand,comment)"
				+ " values(?,?,?,?,?,?,?)";

		pstmtPutChildTag = conn.prepareStatement(sql,
				Statement.RETURN_GENERATED_KEYS);
	}

	public void close() throws SQLException {
		if (pstmtGetMapping != null)
			pstmtGetMapping.close();

		if (pstmtGetSegments != null)
			pstmtGetSegments.close();

		if (pstmtGetParentTags != null)
			pstmtGetParentTags.close();

		if (pstmtPutChildTag != null)
			pstmtPutChildTag.close();

		if (conn != null)
			conn.close();
	}

	public void remapTags(int parent_id, int child_id, String[] tagtypes)
			throws SQLException {
		Mapping mapping = findMapping(parent_id, child_id);

		if (mapping == null)
			return;
		
		System.err.println("Mapping from contig " + parent_id + " to contig " + child_id + ":");
		System.err.println(mapping);
		for (int i = 0; i < mapping.segments.length; i++)
			System.err.println("\t" + mapping.segments[i]);

		for (int i = 0; i < tagtypes.length; i++)
			remapTags(mapping, tagtypes[i]);
	}

	protected Mapping findMapping(int parent_id, int child_id)
			throws SQLException {
		pstmtGetMapping.setInt(1, parent_id);
		pstmtGetMapping.setInt(2, child_id);

		ResultSet rs = pstmtGetMapping.executeQuery();

		Mapping mapping = null;

		if (rs.next()) {
			mapping = new Mapping();

			mapping.contig_id = child_id;
			mapping.parent_id = parent_id;

			int mapping_id = rs.getInt(1);
			mapping.cstart = rs.getInt(2);
			mapping.cfinish = rs.getInt(3);
			mapping.pstart = rs.getInt(4);
			mapping.pfinish = rs.getInt(5);
			mapping.forward = rs.getString(6).equalsIgnoreCase("Forward");

			mapping.segments = getParentSegments(mapping_id, mapping.forward);
		}

		rs.close();

		return mapping;
	}

	private Segment[] getParentSegments(int mapping_id, boolean forward)
			throws SQLException {
		pstmtGetSegments.setInt(1, mapping_id);

		Vector<Segment> segmentv = new Vector<Segment>();

		ResultSet rs = pstmtGetSegments.executeQuery();

		while (rs.next()) {
			int cstart = rs.getInt(1);
			int pstart = rs.getInt(2);
			int length = rs.getInt(3);

			Segment segment = new Segment(cstart, pstart, length, forward);

			segmentv.add(segment);
		}

		rs.close();

		Segment[] segments = segmentv.toArray(new Segment[0]);

		return segments;
	}

	protected void remapTags(Mapping mapping, String tagtype)
			throws SQLException {
		pstmtGetParentTags.setInt(1, mapping.parent_id);
		pstmtGetParentTags.setString(2, tagtype);

		ResultSet rs = pstmtGetParentTags.executeQuery();

		Tag tag = new Tag();

		while (rs.next()) {
			tag.id = rs.getInt(1);
			tag.contig_id = mapping.parent_id;
			tag.parent_id = rs.getInt(2);
			tag.tag_id = rs.getInt(3);
			tag.cstart = rs.getInt(4);
			tag.cfinal = rs.getInt(5);
			tag.setStrand(rs.getString(6));

			System.err.println("Original: " + tag);
			
			int rc = mapping.remapTag(tag);

			if (rc == Mapping.NO_MATCH)
				System.err.println("\t-- NO MATCH --");
			else
				System.err.println("Remapped (code = " + rc + "): " + tag);
		}

		rs.close();
	}

	class Mapping {
		public static final int NO_MATCH = 0;
		public static final int WITHIN_SINGLE_SEGMENT = 1;
		public static final int SPANS_MULTIPLE_SEGMENTS = 2;
		public static final int LEFT_END_OUTSIDE_RANGE = 3;
		public static final int RIGHT_END_OUTSIDE_RANGE = 4;
		public static final int LEFT_END_BETWEEN_SEGMENTS = 5;
		public static final int RIGHT_END_BETWEEN_SEGMENTS = 6;

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

			int segStart = findParentSegmentNumber(tag.cstart);
			int segFinish = findParentSegmentNumber(tag.cfinal);
			
			System.err.println("Tag start is in segment " + segStart);
			System.err.println("Tag end is in segment " + segFinish);
			
			if (segStart >= 0 && segFinish >= 0) {
				tag.cstart = segments[segStart].mapToChild(tag.cstart, forward);
				tag.cfinal = segments[segFinish].mapToChild(tag.cfinal, forward);
				
				tag.contig_id = contig_id;
				tag.parent_id = tag.id;
				tag.id = 0;
				
				return (segStart == segFinish) ? WITHIN_SINGLE_SEGMENT : SPANS_MULTIPLE_SEGMENTS;
			}
			
			return NO_MATCH;
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
		
		public String toString() {
			return "Mapping[parent_id=" + parent_id + ", contig_id=" + contig_id +
				", cstart=" + cstart + ", cfinish=" + cfinish + ", pstart=" + pstart +
				", pfinish=" + pfinish + ",sense=" + (forward ? "forward" : "reverse") +
				", " + (segments == null ? "no " : segments.length) + " segments]";
		}
	}

	class Segment {
		protected int cstart;
		protected int pstart;
		protected int pfinish;

		public Segment(int cstart, int pstart, int length, boolean forward) {
			if (forward) {
				this.cstart = cstart;
				this.pstart = pstart;
				this.pfinish = pstart + length - 1;
			} else {
				this.cstart = cstart + length - 1;
				this.pstart = pstart - length + 1;
				this.pfinish = pstart;
			}
		}

		public int mapToChild(int pos, boolean forward) {
			if (pos >= pstart && pos <= pfinish) {
				int offset = pos - pstart;
				return forward ? cstart + offset : cstart - offset;
			} else
				return -1;
		}
		
		public String toString() {
			return "Segment[pstart=" + pstart + ", pfinish=" + pfinish + ", cstart=" + cstart + "]";
		}
	}

	class Tag {
		public static final int FORWARD = 1;
		public static final int REVERSE = 2;
		public static final int UNKNOWN = 3;

		protected int id;
		protected int contig_id;
		protected int parent_id;
		protected int tag_id;
		protected int cstart;
		protected int cfinal;
		protected int strand;
		protected String tagtype;
		protected String tagcomment;

		public void setStrand(String s) {
			if (s == null)
				strand = UNKNOWN;
			else if (s.equalsIgnoreCase("F"))
				strand = FORWARD;
			else if (s.equalsIgnoreCase("R"))
				strand = REVERSE;
			else
				strand = UNKNOWN;
		}
		
		public String toString() {
			return "Tag[id=" + id + ", parent_id=" + parent_id + ", contig_id=" + contig_id +
				", tag_id=" + tag_id + ", cstart=" + cstart + ", cfinal=" + cfinal + "]";
		}
	}

	public static void main(String[] args) {
		String instance = null;
		String organism = null;
		int parent_id = -1;
		int child_id = -1;
		String[] tagtypes = { "TEST" };

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-parent"))
				parent_id = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-child"))
				child_id = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-tags"))
				tagtypes = args[++i].split(",");
		}

		if (instance == null || organism == null || parent_id < 0
				|| child_id < 0) {
			printUsage(System.err);
			System.exit(1);
		}

		System.err.println("Creating an ArcturusInstance for " + instance);
		System.err.println();

		try {
			ArcturusInstance ai = null;

			ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			ContigTagRemapper crm = new ContigTagRemapper(adb);

			crm.remapTags(parent_id, child_id, tagtypes);

			crm.close();
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			System.exit(0);
		}
	}

	private static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-parent\t\tContig ID of parent contig");
		ps.println("\t-child\t\tContig ID of child contig");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-tags\t\tComma-separated list of tag types to remap [default: TEST]");
	}
}
