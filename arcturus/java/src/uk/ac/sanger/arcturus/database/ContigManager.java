package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.*;

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
    private PreparedStatement pstmtReadDataByContigID;

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

	query = "select READS.read_id,READS.readname,asped,strand,primer,chemistry," +
	    "           TEMPLATE.template_id,TEMPLATE.name,TEMPLATE.ligation_id,SEQ2READ.seq_id,SEQ2READ.version" +
	    " from READS,TEMPLATE,SEQ2READ,MAPPING" +
	    " where READS.read_id=SEQ2READ.read_id and READS.template_id=TEMPLATE.template_id and SEQ2READ.seq_id=MAPPING.seq_id" +
	    " and contig_id = ?";
	pstmtReadDataByContigID = conn.prepareStatement(query);

	hashByID = new HashMap();
    }

    public Contig getContigByID(int id) throws SQLException {
	return getContigByID(id, true);
    }

    public Contig getContigByID(int id, boolean autoload) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	return (obj == null && autoload) ? loadContigByID(id) : (Contig)obj;
    }

    private Contig loadContigByID(int id) throws SQLException {
	pstmtByID.setInt(1, id);
	ResultSet rs = pstmtByID.executeQuery();

	Contig contig = null;

	if (rs.next()) {
	    int length = rs.getInt(1);
	    int nreads = rs.getInt(2);
	    java.sql.Date updated = rs.getDate(3);

	    contig = createAndRegisterNewContig(id, length, nreads, updated);
	}

	rs.close();

	return contig;
    }

    public Contig getFullContigByID(int id) throws SQLException {
	return getFullContigByID(id, true);
    }

    public Contig getFullContigByID(int id, boolean autoload) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	if (obj == null)
	    return autoload ? loadFullContigByID(id) : null;

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

    private Contig createAndRegisterNewContig(int id, int length, int nreads, java.sql.Date updated) {
	Contig contig = new Contig(id, length, nreads, updated, adb);

	registerNewContig(contig);

	return contig;
    }

    private Contig createAndRegisterNewContig(int id, int length, int nreads, java.sql.Date updated,
				     Mapping[] mappings) {
	Contig contig = new Contig(id, length, nreads, updated, mappings, adb);

	registerNewContig(contig);

	return contig;
    }

    void registerNewContig(Contig contig) {
	hashByID.put(new Integer(contig.getID()), contig);
    }

    private void loadMappingsForContig(Contig contig) throws SQLException {
	loadMappingsForContig(contig, true);
    }

    private void loadMappingsForContig(Contig contig, boolean fast) throws SQLException {
	if (fast)
	    fastLoadMappingsForContig(contig);
	else
	    slowLoadMappingsForContig(contig);
    }

    private void slowLoadMappingsForContig(Contig contig) throws SQLException {
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

     private void fastLoadMappingsForContig(Contig contig) throws SQLException {
	int id = contig.getID();

	pstmtReadDataByContigID.setInt(1, id);

	ResultSet rs = pstmtReadDataByContigID.executeQuery();

	while (rs.next()) {
	    int ligation_id = rs.getInt(9);
	    Ligation ligation = adb.getLigationByID(ligation_id);

	    int template_id = rs.getInt(7);
	    Template template = adb.getTemplateByID(template_id, false);
	    if (template == null) {
		System.err.print('T');
		String template_name = rs.getString(8);
		template = new Template(template_name, template_id, ligation, adb);
		adb.registerNewTemplate(template);
	    }

	    int read_id = rs.getInt(1);
	    Read read = adb.getReadByID(read_id, false);
	    if (read == null) {
		System.err.print('R');
		String readname = rs.getString(2);
		java.sql.Date asped = rs.getDate(3);
		int strand = adb.parseStrand(rs.getString(4));
		int primer = adb.parsePrimer(rs.getString(5));
		int chemistry = adb.parseChemistry(rs.getString(6));

		read = new Read(readname, read_id, template, asped, strand, primer, chemistry, adb);

		adb.registerNewRead(read);
	    }

	    int seq_id = rs.getInt(10);
	    Sequence sequence = adb.getSequenceBySequenceID(seq_id, false);
	    if (sequence == null) {
		System.err.print('S');
		int version = rs.getInt(11);
		sequence = new Sequence(seq_id, read, null, null, version);
		adb.registerNewSequence(sequence);
	    }
	}

	System.err.println();

	rs.close();
     }
}
