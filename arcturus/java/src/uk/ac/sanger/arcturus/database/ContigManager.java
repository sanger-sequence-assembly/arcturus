package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Mapping;
import uk.ac.sanger.arcturus.data.Segment;

import java.sql.*;
import java.util.*;

/**
 * This class manages Contig objects.
 */

public class ContigManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByID;
    private PreparedStatement pstmtByID;
    private PreparedStatement pstmtCountMappingsByContigID,pstmtMappingsByContigID, pstmtSegmentsByMappingID;

    /**
     * Creates a new ContigManager to provide contig management
     * services to an ArcturusDatabase object.
     */

    public ContigManager(ArcturusDatabase adb) throws SQLException {
	this.adb = adb;

	conn = adb.getConnection();

	String query = "select length,nreads,updated from CONTIG where contig_id = ?";
	pstmtByID = conn.prepareStatement(query);

	query = "select count(*) from MAPPING where contig_id = ?";
	pstmtCountMappingsByContigID = conn.prepareStatement(query);

	query = "select seq_id,MAPPING.mapping_id,MAPPING.cstart,cfinish,direction,count(*)" +
	    " from MAPPING left join SEGMENT using(mapping_id) " +
	    " where contig_id = ?" +
	    " group by MAPPING.mapping_id" +
	    " order by MAPPING.cstart asc, cfinish asc";
	pstmtMappingsByContigID = conn.prepareStatement(query);

	query = "select cstart,rstart,length from SEGMENT where mapping_id = ? order by cstart asc";
	pstmtSegmentsByMappingID = conn.prepareStatement(query);

	hashByID = new HashMap();
    }

    public Contig getContigByID(int id) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	return (obj == null) ? loadContigByID(id) : (Contig)obj;
    }

    private Contig loadContigByID(int id) throws SQLException {
	pstmtByID.setInt(1, id);
	ResultSet rs = pstmtByID.executeQuery();

	Contig contig = null;

	if (rs.next()) {
	    int length = rs.getInt(1);
	    int nreads = rs.getInt(2);
	    java.sql.Date updated = rs.getDate(3);

	    contig = registerNewContig(id, length, nreads, updated);
	}

	rs.close();

	return contig;
    }

    public Contig getFullContigByID(int id) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	if (obj == null)
	    return loadFullContigByID(id);

	Contig contig = (Contig)obj;

	if (contig.getMappings() == null)
	    loadMappingsForContig(contig);

	return contig;
    }

    private Contig loadFullContigByID(int id) throws SQLException {
	Contig contig = loadContigByID(id);

	loadMappingsForContig(contig);

	return contig;
   }

    private Contig registerNewContig(int id, int length, int nreads, java.sql.Date updated) {
	Contig contig = new Contig(id, length, nreads, updated, adb);

	hashByID.put(new Integer(id), contig);

	return contig;
    }

    private Contig registerNewContig(int id, int length, int nreads, java.sql.Date updated,
				     Mapping[] mappings) {
	Contig contig = new Contig(id, length, nreads, updated, mappings, adb);

	hashByID.put(new Integer(id), contig);

	return contig;
    }

    private void loadMappingsForContig(Contig contig) throws SQLException {
	int id = contig.getID();

	pstmtCountMappingsByContigID.setInt(1, id);
	ResultSet rs = pstmtCountMappingsByContigID.executeQuery();

	int nmaps = 0;
	Mapping[] mappings;

	if (rs.next()) {
	    nmaps = rs.getInt(1);
	    mappings = new Mapping[nmaps];
	} else
	    return;

	rs.close();

	pstmtMappingsByContigID.setInt(1, id);
	rs = pstmtMappingsByContigID.executeQuery();

	int kmap = 0;

	while (rs.next()) {
	    int seq_id = rs.getInt(1);
	    int mapping_id = rs.getInt(2);
	    int cstart = rs.getInt(3);
	    int cfinish = rs.getInt(4);
	    int direction = rs.getString(5).equals("Forward") ? Mapping.FORWARD : Mapping.REVERSE;
	    int nsegs = rs.getInt(6);

	    Sequence sequence = adb.getSequenceBySequenceID(seq_id);

	    Mapping mapping = new Mapping(sequence, cstart, cfinish, direction, nsegs);

	    pstmtSegmentsByMappingID.setInt(1, mapping_id);
	    ResultSet seg_rs = pstmtSegmentsByMappingID.executeQuery();

	    while (seg_rs.next()) {
		int seg_cstart = seg_rs.getInt(1);
		int seg_rstart = seg_rs.getInt(2);
		int seg_length = seg_rs.getInt(3);

		Segment segment= new Segment(seg_cstart, seg_rstart, seg_length);

		mapping.addSegment(segment);
	    }

	    seg_rs.close();

	    mappings[kmap++] = mapping;
	}

	rs.close();

	contig.setMappings(mappings);
    }
}
