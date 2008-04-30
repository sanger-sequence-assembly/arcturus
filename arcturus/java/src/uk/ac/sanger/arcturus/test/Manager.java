package uk.ac.sanger.arcturus.test;

import java.util.*;
import java.util.zip.*;
import java.sql.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ReadManager;
import uk.ac.sanger.arcturus.database.ManagerEvent;
import uk.ac.sanger.arcturus.database.ManagerEventListener;

public class Manager {
	protected Map cloneByID = new HashMap();
	protected Map ligationByID = new HashMap();
	protected Map templateByID = new HashMap(20000);
	protected Map readByID = new HashMap(20000);
	protected Map sequenceByID = new HashMap(20000);
	protected Map projectByID = new HashMap();
	protected Map assemblyByID = new HashMap();
	protected Map svectorByID = new HashMap();
	protected Map cvectorByID = new HashMap();
	protected Map contigByID = new HashMap(20000);

	protected Inflater decompresser = new Inflater();

	protected Connection conn = null;

	protected PreparedStatement pstmtContigData = null;
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

	private transient Vector eventListeners = new Vector();

	protected MappingComparator mappingComparator = new MappingComparator();
	protected SegmentComparatorByContigPosition segmentComparator = new SegmentComparatorByContigPosition();

	protected ManagerEvent event = null;

	protected boolean loadSegments = true;
	protected boolean loadReadsAndTemplates = true;
	protected boolean loadSequences = true;
	protected boolean loadSequenceVectors = true;
	protected boolean loadCloningVectors = true;
	protected boolean loadQualityClipping = true;
	protected boolean loadAlignToSCF = true;

	protected boolean useCacheing = true;

	public Manager(Connection conn) throws SQLException {
		this.conn = conn;

		event = new ManagerEvent(null);

		prepareStatements();

		preloadClones();
		preloadLigations();

		preloadAssemblies();
		preloadProjects();

		preloadSequencingVectors();
		preloadCloningVectors();

		loadSegments = !Boolean.getBoolean("noLoadSegments");
		loadReadsAndTemplates = !Boolean.getBoolean("noLoadReadsAndTemplates");
		loadSequences = !Boolean.getBoolean("noLoadSequences");
		loadSequenceVectors = !Boolean.getBoolean("noLoadSequenceVectors");
		loadCloningVectors = !Boolean.getBoolean("noLoadCloningVectors");
		loadQualityClipping = !Boolean.getBoolean("noLoadQualityClipping");
		loadAlignToSCF = !Boolean.getBoolean("noLoadAlignToSCF");

		useCacheing = !Boolean.getBoolean("noCacheing");
	}

	protected void prepareStatements() throws SQLException {
		String query;

		query = "select gap4name,CONTIG.length,nreads,created,updated,project_id,CONSENSUS.length,sequence,quality "
				+ " from CONTIG left join CONSENSUS using(contig_id) where CONTIG.contig_id = ?";

		pstmtContigData = conn.prepareStatement(query);

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
				+ " TEMPLATE.template_id,TEMPLATE.name,ligation_id "
				+ " from MAPPING,SEQ2READ,READINFO,TEMPLATE "
				+ " where contig_id = ? and MAPPING.seq_id=SEQ2READ.seq_id and "
				+ " SEQ2READ.read_id=READINFO.read_id and READINFO.template_id=TEMPLATE.template_id";

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
	}

	protected void preloadClones() throws SQLException {
		String query = "select clone_id, name from CLONE";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int clone_id = rs.getInt(1);

			Integer id = new Integer(clone_id);

			if (!cloneByID.containsKey(id)) {
				String name = rs.getString(2);

				Clone clone = new Clone(name, clone_id, null);
				cloneByID.put(id, clone);
			}
		}

