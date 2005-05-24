import java.util.*;
import java.util.zip.*;
import java.sql.*;

import uk.ac.sanger.arcturus.data.*;

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

    private transient Vector eventListeners = new Vector();

    protected MappingComparator mappingComparator = new MappingComparator();
    protected SegmentComparator segmentComparator = new SegmentComparator();

    public Manager(Connection conn) throws SQLException {
	this.conn = conn;

	prepareStatements();

	preloadClones();
	preloadLigations();

	preloadAssemblies();
	preloadProjects();

	preloadSequencingVectors();
	preloadCloningVectors();
    }

    protected void prepareStatements() throws SQLException {
	String query;

	query = "select gap4name,CONTIG.length,nreads,created,updated,project_id,CONSENSUS.length,sequence,quality " + 
	    " from CONTIG left join CONSENSUS using(contig_id) where CONTIG.contig_id = ?";

	pstmtContigData = conn.prepareStatement(query);

	query = "select count(*) from MAPPING where contig_id = ?";

	pstmtCountMappings = conn.prepareStatement(query);

	query = "select count(*) from MAPPING left join SEGMENT using(mapping_id) where contig_id = ?";

	pstmtCountSegments = conn.prepareStatement(query);

	query = "select seq_id,cstart,cfinish,direction from MAPPING where contig_id=? " +
	    " order by seq_id asc";

	pstmtMappingData = conn.prepareStatement(query);

	query = "select seq_id,SEGMENT.cstart,rstart,length " +
	    " from MAPPING left join SEGMENT using(mapping_id) " +
	    " where contig_id = ?";

	// Previous server-side sorting clause:
	// + " order by MAPPING.seq_id asc, SEGMENT.cstart asc"

	pstmtSegmentData = conn.prepareStatement(query);

	query = "select seqlen,sequence,quality " +
	    " from MAPPING left join SEQUENCE using(seq_id) " +
	    " where contig_id = ? order by MAPPING.seq_id asc";

	pstmtSequenceData = conn.prepareStatement(query);

	query = "select MAPPING.seq_id,READS.read_id,readname,strand,chemistry,primer,asped," + 
	    " TEMPLATE.template_id,TEMPLATE.name,ligation_id " +
	    " from MAPPING,SEQ2READ,READS,TEMPLATE " + 
	    " where contig_id = ? and MAPPING.seq_id=SEQ2READ.seq_id and " +
	    " SEQ2READ.read_id=READS.read_id and READS.template_id=TEMPLATE.template_id " +
	    " order by MAPPING.seq_id asc";

	pstmtReadAndTemplateData = conn.prepareStatement(query);
    }

    protected void preloadClones() throws SQLException {
	String query = "select clone_id, name from CLONE";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int clone_id = rs.getInt(1);

	    Integer id = new Integer(clone_id);

	    if (! cloneByID.containsKey(id)) {
		String name = rs.getString(2);

		Clone clone = new Clone(name, clone_id, null);
		cloneByID.put(id, clone);
	    }
	}

	rs.close();
    }

    public Clone getCloneByID(int clone_id) {
	return (Clone)cloneByID.get(new Integer(clone_id));
    }

    protected void preloadLigations() throws SQLException {
	String query = "select ligation_id,name,clone_id,silow,sihigh from LIGATION";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int ligation_id = rs.getInt(1);

	    Integer id = new Integer(ligation_id);

	    if (! ligationByID.containsKey(id)) {
		String name = rs.getString(2);
		int clone_id = rs.getInt(3);
		int silow = rs.getInt(4);
		int sihigh = rs.getInt(5);

		Clone clone = getCloneByID(clone_id);

		Ligation ligation = new Ligation(name, ligation_id, clone, silow, sihigh, null);
		ligationByID.put(id, ligation);
	    }
	}

	rs.close();
    }

    public Ligation getLigationByID(int ligation_id) {
	return (Ligation)ligationByID.get(new Integer(ligation_id));
    }

    protected void preloadAssemblies() throws SQLException {
	String query = "select assembly_id,name,updated,created,creator from ASSEMBLY";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int assembly_id = rs.getInt(1);

	    Integer id = new Integer(assembly_id);

	    if (! assemblyByID.containsKey(id)) {
		String name = rs.getString(2);
		java.util.Date updated = rs.getTimestamp(3);
		java.util.Date created = rs.getTimestamp(4);
		String creator = rs.getString(5);

		Assembly assembly = new Assembly(name, assembly_id, updated, created, creator, null);
		assemblyByID.put(id, assembly);
	    }
	}

	rs.close();
    }

    public Assembly getAssemblyByID(int assembly_id) {
	return (Assembly)assemblyByID.get(new Integer(assembly_id));
    }

    protected void preloadProjects() throws SQLException {
	String query = "select project_id,assembly_id,name,updated,owner,locked,created,creator from PROJECT";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int project_id = rs.getInt(1);

	    Integer id = new Integer(project_id);

	    if (! projectByID.containsKey(id)) {
		int assembly_id = rs.getInt(2);
		String name = rs.getString(3);
		java.util.Date updated = rs.getTimestamp(4);
		String owner = rs.getString(5);
		java.util.Date locked = rs.getTimestamp(6);
		java.util.Date created = rs.getTimestamp(7);
		String creator = rs.getString(8);

		Assembly assembly = getAssemblyByID(assembly_id);

		Project project = new Project(project_id, assembly, name, updated, owner, locked,
					      created, creator, null);

		projectByID.put(id, project);
	    }
	}

	rs.close();
    }

    public Project getProjectByID(int project_id) {
	return (Project)projectByID.get(new Integer(project_id));
    }

    protected void preloadSequencingVectors() throws SQLException {
	String query = "select svector_id, name from SEQUENCEVECTOR";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int svector_id = rs.getInt(1);

	    Integer id = new Integer(svector_id);

	    if (! svectorByID.containsKey(id)) {
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

	    if (! cvectorByID.containsKey(id)) {
		String name = rs.getString(2);

		cvectorByID.put(id, name);
	    }
	}

	rs.close();
    }

    public Contig getContigByID(int contig_id) throws SQLException, DataFormatException {
	Contig contig = (Contig)contigByID.get(new Integer(contig_id));

	if (contig != null)
	    return contig;
	else
	    return loadContigByID(contig_id);
    }

    protected int parseStrand(String text) {
	if (text.equals("Forward"))
	    return Read.FORWARD;

	if (text.equals("Reverse"))
	    return Read.REVERSE;

	return Read.UNKNOWN;
    }

    protected int parsePrimer(String text) {
	if (text.equals("Universal_primer"))
	    return Read.UNIVERSAL_PRIMER;

	if (text.equals("Custom"))
	    return Read.CUSTOM_PRIMER;

	return Read.UNKNOWN;
    }

    protected int parseChemistry(String text) {
	if (text.equals("Dye_terminator"))
	    return Read.DYE_TERMINATOR;

	if (text.equals("Dye_primer"))
	    return Read.DYE_PRIMER;

	return Read.UNKNOWN;
    }

    public Sequence getSequenceByID(int seq_id) {
	return (Sequence)sequenceByID.get(new Integer(seq_id));
    }

    public Read getReadByID(int read_id) {
	return (Read)readByID.get(new Integer(read_id));
    }

    public Template getTemplateByID(int template_id) {
	return (Template)templateByID.get(new Integer(template_id));
    }

    public Contig loadContigByID(int contig_id) throws SQLException, DataFormatException {
	Contig contig = null;
	ManagerEvent event = new ManagerEvent(this);

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

	    contig = new Contig(gap4name, contig_id, ctglen, nreads, created, updated,
				project, null);

	    byte[] dna = inflate(cdna, consensus_length);
	    byte[] qual = inflate(cqual, consensus_length);

	    contig.setConsensus(dna, qual);

	    int dna_len = (dna == null) ? -1 : dna.length;
	    int qual_len = (qual == null) ? -1 : qual.length;

	    event.setMessage("Contig " + contig_id + " : " + ctglen + " bp, " + nreads + " reads, dna_len=" + dna_len +
			     ", qual_len=" + qual_len);
	    event.setState(ManagerEvent.START);
	    fireEvent(event);
	} else
	    return null;

	rs.close();

	pstmtCountMappings.setInt(1, contig_id);

	rs = pstmtCountMappings.executeQuery();

	rs.next();

	int nMappings = rs.getInt(1);

	rs.close();

	pstmtCountSegments.setInt(1, contig_id);

	rs = pstmtCountSegments.executeQuery();

	rs.next();

	int nSegments = rs.getInt(1);

	rs.close();

	/*
	 * Create an empty array of Mapping objects.
	 */

	Mapping mappings[] = new Mapping[nMappings];

	pstmtMappingData.setInt(1, contig_id);

	event.begin("Execute mapping query", nMappings);
	fireEvent(event);

	rs = pstmtMappingData.executeQuery();

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
	    int direction = forward ? Mapping.FORWARD : Mapping.REVERSE;

	    Sequence sequence = getSequenceByID(seq_id);

	    if (sequence == null) {
		sequence = new Sequence(seq_id, null);
		sequenceByID.put(new Integer(seq_id), sequence);
	    }

	    mappings[kMapping++] = new Mapping(sequence, cstart, cfinish, direction);

	    if ((kMapping % 10) == 0) {
		event.working(kMapping);
		fireEvent(event);
	    }
	}

	event.end();
	fireEvent(event);

	rs.close();

	Arrays.sort(mappings, mappingComparator);

	contig.setMappings(mappings);

	pstmtReadAndTemplateData.setInt(1, contig_id);

	event.begin("Execute read/template data query", nMappings);
	fireEvent(event);

	rs = pstmtReadAndTemplateData.executeQuery();

	event.end();
	fireEvent(event);

	kMapping = 0;

	event.begin("Loading read and template data", nMappings);
	fireEvent(event);

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
		template = new Template(templatename, template_id, ligation, null);
		templateByID.put(new Integer(template_id), template);
	    }

	    Read read = getReadByID(read_id);

	    if (read == null) {
		int iStrand = parseStrand(strand);

		int iChemistry = parseChemistry(chemistry);

		int iPrimer = parsePrimer(primer);

		read = new Read(readname, read_id, template, asped, iStrand, iPrimer, iChemistry, null);

		readByID.put(new Integer(read_id), read);
	    }

	    mappings[kMapping++].getSequence().setRead(read);

	    if ((kMapping % 10) == 0) {
		event.working(kMapping);
		fireEvent(event);
	    }
	}

	event.end();
	fireEvent(event);

	rs.close();

	kMapping = 0;

	Vector segv = new Vector(1000, 1000);

	pstmtSegmentData.setInt(1, contig_id);

	event.begin("Execute segment query", nMappings);
	fireEvent(event);

	rs = pstmtSegmentData.executeQuery();

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

	    segments[kSegment++] = new SortableSegment(seq_id, cstart, rstart, length);

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

	kMapping = 0;

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
		mappings[kMapping++].setSegments(segs);
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

	mappings[kMapping++].setSegments(segs);

	event.end();
	fireEvent(event);

	kMapping = 0;

	pstmtSequenceData.setInt(1, contig_id);

	event.begin("Execute sequence query", nMappings);
	fireEvent(event);

	rs = pstmtSequenceData.executeQuery();

	event.end();
	fireEvent(event);

	event.begin("Loading sequences", nMappings);
	fireEvent(event);

	while (rs.next()) {
	    int seqlen = rs.getInt(1);

	    Sequence sequence = mappings[kMapping++].getSequence();


	    byte[] cdna = rs.getBytes(2);

	    byte[] dna = inflate(cdna, seqlen);

	    sequence.setDNA(dna);
		
	    byte[] cqual = rs.getBytes(3);

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

	Integer id = new Integer(contig_id);

	contigByID.put(id, contig);

	return contig;
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

    public void addManagerEventListener(ManagerEventListener listener) {
	eventListeners.addElement(listener);
    }

    public void removeManagerEventListener(ManagerEventListener listener) {
	eventListeners.removeElement(listener);
    }

    private void fireEvent(ManagerEvent event) {
	Enumeration e = eventListeners.elements();
	while (e.hasMoreElements()) {
	    ManagerEventListener l = (ManagerEventListener)e.nextElement();
	    l.managerUpdate(event);
	}
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
	    SortableSegment that = (SortableSegment)o;

	    int diff = this.seq_id - that.seq_id;

	    if (diff != 0)
		return diff;

	    diff = this.cstart - that.cstart;

	    return diff;
	}
    }

    class MappingComparator implements Comparator {
	public int compare(Object o1, Object o2) {
	    Mapping mapping1 = (Mapping)o1;
	    Mapping mapping2 = (Mapping)o2;

	    int diff = mapping1.getContigStart() - mapping2.getContigStart();

	    return diff;
	}

	public boolean equals(Object obj) {
	    if (obj instanceof MappingComparator) {
		MappingComparator that = (MappingComparator)obj;
		return this == that;
	    } else
		return false;
	}
    }

    class SegmentComparator implements Comparator {
	public int compare(Object o1, Object o2) {
	    Segment segment1 = (Segment)o1;
	    Segment segment2 = (Segment)o2;

	    int diff = segment1.getReadStart() - segment2.getReadStart();

	    return diff;
	}

	public boolean equals(Object obj) {
	    if (obj instanceof SegmentComparator) {
		SegmentComparator that = (SegmentComparator)obj;
		return this == that;
	    } else
		return false;
	}
    }
}
