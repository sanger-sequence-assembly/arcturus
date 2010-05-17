package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.database.ContigProcessor;

import java.sql.*;
import java.util.*;
import java.util.zip.Inflater;
import java.util.zip.DataFormatException;

/**
 * This class manages Contig objects.
 */

public class ContigManager extends AbstractManager {
	private ArcturusDatabase adb;
	private HashMap<Integer, Contig> hashByID;

	private Inflater decompresser = new Inflater();

	protected PreparedStatement pstmtContigData = null;
	protected PreparedStatement pstmtCurrentContigData = null;
	protected PreparedStatement pstmtCountMappings = null;
	protected PreparedStatement pstmtMappingData = null;
	protected PreparedStatement pstmtCountSegments = null;
	protected PreparedStatement pstmtSegmentData = null;
	protected PreparedStatement pstmtSequenceData = null;
	protected PreparedStatement pstmtReadAndTemplateData = null;
	protected PreparedStatement pstmtQualityClipping = null;
	protected PreparedStatement pstmtSequenceVector = null;
	protected PreparedStatement pstmtCloningVector = null;
	protected PreparedStatement pstmtAlignToSCF = null;
	protected PreparedStatement pstmtConsensus = null;
	protected PreparedStatement pstmtTags = null;

	protected PreparedStatement pstmtCountContigsByProject = null;
	protected PreparedStatement pstmtContigsByProject = null;

	protected PreparedStatement pstmtCountCurrentContigs = null;
	protected PreparedStatement pstmtCurrentContigs = null;
	
	protected PreparedStatement pstmtContigIDFromReadname = null;
	
	protected PreparedStatement pstmtChildContigs = null;

	protected ManagerEvent event = null;

	private transient Vector<ManagerEventListener> eventListeners = new Vector<ManagerEventListener>();

	protected SegmentComparatorByContigPosition segmentComparator = new SegmentComparatorByContigPosition();

	protected Map<Integer, String> svectorByID = new HashMap<Integer, String>();
	protected Map<Integer, String> cvectorByID = new HashMap<Integer, String>();

	/**
	 * Creates a new ContigManager to provide contig management services to an
	 * ArcturusDatabase object.
	 */

	public ContigManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;

		event = new ManagerEvent(this);

		hashByID = new HashMap<Integer, Contig>();