		rs.close();
	}

	public Clone getCloneByID(int clone_id) {
		return (Clone) cloneByID.get(new Integer(clone_id));
	}

	protected void preloadLigations() throws SQLException {
		String query = "select ligation_id,name,clone_id,silow,sihigh from LIGATION";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int ligation_id = rs.getInt(1);

			Integer id = new Integer(ligation_id);

			if (!ligationByID.containsKey(id)) {
				String name = rs.getString(2);
				int clone_id = rs.getInt(3);
				int silow = rs.getInt(4);
				int sihigh = rs.getInt(5);

				Clone clone = getCloneByID(clone_id);

				Ligation ligation = new Ligation(name, ligation_id, clone,
						silow, sihigh, null);
				ligationByID.put(id, ligation);
			}
		}

		rs.close();
	}

	public Ligation getLigationByID(int ligation_id) {
		return (Ligation) ligationByID.get(new Integer(ligation_id));
	}

	protected void preloadAssemblies() throws SQLException {
		String query = "select assembly_id,name,updated,created,creator from ASSEMBLY";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int assembly_id = rs.getInt(1);

			Integer id = new Integer(assembly_id);

			if (!assemblyByID.containsKey(id)) {
				String name = rs.getString(2);
				java.util.Date updated = rs.getTimestamp(3);
				java.util.Date created = rs.getTimestamp(4);
				String creator = rs.getString(5);

				Assembly assembly = new Assembly(name, assembly_id, updated,
						created, creator, null);
				assemblyByID.put(id, assembly);
			}
		}

		rs.close();
	}

	public Assembly getAssemblyByID(int assembly_id) {
		return (Assembly) assemblyByID.get(new Integer(assembly_id));
	}

	protected void preloadProjects() throws SQLException {
		String query = "select project_id,assembly_id,name,updated,owner,locked,lockowner,created,creator from PROJECT";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int project_id = rs.getInt(1);

			Integer id = new Integer(project_id);

			if (!projectByID.containsKey(id)) {
				int assembly_id = rs.getInt(2);
				String name = rs.getString(3);
				java.util.Date updated = rs.getTimestamp(4);
				String owner = rs.getString(5);
				java.util.Date locked = rs.getTimestamp(6);
				String lockowner = rs.getString(7);
				java.util.Date created = rs.getTimestamp(8);
				String creator = rs.getString(9);

				Assembly assembly = getAssemblyByID(assembly_id);

				Project project = new Project(project_id, assembly, name,
						updated, owner, locked, lockowner, created, creator, Project.UNKNOWN, null);

				projectByID.put(id, project);
			}
		}

		rs.close();
	}

	public Project getProjectByID(int project_id) {
		return (Project) projectByID.get(new Integer(project_id));
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

	public Contig getContigByID(int contig_id) throws SQLException,
			DataFormatException {
		Contig contig = (Contig) contigByID.get(new Integer(contig_id));

		if (contig != null)
			return contig;
		else
			return loadContigByID(contig_id);
	}

	public Sequence getSequenceByID(int seq_id) {
		return (Sequence) sequenceByID.get(new Integer(seq_id));
	}

	public Read getReadByID(int read_id) {
		return (Read) readByID.get(new Integer(read_id));
	}

	public Template getTemplateByID(int template_id) {
		return (Template) templateByID.get(new Integer(template_id));
	}

	public Contig loadContigByID(int contig_id) throws SQLException,
			DataFormatException {
		Contig contig = createContig(contig_id);

		if (contig == null)
			return null;

		int nMappings = getMappingCount(contig_id);

		/*
		 * Create an empty array of Mapping objects.
		 */

		Mapping mappings[] = new Mapping[nMappings];

		getMappings(contig_id, mappings);

		Map mapmap = createMappingsMap(mappings);

		if (loadReadsAndTemplates)
			getReadAndTemplateData(contig_id, mapmap);

		if (loadSegments)
			getSegmentData(contig_id, mapmap);

		if (loadSequences)
			getSequenceData(contig_id, mapmap);

		if (loadSequenceVectors)
			getSequenceVectorData(contig_id, mapmap);

		if (loadCloningVectors)
			getCloningVectorData(contig_id, mapmap);

		if (loadQualityClipping)
			getQualityClippingData(contig_id, mapmap);

		if (loadAlignToSCF)
			getAlignToSCF(contig_id, mapmap);

		Arrays.sort(mappings, mappingComparator);

		contig.setMappings(mappings);

		Integer id = new Integer(contig_id);

		if (useCacheing)
			contigByID.put(id, contig);

		return contig;
	}

	private Contig createContig(int contig_id) throws SQLException,
			DataFormatException {
		Contig contig = null;

		pstmtContigData.setInt(1, contig_id);

		ResultSet rs = pstmtContigData.executeQuery();

		if (rs.next()) {
			String gap4name = rs.getString(1);
			int ctglen = rs.getInt(2);
			int nreads = rs.getInt(3);
			java.util.Date created = rs.getTimestamp(4);
			java.util.Date updated = rs.getTimestamp(5);
			int project_id = rs.getInt(6);
			int consensus_length = rs.getInt(7);
			byte[] cdna = rs.getBytes(8);
			byte[] cqual = rs.getBytes(9);

			Project project = getProjectByID(project_id);

			contig = new Contig(gap4name, contig_id, ctglen, nreads, created,
					updated, project, null);

			byte[] dna = inflate(cdna, consensus_length);
			byte[] qual = inflate(cqual, consensus_length);

			contig.setConsensus(dna, qual);

			int dna_len = (dna == null) ? -1 : dna.length;
			int qual_len = (qual == null) ? -1 : qual.length;

			event.setMessage("Contig " + contig_id + " : " + ctglen + " bp, "
					+ nreads + " reads, dna_len=" + dna_len + ", qual_len="
					+ qual_len);
			event.setState(ManagerEvent.START);
			fireEvent(event);
		} else
			return null;

		rs.close();

		return contig;
	}

	private int getMappingCount(int contig_id) throws SQLException {
		pstmtCountMappings.setInt(1, contig_id);

		ResultSet rs = pstmtCountMappings.executeQuery();

		rs.next();

		int nMappings = rs.getInt(1);

		rs.close();

		return nMappings;
	}

	private void getMappings(int contig_id, Mapping[] mappings)
			throws SQLException {
		int nMappings = mappings.length;

		pstmtMappingData.setInt(1, contig_id);

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

			Sequence sequence = getSequenceByID(seq_id);

			if (sequence == null) {
				sequence = new Sequence(seq_id, null, length);

				sequenceByID.put(new Integer(seq_id), sequence);
			}

			mappings[kMapping++] = new Mapping(sequence, cstart, cfinish,
					forward);

			if ((kMapping % 10) == 0) {
				event.working(kMapping);
				fireEvent(event);
			}
		}

		event.end();
		fireEvent(event);

		rs.close();
	}

	private void getReadAndTemplateData(int contig_id, Map mapmap)
			throws SQLException {
		int nMappings = mapmap.size();

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

			Ligation ligation = getLigationByID(ligation_id);

			Template template = getTemplateByID(template_id);

			if (template == null) {
				template = new Template(templatename, template_id, ligation,
						null);
				if (useCacheing)
					templateByID.put(new Integer(template_id), template);
			}

			Read read = getReadByID(read_id);

			if (read == null) {
				int iStrand = ReadManager.parseStrand(strand);

				int iChemistry = ReadManager.parseChemistry(chemistry);

				int iPrimer = ReadManager.parsePrimer(primer);

				read = new Read(readname, read_id, template, asped, iStrand,
						iPrimer, iChemistry, null);

				if (useCacheing)
					readByID.put(new Integer(read_id), read);
			}

			Mapping mapping = (Mapping) mapmap.get(new Integer(seq_id));
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
	}

	private int getSegmentCount(int contig_id) throws SQLException {
		pstmtCountSegments.setInt(1, contig_id);

		ResultSet rs = pstmtCountSegments.executeQuery();

		rs.next();

		int nSegments = rs.getInt(1);

		rs.close();

		return nSegments;
	}

	private void getSegmentData(int contig_id, Map mapmap) throws SQLException {
		int nSegments = getSegmentCount(contig_id);

		int nMappings = mapmap.size();

		Vector segv = new Vector(1000, 1000);

		pstmtSegmentData.setInt(1, contig_id);

		event.begin("Execute segment query", nMappings);
		fireEvent(event);

		ResultSet rs = pstmtSegmentData.executeQuery();

		event.end();
		fireEvent(event);

		event.begin("Loading segments", nSegments);
		fireEvent(event);

		SortableSegment segments[] = new SortableSegment[nSegments];

		int kSegment = 0;

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int cstart = rs.getInt(2);
			int rstart = rs.getInt(3);
			int length = rs.getInt(4);

			segments[kSegment++] = new SortableSegment(seq_id, cstart, rstart,
					length);

			if ((kSegment % 50) == 0) {
				event.working(kSegment);
				fireEvent(event);
			}
		}

		rs.close();

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

		for (kSegment = 0; kSegment < nSegments; kSegment++) {
			int next_seq_id = segments[kSegment].seq_id;
			int cstart = segments[kSegment].cstart;
			int rstart = segments[kSegment].rstart;
			int length = segments[kSegment].length;

			if ((next_seq_id != current_seq_id) && (current_seq_id > 0)) {
				Segment segs[] = new Segment[segv.size()];
				segv.toArray(segs);
				Arrays.sort(segs, segmentComparator);
				Mapping mapping = (Mapping) mapmap.get(new Integer(
						current_seq_id));
				mapping.setSegments(segs);
				segv.clear();
			}

			segv.add(new Segment(cstart, rstart, length));

			current_seq_id = next_seq_id;

			if ((kSegment % 50) == 0) {
				event.working(kSegment);
				fireEvent(event);
			}
		}

		Segment segs[] = new Segment[segv.size()];

		segv.toArray(segs);

		Arrays.sort(segs, segmentComparator);

		Mapping mapping = (Mapping) mapmap.get(new Integer(current_seq_id));
		mapping.setSegments(segs);

		event.end();
		fireEvent(event);

	}

	private void getSequenceData(int contig_id, Map mapmap)
			throws SQLException, DataFormatException {
		int nMappings = mapmap.size();

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

			Mapping mapping = (Mapping) mapmap.get(new Integer(seq_id));
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

	private byte[] inflate(byte[] cdata, int length) throws DataFormatException {
		if (cdata == null)
			return null;

		byte[] data = new byte[length];

		decompresser.setInput(cdata, 0, cdata.length);
		decompresser.inflate(data, 0, data.length);
		decompresser.reset();

		return data;
	}

	private Map createMappingsMap(Mapping[] mappings) {
		Map hash = new HashMap(mappings.length);

		for (int i = 0; i < mappings.length; i++) {
			Mapping value = mappings[i];
			int sequence_id = value.getSequence().getID();
			Integer key = new Integer(sequence_id);
			hash.put(key, value);
		}

		return hash;
	}

	private void getSequenceVectorData(int contig_id, Map mapmap)
			throws SQLException {
		event.begin("Loading sequence vector data", 0);
		fireEvent(event);

		pstmtSequenceVector.setInt(1, contig_id);

		ResultSet rs = pstmtSequenceVector.executeQuery();

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int svector_id = rs.getInt(2);
			int svleft = rs.getInt(3);
			int svright = rs.getInt(4);

			Mapping mapping = (Mapping) mapmap.get(new Integer(seq_id));

			Sequence sequence = mapping.getSequence();

			String svector = (String) svectorByID.get(new Integer(svector_id));

			Clipping clipping = new Clipping(Clipping.SVEC, svector, svleft,
					svright);

			if (svleft == 1)
				sequence.setSequenceVectorClippingLeft(clipping);
			else
				sequence.setSequenceVectorClippingRight(clipping);
		}

		rs.close();

		event.end();
		fireEvent(event);
	}

	private void getCloningVectorData(int contig_id, Map mapmap)
			throws SQLException {
		event.begin("Loading cloning vector data", 0);
		fireEvent(event);

		pstmtCloningVector.setInt(1, contig_id);

		ResultSet rs = pstmtCloningVector.executeQuery();

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int cvector_id = rs.getInt(2);
			int cvleft = rs.getInt(3);
			int cvright = rs.getInt(4);

			Mapping mapping = (Mapping) mapmap.get(new Integer(seq_id));

			Sequence sequence = mapping.getSequence();

			String cvector = (String) cvectorByID.get(new Integer(cvector_id));

			sequence.setCloningVectorClipping(new Clipping(Clipping.CVEC,
					cvector, cvleft, cvright));
		}

		rs.close();

		event.end();
		fireEvent(event);
	}

	private void getQualityClippingData(int contig_id, Map mapmap)
			throws SQLException {
		event.begin("Loading quality clipping data", 0);
		fireEvent(event);

		pstmtQualityClipping.setInt(1, contig_id);

		ResultSet rs = pstmtQualityClipping.executeQuery();

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int qleft = rs.getInt(2);
			int qright = rs.getInt(3);

			Mapping mapping = (Mapping) mapmap.get(new Integer(seq_id));

			Sequence sequence = mapping.getSequence();

			sequence.setQualityClipping(new Clipping(Clipping.QUAL, null,
					qleft, qright));
		}

		rs.close();

		event.end();
		fireEvent(event);
	}

	private void getAlignToSCF(int contig_id, Map mapmap) throws SQLException {
		event.begin("Loading AlignToSCF data", 0);
		fireEvent(event);

		pstmtAlignToSCF.setInt(1, contig_id);

		ResultSet rs = pstmtAlignToSCF.executeQuery();

		Vector alignments = new Vector();

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int seqstart = rs.getInt(2);
			int scfstart = rs.getInt(3);
			int length = rs.getInt(4);

			alignments.add(new SortableAlignToSCF(seq_id, seqstart, scfstart,
					length));
		}

		rs.close();

		SortableAlignToSCF[] array = new SortableAlignToSCF[alignments.size()];

		alignments.toArray(array);

		Arrays.sort(array);

		alignments.clear();

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
				Mapping mapping = (Mapping) mapmap.get(new Integer(
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
			Mapping mapping = (Mapping) mapmap.get(new Integer(current_seq_id));
			mapping.getSequence().setAlignToSCF(a2scf);
		}

		event.end();
		fireEvent(event);
	}

	public void addManagerEventListener(ManagerEventListener listener) {
		eventListeners.addElement(listener);
	}

	public void removeManagerEventListener(ManagerEventListener listener) {
		eventListeners.removeElement(listener);
	}

	private void fireEvent(ManagerEvent event) {
		Enumeration e = eventListeners.elements();
		while (e.hasMoreElements()) {
			ManagerEventListener l = (ManagerEventListener) e.nextElement();
			l.managerUpdate(event);
		}
	}

	public int getSequenceMapSize() {
		return sequenceByID.size();
	}

	public void clearSequenceMap() {
		sequenceByID.clear();
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

	class AlignToSCFComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			AlignToSCF aligntoscf1 = (AlignToSCF) o1;
			AlignToSCF aligntoscf2 = (AlignToSCF) o2;

			int diff = aligntoscf1.getStartInSequence()
					- aligntoscf2.getStartInSequence();

			return diff;
		}

		public boolean equals(Object obj) {
			if (obj instanceof AlignToSCFComparator) {
				AlignToSCFComparator that = (AlignToSCFComparator) obj;
				return this == that;
			} else
				return false;
		}
	}

	class MappingComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			Mapping mapping1 = (Mapping) o1;
			Mapping mapping2 = (Mapping) o2;

			int diff = mapping1.getContigStart() - mapping2.getContigStart();

			return diff;
		}

		public boolean equals(Object obj) {
			if (obj instanceof MappingComparator) {
				MappingComparator that = (MappingComparator) obj;
				return this == that;
			} else
				return false;
		}
	}

	class SegmentComparatorByContigPosition implements Comparator {
		public int compare(Object o1, Object o2) {
			Segment segment1 = (Segment) o1;
			Segment segment2 = (Segment) o2;

			int diff = segment1.getContigStart() - segment2.getContigStart();

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
}
