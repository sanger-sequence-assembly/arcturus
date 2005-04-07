package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.*;

import java.sql.*;
import java.util.*;
import java.util.zip.Inflater;
import java.util.zip.DataFormatException;

/**
 * This class manages Contig objects.
 */

public class ContigManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByID;
    private PreparedStatement pstmtByID;
    private PreparedStatement pstmtCountContigsByProject, pstmtGetContigsByProject;
    private PreparedStatement pstmtCountMappingsByContigID,pstmtMappingsByContigID, pstmtSegmentsByContigID;
    private PreparedStatement pstmtReadDataByContigID,pstmtFullReadDataByContigID;
    private PreparedStatement pstmtConsensusByID;
    private PreparedStatement pstmtReadDataByProjectID,pstmtFullReadDataByProjectID;
    private PreparedStatement pstmtConsensusByProjectID;
    private Inflater decompresser = new Inflater();

    private final static int BY_CONTIG_ID = 1;
    private final static int BY_PROJECT_ID = 2;

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

	query = "select count(*) from CONTIG where project_id = ?";
	pstmtCountContigsByProject = conn.prepareStatement(query);

	query = "select contig_id,length,nreads,updated from CONTIG where project_id = ?";
	pstmtGetContigsByProject = conn.prepareStatement(query);

	query = "select length,sequence,quality from CONSENSUS where contig_id = ?";
	pstmtConsensusByID = conn.prepareStatement(query);

	query = "select CONTIG.contig_id,length,sequence,quality from CONTIG left join CONSENSUS using(contig_id) where project_id = ?";
	pstmtConsensusByProjectID = conn.prepareStatement(query);

	query = "select seq_id,MAPPING.mapping_id,MAPPING.cstart,cfinish,direction,count(*)" +
	    " from MAPPING left join SEGMENT using(mapping_id)" +
	    " where contig_id = ?" +
	    " group by MAPPING.mapping_id" +
	    " order by MAPPING.cstart asc, cfinish asc";
	pstmtMappingsByContigID = conn.prepareStatement(query);

	query = "select MAPPING.mapping_id,SEGMENT.cstart,rstart,length" +
	    " from MAPPING left join SEGMENT using(mapping_id)"+
	    " where contig_id = ?" +
	    " order by MAPPING.cstart asc, MAPPING.cfinish asc, SEGMENT.cstart asc";
	pstmtSegmentsByContigID = conn.prepareStatement(query);

	query = "select READS.read_id,READS.readname,asped,strand,primer,chemistry," +
	    "           TEMPLATE.template_id,TEMPLATE.name,TEMPLATE.ligation_id,SEQ2READ.seq_id,SEQ2READ.version" +
	    " from READS,TEMPLATE,SEQ2READ,MAPPING" +
	    " where READS.read_id=SEQ2READ.read_id and READS.template_id=TEMPLATE.template_id and SEQ2READ.seq_id=MAPPING.seq_id" +
	    " and contig_id = ?";
	pstmtReadDataByContigID = conn.prepareStatement(query);

	query = "select READS.read_id,READS.readname,asped,strand,primer,chemistry," +
	    "           TEMPLATE.template_id,TEMPLATE.name,TEMPLATE.ligation_id,SEQ2READ.seq_id,SEQ2READ.version," +
	    "           SEQUENCE.seqlen,SEQUENCE.sequence,SEQUENCE.quality" +
	    " from READS,TEMPLATE,SEQ2READ,MAPPING,SEQUENCE" +
	    " where READS.read_id=SEQ2READ.read_id and READS.template_id=TEMPLATE.template_id and SEQ2READ.seq_id=MAPPING.seq_id" +
	    " and SEQUENCE.seq_id=MAPPING.seq_id" +
	    " and contig_id = ?";
	pstmtFullReadDataByContigID = conn.prepareStatement(query);

	query = "select READS.read_id,READS.readname,asped,strand,primer,chemistry," +
	    "           TEMPLATE.template_id,TEMPLATE.name,TEMPLATE.ligation_id,SEQ2READ.seq_id,SEQ2READ.version" +
	    " from READS,CONTIG,TEMPLATE,SEQ2READ,MAPPING" +
	    " where READS.read_id=SEQ2READ.read_id and READS.template_id=TEMPLATE.template_id and SEQ2READ.seq_id=MAPPING.seq_id" +
	    " and CONTIG.contig_id=MAPPING.contig_id" + 
	    " and project_id = ?";
	pstmtReadDataByProjectID = conn.prepareStatement(query);

	query = "select READS.read_id,READS.readname,asped,strand,primer,chemistry," +
	    "           TEMPLATE.template_id,TEMPLATE.name,TEMPLATE.ligation_id,SEQ2READ.seq_id,SEQ2READ.version," +
	    "           SEQUENCE.seqlen,SEQUENCE.sequence,SEQUENCE.quality" +
	    " from READS,CONTIG,TEMPLATE,SEQ2READ,MAPPING,SEQUENCE" +
	    " where READS.read_id=SEQ2READ.read_id and READS.template_id=TEMPLATE.template_id and SEQ2READ.seq_id=MAPPING.seq_id" +
	    " and SEQUENCE.seq_id=MAPPING.seq_id" +
	    " and CONTIG.contig_id=MAPPING.contig_id" + 
	    " and project_id = ?";
	pstmtFullReadDataByProjectID = conn.prepareStatement(query);

	hashByID = new HashMap();
    }

    public Contig getContigByID(int id, int consensusOption, int mappingOption) throws SQLException {
	return getContigByID(id, consensusOption, mappingOption, true);
    }

    public Contig getContigByID(int id, int consensusOption, int mappingOption,
				boolean autoload) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	if (obj == null)
	    return autoload ? loadContigByID(id, consensusOption, mappingOption) : null;

	Contig contig = (Contig)obj;

	if (contig.getMappings() == null && mappingOption != ArcturusDatabase.CONTIG_NO_MAPPING)
	    loadMappingsForContig(contig, mappingOption);

	if (contig.getConsensus() == null && consensusOption != ArcturusDatabase.CONTIG_NO_CONSENSUS)
	    loadConsensusForContig(contig);

	return contig;
    }

    private Contig loadContigByID(int id, int consensusOption, int mappingOption) throws SQLException {
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

	if (mappingOption != ArcturusDatabase.CONTIG_NO_MAPPING)
	    loadMappingsForContig(contig, mappingOption);

	if (consensusOption != ArcturusDatabase.CONTIG_NO_CONSENSUS)
	    loadConsensusForContig(contig);

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

    private void loadMappingsForContig(Contig contig, int mappingOption) throws SQLException {
	bulkLoadReadData(BY_CONTIG_ID, contig.getID(), mappingOption);

	bulkLoadMappings(contig);
    }

    private void bulkLoadReadData(int idType, int id, int mappingOption) throws SQLException {
	PreparedStatement pstmt = null;

	if (idType == BY_CONTIG_ID) {
	    if (mappingOption == ArcturusDatabase.CONTIG_FULL_MAPPING)
		pstmt = pstmtFullReadDataByContigID;
	    else
		pstmt = pstmtReadDataByContigID;
	} else {
	    if (mappingOption == ArcturusDatabase.CONTIG_FULL_MAPPING)
		pstmt = pstmtFullReadDataByProjectID;
	    else
		pstmt = pstmtReadDataByProjectID;
	}

	pstmt.setInt(1, id);

	ResultSet rs = pstmt.executeQuery();

	while (rs.next()) {
	    int ligation_id = rs.getInt(9);
	    Ligation ligation = adb.getLigationByID(ligation_id);

	    int template_id = rs.getInt(7);
	    Template template = adb.getTemplateByID(template_id, false);
	    if (template == null) {
		String template_name = rs.getString(8);
		template = new Template(template_name, template_id, ligation, adb);
		adb.registerNewTemplate(template);
	    }

	    int read_id = rs.getInt(1);
	    Read read = adb.getReadByID(read_id, false);
	    if (read == null) {
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
		int version = rs.getInt(11);
		sequence = new Sequence(seq_id, read, null, null, version);
		adb.registerNewSequence(sequence);

		if (mappingOption == ArcturusDatabase.CONTIG_FULL_MAPPING) {
		    int seqlen = rs.getInt(12);
		    byte[] dna = adb.decodeCompressedData(rs.getBytes(13), seqlen);
		    byte[] quality = adb.decodeCompressedData(rs.getBytes(14), seqlen);
		    sequence.setDNA(dna);
		    sequence.setQuality(quality);
		}
	    }
	}

	rs.close();
     }

    private void bulkLoadMappings(Contig contig) throws SQLException {
	int contig_id = contig.getID();
	
	pstmtCountMappingsByContigID.setInt(1, contig_id);
	ResultSet rs = pstmtCountMappingsByContigID.executeQuery();

	int nmaps = 0;
	Mapping[] mappings;

	if (rs.next()) {
	    nmaps = rs.getInt(1);
	    mappings = new Mapping[nmaps];
	} else {
	    rs.close();
	    return;
	}

	rs.close();

	pstmtMappingsByContigID.setInt(1, contig_id);
	rs = pstmtMappingsByContigID.executeQuery();

	int kmap = 0;

	HashMap hash = new HashMap(nmaps);

	while (rs.next()) {
	    int seq_id = rs.getInt(1);
	    int mapping_id = rs.getInt(2);
	    int cstart = rs.getInt(3);
	    int cfinish = rs.getInt(4);
	    int direction = rs.getString(5).equals("Forward") ? Mapping.FORWARD : Mapping.REVERSE;
	    int nsegs = rs.getInt(6);

	    Sequence sequence = adb.getSequenceBySequenceID(seq_id);

	    Mapping mapping = new Mapping(sequence, cstart, cfinish, direction, nsegs);

	    mappings[kmap++] = mapping;

	    hash.put(new Integer(mapping_id), mapping);
	}

	rs.close();

	pstmtSegmentsByContigID.setInt(1, contig_id);
	rs = pstmtSegmentsByContigID.executeQuery();

	int last_mapping_id = -1;
	Mapping last_mapping = null;

	while (rs.next()) {
	    int mapping_id = rs.getInt(1);
	    int seg_cstart = rs.getInt(2);
	    int seg_rstart = rs.getInt(3);
	    int seg_length = rs.getInt(4);

	    Mapping mapping = (mapping_id == last_mapping_id) ?
		last_mapping : (Mapping)hash.get(new Integer(mapping_id));
	    
	    Segment segment= new Segment(seg_cstart, seg_rstart, seg_length);
	    
	    mapping.addSegment(segment);

	    last_mapping = mapping;
	    last_mapping_id = mapping_id;
	}

	rs.close();

	contig.setMappings(mappings);
    }

    private void loadConsensusForContig(Contig contig) throws SQLException {
	int contig_id = contig.getID();
	
	pstmtConsensusByID.setInt(1, contig_id);
	ResultSet rs = pstmtConsensusByID.executeQuery();

	if (rs.next()) {
	    int seqlen = rs.getInt(1);

	    byte[] cdna = rs.getBytes(2);

	    byte[] dna = new byte[seqlen];

	    try {
		decompresser.setInput(cdna, 0, cdna.length);
		int dnalen = decompresser.inflate(dna, 0, dna.length);
		decompresser.reset();
	    }
	    catch (DataFormatException dfe) {
		dna = null;
	    }

	    byte[] cqual = rs.getBytes(3);

	    byte[] qual = new byte[seqlen];

	    try {
		decompresser.setInput(cqual, 0, cqual.length);
		int dnalen = decompresser.inflate(qual, 0, qual.length);
		decompresser.reset();
	    }
	    catch (DataFormatException dfe) {
		qual = null;
	    }

	    contig.setConsensus(dna, qual);
	}

	rs.close();
    }

    public int countContigsByProject(int project_id) throws SQLException {
	pstmtCountContigsByProject.setInt(1, project_id);
	ResultSet rs = pstmtCountContigsByProject.executeQuery();

	int nContigs = 0;

	if (rs.next()) {
	    nContigs = rs.getInt(1);
	}

	rs.close();

	return nContigs;
    }

    public Contig[] getContigsByProject(int project_id, int consensusOption, int mappingOption) throws SQLException {
	return getContigsByProject(project_id, consensusOption, mappingOption, true);
    }

    public Contig[] getContigsByProject(int project_id, int consensusOption, int mappingOption,
					boolean autoload) throws SQLException {
	Vector contigs = new Vector();

	pstmtGetContigsByProject.setInt(1, project_id);

	ResultSet rs = pstmtGetContigsByProject.executeQuery();

	while (rs.next()) {
	    int id = rs.getInt(1);

	    Object obj = hashByID.get(new Integer(id));

	    Contig contig = (Contig)obj;

	    if (contig == null) {
		int length = rs.getInt(2);
		int nreads = rs.getInt(3);
		java.sql.Date updated = rs.getDate(4);

		contig = createAndRegisterNewContig(id, length, nreads, updated);
	    }

	    contigs.add(contig);
	}

	if (mappingOption != ArcturusDatabase.CONTIG_NO_MAPPING) {
	    System.err.println("loading read data for project " + project_id);
	    loadReadDataForProject(project_id, mappingOption);
	    System.err.println("done");

	    System.err.println("loading mapping data for project " + project_id);
	    for (Enumeration e = contigs.elements() ; e.hasMoreElements() ;) {
		Contig contig = (Contig)e.nextElement();
		bulkLoadMappings(contig);
	    }
	    System.err.println("done");
	}

	if (consensusOption != ArcturusDatabase.CONTIG_NO_CONSENSUS)
	    loadConsensusForProject(project_id);

	Contig[] contigarray = new Contig[contigs.size()];

	contigs.copyInto(contigarray);

	return contigarray;
    }

    private void loadReadDataForProject(int project_id, int mappingOption) throws SQLException {
	bulkLoadReadData(BY_PROJECT_ID, project_id, mappingOption);
    }

    private void loadConsensusForProject(int project_id) throws SQLException {
    }

    public int[] getCurrentContigIDList() throws SQLException {
	String query = "select count(*) from CONTIG left join C2CMAPPING" + 
	    " on CONTIG.contig_id = C2CMAPPING.parent_id" +
	    " where C2CMAPPING.parent_id is null";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	int ncontigs = 0;

	if (rs.next()) {
	    ncontigs = rs.getInt(1);
	}

	rs.close();

	if (ncontigs == 0)
	    return null;
	
	int[] ids = new int[ncontigs];

	query = "select CONTIG.contig_id from CONTIG left join C2CMAPPING" + 
	    " on CONTIG.contig_id = C2CMAPPING.parent_id" +
	    " where C2CMAPPING.parent_id is null";

	rs = stmt.executeQuery(query);

	int j = 0;

	while (rs.next() && j < ncontigs)
	    ids[j++] = rs.getInt(1);

	rs.close();
	stmt.close();

	return ids;
    }

    public int[] getUnassembledReadIDList() throws SQLException {
	Statement stmt = conn.createStatement();

	String[] queries = {
	    "create temporary table CURCTG as" +
	    " select CONTIG.contig_id from CONTIG left join C2CMAPPING" +
	    " on CONTIG.contig_id = C2CMAPPING.parent_id" +
	    " where C2CMAPPING.parent_id is null",

	    "create temporary table CURSEQ as" +
	    " select seq_id from CURCTG left join MAPPING using(contig_id)",

	    "create temporary table CURREAD" +
	    " (read_id integer not null, seq_id integer not null, key (read_id)) as" +
	    " select read_id,SEQ2READ.seq_id from CURSEQ left join SEQ2READ using(seq_id)",

	    "create temporary table FREEREAD as" +
	    " select READS.read_id from READS left join CURREAD using(read_id)" +
	    " where seq_id is null"
	};

	for (int i = 0; i < queries.length; i++) {
	    int rows = stmt.executeUpdate(queries[i]);
	}

	String query = "select count(*) from FREEREAD";

	ResultSet rs = stmt.executeQuery(query);

	int nreads = 0;

	if (rs.next())
	    nreads = rs.getInt(1);

	rs.close();

	if (nreads == 0)
	    return null;

	query = "select read_id from FREEREAD";

	rs = stmt.executeQuery(query);

	int[] ids = new int[nreads];

	int j = 0;

	while (rs.next() && j < nreads)
	    ids[j++] = rs.getInt(1);

	rs.close();

	stmt.close();

	return ids;
    }
}
