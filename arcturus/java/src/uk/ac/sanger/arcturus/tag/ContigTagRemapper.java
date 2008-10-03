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

	public void remapTags(int parent_id, int child_id, String[] tagtypes, boolean store)
			throws SQLException {
		Mapping mapping = findMapping(parent_id, child_id);

		if (mapping == null)
			return;

		System.err.println("Mapping from contig " + parent_id + " to contig "
				+ child_id + ":");
		System.err.println(mapping);
		for (int i = 0; i < mapping.segments.length; i++)
			System.err.println("\t" + mapping.segments[i]);

		for (int i = 0; i < tagtypes.length; i++)
			remapTags(mapping, tagtypes[i],store);
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

	protected void remapTags(Mapping mapping, String tagtype, boolean store)
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

			System.err.println("\nOriginal: " + tag);

			int rc = mapping.remapTag(tag);

			switch (rc) {
				case Mapping.NO_MATCH:
				case Mapping.LEFT_END_OUTSIDE_RANGE:
				case Mapping.RIGHT_END_OUTSIDE_RANGE:
					System.err.println("\tUnable to re-map: " + Mapping.codeToString(rc));
					break;
			
				case Mapping.WITHIN_SINGLE_SEGMENT:
				case Mapping.SPANS_MULTIPLE_SEGMENTS:
				case Mapping.LEFT_END_BETWEEN_SEGMENTS:
				case Mapping.RIGHT_END_BETWEEN_SEGMENTS:
				case Mapping.BOTH_ENDS_BETWEEN_SEGMENTS:
					if (store)
						storeTag(tag);
					
					System.err.println("Remapped (" + Mapping.codeToString(rc) + "): " + tag);
					break;
					
				default:
					System.err.println("\tUnknown code returned by remapTag: " + rc);
					break;
			}
		}

		rs.close();
	}
	
	private void storeTag(Tag tag) throws SQLException {
		//"insert into TAG2CONTIG(parent_id,contig_id,tag_id,cstart,cfinal,strand,comment)"
		//	+ " values(?,?,?,?,?,?,?)";

		pstmtPutChildTag.setInt(1, tag.parent_id);
		pstmtPutChildTag.setInt(2, tag.contig_id);
		pstmtPutChildTag.setInt(3, tag.tag_id);
		pstmtPutChildTag.setInt(4, tag.cstart);
		pstmtPutChildTag.setInt(5, tag.cfinal);
		pstmtPutChildTag.setString(6, tag.getStrandAsString());
		
		if (tag.tagcomment == null)
			pstmtPutChildTag.setNull(7, Types.VARCHAR);
		else
			pstmtPutChildTag.setString(7, tag.tagcomment);

		int rc = pstmtPutChildTag.executeUpdate();
		
		if (rc == 1) {
			ResultSet rs = pstmtPutChildTag.getGeneratedKeys();
			
			if (rs.next())
				tag.id = rs.getInt(1);
			
			rs.close();
		}
	}

	public static void main(String[] args) {
		String instance = null;
		String organism = null;
		int parent_id = -1;
		int child_id = -1;
		String[] tagtypes = { "TEST" };
		boolean store = false;

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
			
			if (args[i].equalsIgnoreCase("-store"))
				store = true;
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

			crm.remapTags(parent_id, child_id, tagtypes, store);

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
		ps.println("\t-store\t\tStore the re-mapped tags");
	}
}