		try {
			setConnection(adb.getDefaultConnection());

			preloadSequencingVectors();
			preloadCloningVectors();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the contig manager", conn, adb);
		}
	}

	public void clearCache() {
		hashByID.clear();
	}

	protected void prepareConnection() throws SQLException {
		String query;

		query = "select gap4name,length,nreads,created,updated,project_id "
				+ " from CONTIG where contig_id = ?";

		pstmtContigData = conn.prepareStatement(query);

		query = "select gap4name,length,nreads,created,updated,project_id"
				+ " from CURRENTCONTIGS" + " where contig_id = ?";

		pstmtCurrentContigData = conn.prepareStatement(query);

		query = "select count(*) from MAPPING where contig_id = ?";

		pstmtCountMappings = conn.prepareStatement(query);

		query = "select count(*) from MAPPING left join SEGMENT using(mapping_id) where contig_id = ?";

		pstmtCountSegments = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,cstart,cfinish,direction,seqlen"
				+ " from MAPPING left join SEQUENCE using(seq_id)"
				+ " where contig_id=?";

		pstmtMappingData = conn.prepareStatement(query);

		query = "select seq_id,SEGMENT.cstart,rstart,length "
				+ " from MAPPING left join SEGMENT using(mapping_id) "
				+ " where contig_id = ?";

		pstmtSegmentData = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,seqlen,sequence,quality "
				+ " from MAPPING left join SEQUENCE using(seq_id) "
				+ " where contig_id = ?";

		pstmtSequenceData = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,READINFO.read_id,readname,strand,chemistry,primer,asped,"
				+ " TEMPLATE.template_id,TEMPLATE.name,ligation_id"
				+ " from (MAPPING left join (SEQ2READ left join" 
				+ " (READINFO left join TEMPLATE using (template_id))"
				+ " using (read_id)) using (seq_id))"
				+ " where contig_id = ?";

		pstmtReadAndTemplateData = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,qleft,qright"
				+ " from MAPPING left join QUALITYCLIP using(seq_id) where contig_id = ?";

		pstmtQualityClipping = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,svector_id,svleft,svright"
				+ " from MAPPING left join SEQVEC using(seq_id) where contig_id = ? and svleft is not null";

		pstmtSequenceVector = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,cvector_id,cvleft,cvright"
				+ " from MAPPING left join CLONEVEC using(seq_id) where contig_id = ? and cvleft is not null";

		pstmtCloningVector = conn.prepareStatement(query);

		query = "select MAPPING.seq_id,startinseq,startinscf,length"
				+ " from MAPPING left join ALIGN2SCF using(seq_id) where contig_id = ? and startinseq is not null";

		pstmtAlignToSCF = conn.prepareStatement(query);

		query = "select length,sequence,quality from CONSENSUS where contig_id = ?";

		pstmtConsensus = conn.prepareStatement(query);

		query = "select tagtype,cstart,cfinal,tagcomment"
				+ " from TAG2CONTIG left join CONTIGTAG using(tag_id)"
				+ " where contig_id = ?";

		pstmtTags = conn.prepareStatement(query);

		query = "select count(*) from CURRENTCONTIGS"
				+ " where project_id = ? and length > ?";

		pstmtCountContigsByProject = conn.prepareStatement(query);

		query = "select contig_id,gap4name,length,nreads,created,updated"
				+ " from CURRENTCONTIGS"
				+ " where project_id = ? and length > ?";

		pstmtContigsByProject = conn.prepareStatement(query);

		query = "select count(*) " + " from CURRENTCONTIGS"
				+ " where length > ?";

		pstmtCountCurrentContigs = conn.prepareStatement(query);

		query = "select contig_id,gap4name,length,nreads,created,updated,project_id "
				+ " from CURRENTCONTIGS" + " where length > ?";

		pstmtCurrentContigs = conn.prepareStatement(query);
		
		query = " select CURRENTCONTIGS.contig_id"
			+ " from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS,PROJECT"
			+ " where READINFO.readname = ?"
			+ " and READINFO.read_id = SEQ2READ.read_id"
			+ " and SEQ2READ.seq_id = MAPPING.seq_id"
			+ " and MAPPING.contig_id = CURRENTCONTIGS.contig_id"
			+ " and CURRENTCONTIGS.project_id = PROJECT.project_id";
		
		pstmtContigIDFromReadname = conn.prepareStatement(query);
		
		query = "select contig_id from C2CMAPPING where parent_id = ?";
		
		pstmtChildContigs = conn.prepareStatement(query);
	}

	protected void preloadSequencingVectors() throws SQLException {
		String query = "select svector_id, name from SEQUENCEVECTOR";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int svector_id = rs.getInt(1);

			Integer id = new Integer(svector_id);

			if (!svectorByID.containsKey(id)) {
				String name = rs.getString(2);

				svectorByID.put(id, name);
			}
		}

		rs.close();
	}

	protected void preloadCloningVectors() throws SQLException {
		String query = "select cvector_id, name from CLONINGVECTOR";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int cvector_id = rs.getInt(1);

			Integer id = new Integer(cvector_id);

			if (!cvectorByID.containsKey(id)) {
				String name = rs.getString(2);

				cvectorByID.put(id, name);
			}
		}

		rs.close();
	}

	public Contig getContigByReadName(String readname) throws ArcturusDatabaseException {
		return getContigByReadName(readname, ArcturusDatabase.CONTIG_BASIC_DATA);
	}
	
	public Contig getContigByReadName(String readname, int options) throws ArcturusDatabaseException {
		Contig contig = null;
		
		try {
			pstmtContigIDFromReadname.setString(1, readname);

			ResultSet rs = pstmtContigIDFromReadname.executeQuery();

			int contig_id = rs.next() ? rs.getInt(1) : -1;

			rs.close();

			if (contig_id > 0)
				contig = getContigByID(contig_id, options);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get contig by readname=\"" + readname + "\"", conn, this);
		}
		
		return contig;
	}
	
	public Contig getContigByID(int contig_id) throws ArcturusDatabaseException {
		return getContigByID(contig_id, ArcturusDatabase.CONTIG_BASIC_DATA);
	}

	public Contig getContigByID(int contig_id, int options)
			throws ArcturusDatabaseException {
		Contig contig = (Contig) hashByID.get(new Integer(contig_id));

		if (contig == null)
			contig = loadContigByID(contig_id, options);
		else
			updateContig(contig, options);

		return contig;
	}

	private Contig loadContigByID(int contig_id, int options)
			throws ArcturusDatabaseException {
		Contig contig = createContig(contig_id);

		if (contig != null)
			updateContig(contig, options);

		return contig;
	}

	private Contig createContig(int contig_id) throws ArcturusDatabaseException {
		Contig contig = null;

		try {
			pstmtContigData.setInt(1, contig_id);

			ResultSet rs = pstmtContigData.executeQuery();

			if (rs.next()) {
				String gap4name = rs.getString(1);
				int ctglen = rs.getInt(2);
				int nreads = rs.getInt(3);
				java.util.Date created = rs.getTimestamp(4);
				java.util.Date updated = rs.getTimestamp(5);
				int project_id = rs.getInt(6);

				Project project = adb.getProjectByID(project_id);

				contig = new Contig(gap4name, contig_id, ctglen, nreads,
						created, updated, project, adb);

				registerNewContig(contig);

				event.setMessage("Contig " + contig_id + " : " + ctglen
						+ " bp, " + nreads + " reads");
				event.setState(ManagerEvent.START);
				fireEvent(event);
			} else
				return null;

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to create contig by ID=" + contig_id,
					conn, this);
		}

		return contig;
	}

	void registerNewContig(Contig contig) {
		hashByID.put(new Integer(contig.getID()), contig);
	}
	
	private void updateBasicContigData(Contig contig) throws ArcturusDatabaseException {
		if (contig == null)
			return;
		
		try {
		pstmtContigData.setInt(1, contig.getID());

		ResultSet rs = pstmtContigData.executeQuery();

		if (rs.next()) {
			java.util.Date updated = rs.getTimestamp(5);
			int project_id = rs.getInt(6);

			Project project = adb.getProjectByID(project_id);
			
			contig.setUpdated(updated);
			contig.setProject(project);
		}
		
		rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to update basic contig data for " + contig,
					conn, this);			
		}
	}

	public void updateContig(Contig contig, int options) throws ArcturusDatabaseException {
		if (options == ArcturusDatabase.CONTIG_BASIC_DATA) {
			updateBasicContigData(contig);
			return;
		}
		
		int contig_id = contig.getID();

		if ((options & ArcturusDatabase.CONTIG_MAPPING_RELATED_DATA) != 0) {
			BasicSequenceToContigMapping mappings[] = contig.getMappings();

			if (mappings == null) {
				int nMappings = getMappingCount(contig_id);

				/*
				 * Create an empty array of Mapping objects.
				 */

				mappings = new BasicSequenceToContigMapping[nMappings];

				getMappings(contig, mappings);

				Arrays.sort(mappings);

				contig.setMappings(mappings);
			}

			Map mapmap = createMappingsMap(mappings);

			if ((options & ArcturusDatabase.CONTIG_MAPPINGS_READS_AND_TEMPLATES) != 0)
				getReadAndTemplateData(contig_id, mapmap);

			if ((options & ArcturusDatabase.CONTIG_MAPPING_SEGMENTS) != 0)
				getSegmentData(contig_id, mapmap);

			if ((options & ArcturusDatabase.CONTIG_SEQUENCE_DNA_AND_QUALITY) != 0)
				getSequenceData(contig_id, mapmap);

			if ((options & ArcturusDatabase.CONTIG_SEQUENCE_AUXILIARY_DATA) != 0) {
				getSequenceVectorData(contig_id, mapmap);
				getCloningVectorData(contig_id, mapmap);
				getQualityClippingData(contig_id, mapmap);
				getAlignToSCF(contig_id, mapmap);
			}
		}

		if ((options & ArcturusDatabase.CONTIG_CONSENSUS) != 0
				&& contig.getDNA() == null)
			loadConsensusForContig(contig);

		if ((options & ArcturusDatabase.CONTIG_TAGS) != 0)
			loadTagsForContig(contig);
	}

	private int getMappingCount(int contig_id) throws ArcturusDatabaseException {
		int count = 0;
		
		try {
			pstmtCountMappings.setInt(1, contig_id);

			ResultSet rs = pstmtCountMappings.executeQuery();

			rs.next();

			count = rs.getInt(1);

			rs.close();

		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to get mapping count for contig ID= " + contig_id,
					conn, this);			
		}
		
		return count;
	}

	private void getMappings(Contig contig, BasicSequenceToContigMapping[] mappings)
			throws ArcturusDatabaseException {
		int nMappings = mappings.length;

		try {
			pstmtMappingData.setInt(1, contig.getID());

			event.begin("Execute mapping query", nMappings);
			fireEvent(event);

			ResultSet rs = pstmtMappingData.executeQuery();

			event.end();
			fireEvent(event);

			int kMapping = 0;

			event.begin("Creating mappings", nMappings);
			fireEvent(event);

			while (rs.next()) {
				int seq_id = rs.getInt(1);
				int cstart = rs.getInt(2);
				int cfinish = rs.getInt(3);
				boolean forward = rs.getString(4).equalsIgnoreCase("Forward");
				int length = rs.getInt(5);

				Sequence sequence = adb.findOrCreateSequence(seq_id, length);

				mappings[kMapping++] = new BasicSequenceToContigMapping(contig, sequence, cstart, cfinish,
						forward);

				if ((kMapping % 10) == 0) {
					event.working(kMapping);
					fireEvent(event);
				}
			}

			event.end();
			fireEvent(event);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to get mappings for contig ID= " + contig.getID(),
					conn, this);			
		}
	}

	private void getReadAndTemplateData(int contig_id, Map mapmap)
			throws ArcturusDatabaseException {
		int nMappings = mapmap.size();

		try {
			pstmtReadAndTemplateData.setInt(1, contig_id);

			event.begin("Execute read/template data query", nMappings);
			fireEvent(event);

			ResultSet rs = pstmtReadAndTemplateData.executeQuery();

			event.end();
			fireEvent(event);

			event.begin("Loading read and template data", nMappings);
			fireEvent(event);

			int kMapping = 0;

			while (rs.next()) {
				int index = 1;

				int seq_id = rs.getInt(index++);
				int read_id = rs.getInt(index++);
				String readname = rs.getString(index++);
				String strand = rs.getString(index++);
				String chemistry = rs.getString(index++);
				String primer = rs.getString(index++);
				java.util.Date asped = rs.getTimestamp(index++);
				int template_id = rs.getInt(index++);
				String templatename = rs.getString(index++);
				int ligation_id = rs.getInt(index++);

				Ligation ligation = adb.getLigationByID(ligation_id);

				Template template = new Template(templatename, template_id,
						 ligation, adb);
				
				((ArcturusDatabaseImpl)adb).registerNewTemplate(template, template_id);

				Read read = new Read(readname, read_id, template, asped,
						ReadManager.parseStrand(strand),
						ReadManager.parsePrimer(primer),
						ReadManager.parseChemistry(chemistry),
						adb);
				
				((ArcturusDatabaseImpl)adb).registerNewRead(read);

				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(seq_id));
				Sequence sequence = mapping.getSequence();

				sequence.setRead(read);

				kMapping++;

				if ((kMapping % 10) == 0) {
					event.working(kMapping);
					fireEvent(event);
				}
			}

			event.end();
			fireEvent(event);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to get read and template data for contig ID= " + contig_id,
					conn, this);			
		}
	}

	private int getSegmentCount(int contig_id) throws ArcturusDatabaseException {
		int count = 0;
		
		try {
			pstmtCountSegments.setInt(1, contig_id);

			ResultSet rs = pstmtCountSegments.executeQuery();

			rs.next();

			count = rs.getInt(1);

			rs.close();

		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to get segment count for contig ID= " + contig_id,
					conn, this);			
		}

		return count;
	}

	private void getSegmentData(int contig_id, Map mapmap) throws ArcturusDatabaseException {
		int nSegments = getSegmentCount(contig_id);

		int nMappings = mapmap.size();

		Vector<BasicSegment> segv = new Vector<BasicSegment>(1000, 1000);
		SortableSegment segments[] = null;

		try {
			pstmtSegmentData.setInt(1, contig_id);

			event.begin("Execute segment query", nMappings);
			fireEvent(event);

			ResultSet rs = pstmtSegmentData.executeQuery();

			event.end();
			fireEvent(event);

			event.begin("Loading segments", nSegments);
			fireEvent(event);

			segments = new SortableSegment[nSegments];

			int kSegment = 0;

			while (rs.next()) {
				int seq_id = rs.getInt(1);
				int cstart = rs.getInt(2);
				int rstart = rs.getInt(3);
				int length = rs.getInt(4);

				segments[kSegment++] = new SortableSegment(seq_id, cstart,
						rstart, length);

				if ((kSegment % 50) == 0) {
					event.working(kSegment);
					fireEvent(event);
				}
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to get segment data for contig ID= " + contig_id,
					conn, this);						
		}

		event.end();
		fireEvent(event);

		event.begin("Sorting segments", nSegments);
		fireEvent(event);

		Arrays.sort(segments);

		event.end();
		fireEvent(event);

		int current_seq_id = 0;

		event.begin("Processing segments", nSegments);
		fireEvent(event);

		for (int kSegment = 0; kSegment < nSegments; kSegment++) {
			int next_seq_id = segments[kSegment].seq_id;
			int cstart = segments[kSegment].cstart;
			int rstart = segments[kSegment].rstart;
			int length = segments[kSegment].length;

			if ((next_seq_id != current_seq_id) && (current_seq_id > 0)) {
				BasicSegment segs[] = new BasicSegment[segv.size()];
				segv.toArray(segs);
				Arrays.sort(segs, segmentComparator);
				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(
						current_seq_id));
				mapping.setSegments(segs);
				segv.clear();
			}

			segv.add(new BasicSegment(cstart, rstart, length));

			current_seq_id = next_seq_id;

			if ((kSegment % 50) == 0) {
				event.working(kSegment);
				fireEvent(event);
			}
		}

		BasicSegment segs[] = new BasicSegment[segv.size()];

		segv.toArray(segs);

		Arrays.sort(segs, segmentComparator);

		BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(current_seq_id));
		mapping.setSegments(segs);

		event.end();
		fireEvent(event);
	}

	private void getSequenceData(int contig_id, Map mapmap)
			throws ArcturusDatabaseException {
		int nMappings = mapmap.size();

		try {
			pstmtSequenceData.setInt(1, contig_id);

			event.begin("Execute sequence query", nMappings);
			fireEvent(event);

			ResultSet rs = pstmtSequenceData.executeQuery();

			event.end();
			fireEvent(event);

			event.begin("Loading sequences", nMappings);
			fireEvent(event);

			int kMapping = 0;

			while (rs.next()) {
				int seq_id = rs.getInt(1);

				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(seq_id));
				Sequence sequence = mapping.getSequence();

				int seqlen = rs.getInt(2);

				byte[] cdna = rs.getBytes(3);

				byte[] dna = inflate(cdna, seqlen);

				sequence.setDNA(dna);

				byte[] cqual = rs.getBytes(4);

				byte[] qual = inflate(cqual, seqlen);

				sequence.setQuality(qual);

				if ((kMapping % 10) == 0) {
					event.working(kMapping);
					fireEvent(event);
				}
			}

			event.end();
			fireEvent(event);

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch sequence data for contig ID= " + contig_id,
					conn, this);									
		}
		catch (DataFormatException e) {
			throw new ArcturusDatabaseException(e,
					"Failed to decompress sequence data for contig ID= " + contig_id,
					conn, adb);									
		}
	}

	private byte[] inflate(byte[] cdata, int length) throws DataFormatException {
		if (cdata == null)
			return null;

		byte[] data = new byte[length];

		decompresser.setInput(cdata, 0, cdata.length);
		decompresser.inflate(data, 0, data.length);
		decompresser.reset();

		return data;
	}

	private Map createMappingsMap(BasicSequenceToContigMapping[] mappings) {
		Map<Integer, BasicSequenceToContigMapping> hash = new HashMap<Integer, BasicSequenceToContigMapping>(mappings.length);

		for (int i = 0; i < mappings.length; i++) {
			BasicSequenceToContigMapping value = mappings[i];
			int sequence_id = value.getSequence().getID();
			Integer key = new Integer(sequence_id);
			hash.put(key, value);
		}

		return hash;
	}

	private void getSequenceVectorData(int contig_id, Map mapmap)
			throws ArcturusDatabaseException {
		event.begin("Loading sequence vector data", 0);
		fireEvent(event);

		try {
			pstmtSequenceVector.setInt(1, contig_id);

			ResultSet rs = pstmtSequenceVector.executeQuery();

			while (rs.next()) {
				int seq_id = rs.getInt(1);
				int svector_id = rs.getInt(2);
				int svleft = rs.getInt(3);
				int svright = rs.getInt(4);

				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(seq_id));

				Sequence sequence = mapping.getSequence();

				String svector = (String) svectorByID.get(new Integer(
						svector_id));

				Clipping clipping = new Clipping(Clipping.SVEC, svector,
						svleft, svright);

				if (svleft == 1)
					sequence.setSequenceVectorClippingLeft(clipping);
				else
					sequence.setSequenceVectorClippingRight(clipping);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch sequence vector data for contig ID= " + contig_id,
					conn, this);												
		}

		event.end();
		fireEvent(event);
	}

	private void getCloningVectorData(int contig_id, Map mapmap)
			throws ArcturusDatabaseException {
		event.begin("Loading cloning vector data", 0);
		fireEvent(event);

		try {
			pstmtCloningVector.setInt(1, contig_id);

			ResultSet rs = pstmtCloningVector.executeQuery();

			while (rs.next()) {
				int seq_id = rs.getInt(1);
				int cvector_id = rs.getInt(2);
				int cvleft = rs.getInt(3);
				int cvright = rs.getInt(4);

				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(seq_id));

				Sequence sequence = mapping.getSequence();

				String cvector = (String) cvectorByID.get(new Integer(
						cvector_id));

				sequence.setCloningVectorClipping(new Clipping(Clipping.CVEC,
						cvector, cvleft, cvright));
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch cloning vector data for contig ID= " + contig_id,
					conn, this);												
		}
		

		event.end();
		fireEvent(event);
	}

	private void getQualityClippingData(int contig_id, Map mapmap)
			throws ArcturusDatabaseException {
		event.begin("Loading quality clipping data", 0);
		fireEvent(event);

		try {
			pstmtQualityClipping.setInt(1, contig_id);

			ResultSet rs = pstmtQualityClipping.executeQuery();

			while (rs.next()) {
				int seq_id = rs.getInt(1);
				int qleft = rs.getInt(2);
				int qright = rs.getInt(3);

				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(seq_id));

				Sequence sequence = mapping.getSequence();

				sequence.setQualityClipping(new Clipping(Clipping.QUAL, null,
						qleft, qright));
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch quality clipping data for contig ID= " + contig_id,
					conn, this);												
		}

		event.end();
		fireEvent(event);
	}

	private void getAlignToSCF(int contig_id, Map mapmap) throws ArcturusDatabaseException {
		event.begin("Loading AlignToSCF data", 0);
		fireEvent(event);

		Vector<SortableAlignToSCF> rawAlignments = new Vector<SortableAlignToSCF>();

		try {
			pstmtAlignToSCF.setInt(1, contig_id);

			ResultSet rs = pstmtAlignToSCF.executeQuery();

			while (rs.next()) {
				int seq_id = rs.getInt(1);
				int seqstart = rs.getInt(2);
				int scfstart = rs.getInt(3);
				int length = rs.getInt(4);

				rawAlignments.add(new SortableAlignToSCF(seq_id, seqstart,
						scfstart, length));
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch quality clipping data for contig ID= " + contig_id,
					conn, this);												
		}

		SortableAlignToSCF[] array = new SortableAlignToSCF[rawAlignments.size()];

		rawAlignments.toArray(array);

		Arrays.sort(array);

		Vector<AlignToSCF> alignments = new Vector<AlignToSCF>();

		int current_seq_id = -1;

		AlignToSCFComparator alignToSCFComparator = new AlignToSCFComparator();

		for (int k = 0; k < array.length; k++) {
			int next_seq_id = array[k].seq_id;
			int seqstart = array[k].seqstart;
			int scfstart = array[k].scfstart;
			int length = array[k].length;

			if ((next_seq_id != current_seq_id) && (current_seq_id > 0)) {
				AlignToSCF a2scf[] = new AlignToSCF[alignments.size()];
				alignments.toArray(a2scf);
				Arrays.sort(a2scf, alignToSCFComparator);
				BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(
						current_seq_id));
				mapping.getSequence().setAlignToSCF(a2scf);
				alignments.clear();
			}

			alignments.add(new AlignToSCF(seqstart, scfstart, length));

			current_seq_id = next_seq_id;

			if ((k % 50) == 0) {
				event.working(k);
				fireEvent(event);
			}
		}

		if (current_seq_id > 0) {
			AlignToSCF a2scf[] = new AlignToSCF[alignments.size()];
			alignments.toArray(a2scf);
			Arrays.sort(a2scf, alignToSCFComparator);
			BasicSequenceToContigMapping mapping = (BasicSequenceToContigMapping) mapmap.get(new Integer(current_seq_id));
			mapping.getSequence().setAlignToSCF(a2scf);
		}

		event.end();
		fireEvent(event);
	}

	public void addContigManagerEventListener(ManagerEventListener listener) {
		eventListeners.addElement(listener);
	}

	public void removeContigManagerEventListener(ManagerEventListener listener) {
		eventListeners.removeElement(listener);
	}

	private void fireEvent(ManagerEvent event) {
		Enumeration e = eventListeners.elements();
		while (e.hasMoreElements()) {
			ManagerEventListener l = (ManagerEventListener) e.nextElement();
			l.managerUpdate(event);
		}
	}

	private void loadConsensusForContig(Contig contig) throws ArcturusDatabaseException {
		int contig_id = contig.getID();

		try {
		pstmtConsensus.setInt(1, contig_id);
		ResultSet rs = pstmtConsensus.executeQuery();

		if (rs.next()) {
			int seqlen = rs.getInt(1);
			byte[] cdna = rs.getBytes(2);
			byte[] cqual = rs.getBytes(3);

			setContigConsensusFromRawData(contig, seqlen, cdna, cqual);
		}

		rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch consensus data for contig ID=" + contig.getID(),
					conn, this);											
		}
	}

	private void setContigConsensusFromRawData(Contig contig, int seqlen,
			byte[] cdna, byte[] cqual) throws ArcturusDatabaseException {
		byte[] dna = new byte[seqlen];

		decompresser.setInput(cdna, 0, cdna.length);
		
		try {
			decompresser.inflate(dna, 0, dna.length);
		} catch (DataFormatException e) {
			throw new ArcturusDatabaseException(e,
					"Failed to decompress DNA data for contig ID=" + contig.getID(),
					conn, adb);								
		}
		
		decompresser.reset();

		byte[] qual = new byte[seqlen];

		decompresser.setInput(cqual, 0, cqual.length);
		
		try {
			decompresser.inflate(qual, 0, qual.length);
		} catch (DataFormatException e) {
			throw new ArcturusDatabaseException(e,
					"Failed to decompress quality data for contig ID=" + contig.getID(),
					conn, adb);								
		}
		
		decompresser.reset();

		contig.setConsensus(dna, qual);
	}

	private void loadTagsForContig(Contig contig) throws ArcturusDatabaseException {
		int contig_id = contig.getID();

		Vector<Tag> tags = contig.getTags();
		
		if (tags != null)
			tags.clear();

		try {
			pstmtTags.setInt(1, contig_id);
			ResultSet rs = pstmtTags.executeQuery();

			while (rs.next()) {
				String type = rs.getString(1);
				int cstart = rs.getInt(2);
				int cfinal = rs.getInt(3);
				String comment = rs.getString(4);

				Tag tag = new Tag(type, cstart, cfinal, comment);

				contig.addTag(tag);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to load tags for contig ID=" + contig.getID(),
					conn, this);											
		}
	}

	public int countContigsByProject(int project_id, int minlen)
			throws ArcturusDatabaseException {
		int count = 0;

		try {
			pstmtCountContigsByProject.setInt(1, project_id);
			pstmtCountContigsByProject.setInt(2, minlen);

			ResultSet rs = pstmtCountContigsByProject.executeQuery();

			if (rs.next())
				count = rs.getInt(1);

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to count contigs for project ID=" + project_id,
					conn, this);											
		}

		return count;
	}

	public Set<Contig> getContigsByProject(int project_id, int options, int minlen)
			throws ArcturusDatabaseException {
		ContigSetBuilder csb = new ContigSetBuilder();

		processContigsByProject(project_id, options, minlen, csb);

		return csb.getContigSet();
	}

	public int processContigsByProject(int project_id, int options, int minlen,
			ContigProcessor processor) throws ArcturusDatabaseException {
		int nContigs = countContigsByProject(project_id, minlen);

		if (nContigs == 0)
			return 0;

		event.begin("Processing contigs for project " + project_id, nContigs);
		fireEvent(event);

		Project project = adb.getProjectByID(project_id);

		int count = 0;
		int processed = 0;

		try {
			pstmtContigsByProject.setInt(1, project_id);
			pstmtContigsByProject.setInt(2, minlen);

			ResultSet rs = pstmtContigsByProject.executeQuery();

			while (rs.next()) {
				int contig_id = rs.getInt(1);

				Contig contig = (Contig) hashByID.get(new Integer(contig_id));

				java.util.Date updated = rs.getTimestamp(6);

				if (contig == null) {
					String gap4name = rs.getString(2);
					int ctglen = rs.getInt(3);
					int nreads = rs.getInt(4);
					java.util.Date created = rs.getTimestamp(5);

					contig = new Contig(gap4name, contig_id, ctglen, nreads,
							created, updated, project, adb);

					registerNewContig(contig);
				} else {
					contig.setProject(project);
					contig.setUpdated(updated);
				}

				updateContig(contig, options);

				if (processor.processContig(contig))
					processed++;

				event.working(++count);
				fireEvent(event);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to process contigs for project ID=" + project_id,
					conn, this);														
		}

		event.end();
		fireEvent(event);

		return processed;
	}

	public boolean isCurrentContig(int contig_id) throws ArcturusDatabaseException {
		boolean found = false;
		
		try {
			pstmtCurrentContigData.setInt(1, contig_id);

			ResultSet rs = pstmtCurrentContigData.executeQuery();

			found = rs.next();

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to test whether contig ID=" + contig_id + " is current",
					conn, this);															
		}

		return found;
	}

	public int[] getCurrentContigIDList() throws ArcturusDatabaseException {
		int[] ids = null;
		
		try {
			String query = "select count(*) from CURRENTCONTIGS";

			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			int ncontigs = 0;

			if (rs.next()) {
				ncontigs = rs.getInt(1);
			}

			rs.close();

			if (ncontigs == 0)
				return null;

			ids = new int[ncontigs];

			query = "select contig_id from CURRENTCONTIGS";

			rs = stmt.executeQuery(query);

			int j = 0;

			while (rs.next() && j < ncontigs)
				ids[j++] = rs.getInt(1);

			rs.close();
			stmt.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch current contig ID list",
					conn, this);																		
		}

		return ids;
	}

	public int countCurrentContigs(int minlen) throws ArcturusDatabaseException {
		int count = 0;
		
		try {
			pstmtCountCurrentContigs.setInt(1, minlen);

			ResultSet rs = pstmtCountCurrentContigs.executeQuery();

			count = rs.next() ? rs.getInt(1) : 0;

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to count current contigs",
					conn, this);																					
		}

		return count;
	}

	public Set getCurrentContigs(int options, int minlen) throws ArcturusDatabaseException {
		ContigSetBuilder csb = new ContigSetBuilder();

		processCurrentContigs(options, minlen, csb);

		return csb.getContigSet();
	}

	public int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws ArcturusDatabaseException {
		int nContigs = countCurrentContigs(minlen);

		if (nContigs == 0)
			return 0;

		event.begin("Processing contigs with minlen=" + minlen, nContigs);
		fireEvent(event);

		int processed = 0;

		try {
			pstmtCurrentContigs.setInt(1, minlen);

			ResultSet rs = pstmtCurrentContigs.executeQuery();

			int count = 0;

			while (rs.next()) {
				int contig_id = rs.getInt(1);

				Contig contig = (Contig) hashByID.get(new Integer(contig_id));

				if (contig == null) {
					String gap4name = rs.getString(2);
					int ctglen = rs.getInt(3);
					int nreads = rs.getInt(4);
					java.util.Date created = rs.getTimestamp(5);
					java.util.Date updated = rs.getTimestamp(6);
					int project_id = rs.getInt(7);

					Project project = adb.getProjectByID(project_id);

					contig = new Contig(gap4name, contig_id, ctglen, nreads,
							created, updated, project, adb);

					registerNewContig(contig);
				}

				updateContig(contig, options);

				if (processor.processContig(contig))
					processed++;

				event.working(++count);
				fireEvent(event);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to process current contigs",
					conn, this);																								
		}

		event.end();
		fireEvent(event);

		return processed;
	}
	
	public Set<Contig> getChildContigs(Contig parent) throws ArcturusDatabaseException {
		if (parent == null)
			return null;
		
		HashSet<Contig> children = new HashSet<Contig>();
		
		try {
			pstmtChildContigs.setInt(1, parent.getID());

			ResultSet rs = pstmtChildContigs.executeQuery();

			while (rs.next()) {
				int contig_id = rs.getInt(1);

				Contig child = null;

				child = getContigByID(contig_id,
						ArcturusDatabase.CONTIG_BASIC_DATA);

				if (child != null)
					children.add(child);
			}
			
			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to fetch children of contig ID=" + parent.getID(),
					conn, this);																											
		}
		
		return children;
	}

	class SortableSegment implements Comparable {
		public int seq_id;
		public int cstart;
		public int rstart;
		public int length;

		public SortableSegment(int seq_id, int cstart, int rstart, int length) {
			this.seq_id = seq_id;
			this.cstart = cstart;
			this.rstart = rstart;
			this.length = length;
		}

		public int compareTo(Object o) {
			SortableSegment that = (SortableSegment) o;

			int diff = this.seq_id - that.seq_id;

			if (diff != 0)
				return diff;

			diff = this.cstart - that.cstart;

			return diff;
		}
	}

	class ContigSetBuilder implements ContigProcessor {
		private Set<Contig> contigs = new HashSet<Contig>();

		public boolean processContig(Contig contig) {
			contigs.add(contig);
			return true;
		}

		public Set<Contig> getContigSet() {
			return contigs;
		}
	}

	class SortableAlignToSCF implements Comparable {
		public int seq_id;
		public int seqstart;
		public int scfstart;
		public int length;

		public SortableAlignToSCF(int seq_id, int seqstart, int scfstart,
				int length) {
			this.seq_id = seq_id;
			this.seqstart = seqstart;
			this.scfstart = scfstart;
			this.length = length;
		}

		public int compareTo(Object o) {
			SortableAlignToSCF that = (SortableAlignToSCF) o;

			int diff = this.seq_id - that.seq_id;

			if (diff != 0)
				return diff;

			diff = this.seqstart - that.seqstart;

			return diff;
		}
	}

	class AlignToSCFComparator implements Comparator<AlignToSCF> {
		public int compare(AlignToSCF a1, AlignToSCF a2) {
			return a1.getStartInSequence() - a2.getStartInSequence();
		}

		public boolean equals(Object obj) {
			if (obj instanceof AlignToSCFComparator) {
				AlignToSCFComparator that = (AlignToSCFComparator) obj;
				return this == that;
			} else
				return false;
		}
	}

	class SegmentComparatorByContigPosition implements Comparator<BasicSegment> {
		public int compare(BasicSegment s1, BasicSegment s2) {
			int diff = s1.getReferenceStart() - s2.getReferenceStart();

			return diff;
		}

		public boolean equals(Object obj) {
			if (obj instanceof SegmentComparatorByContigPosition) {
				SegmentComparatorByContigPosition that = (SegmentComparatorByContigPosition) obj;
				return this == that;
			} else
				return false;
		}
	}

	public void preload() throws ArcturusDatabaseException {
		// This method does nothing, as we never want to preload all contigs.
	}
}
