package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.zip.*;
import java.util.List;
import java.util.Vector;
import java.util.Map;
import java.util.HashMap;
import java.io.*;
import java.text.*;

public class ContigCAFWriter {
	public static final int OK = 0;
	public static final int CONTIG_NOT_FOUND = 1;
	public static final int NO_CONSENSUS = 2;
	public static final int READ_BASIC_DATA_NOT_FOUND = 3;
	public static final int READ_CLONE_DATA_NOT_FOUND = 4;
	public static final int NO_SEQUENCE_DATA = 5;

	private ArcturusDatabase adb;
	private Connection conn;

	private PreparedStatement pstmtContigData;
	private PreparedStatement pstmtConsensus;
	private PreparedStatement pstmtMapping;
	private PreparedStatement pstmtSegment;
	private PreparedStatement pstmtContigTag;
	private PreparedStatement pstmtReadBasicData;
	private PreparedStatement pstmtReadCloneData;
	private PreparedStatement pstmtSequence;
	private PreparedStatement pstmtSequenceVector;
	private PreparedStatement pstmtCloningVector;
	private PreparedStatement pstmtQualityClipping;
	private PreparedStatement pstmtReadTag;
	private PreparedStatement pstmtAlignToSCF;

	private PreparedStatement pstmtContigsForProject;

	private Map<Integer, String> dictBasecaller = new HashMap<Integer, String>();
	private Map<Integer, String> dictReadStatus = new HashMap<Integer, String>();
	private Map<Integer, String> dictClone = new HashMap<Integer, String>();

	class Ligation {
		private String name;
		private String cloneName;
		private int silow;
		private int sihigh;

		public Ligation(String name, String cloneName, int silow, int sihigh) {
			this.name = name;
			this.cloneName = cloneName;
			this.silow = silow;
			this.sihigh = sihigh;
		}

		public String getName() {
			return name;
		}

		public String getCloneName() {
			return cloneName;
		}

		public int getSilow() {
			return silow;
		}

		public int getSihigh() {
			return sihigh;
		}
	}

	private Map<Integer, Ligation> dictLigation = new HashMap<Integer, Ligation>();

	private DateFormat dateformat = new SimpleDateFormat("yyyy-MM-dd");

	private DecimalFormat decimalformat = new DecimalFormat("00000000");

	private Inflater decompresser = new Inflater();

	public ContigCAFWriter(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;
		
		conn = adb.getPooledConnection(this);

		try {
			prepareStatements();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise CAF writer", conn, this);
		}
		
		try {
			createDictionaries();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to create dictionaries for CAF writer", conn, this);
		}
	}

	private void prepareStatements() throws SQLException {
		String sql = "select nreads from CONTIG where contig_id = ?";

		pstmtContigData = conn.prepareStatement(sql);

		sql = "select sequence,quality,length from CONSENSUS where contig_id = ?";

		pstmtConsensus = conn.prepareStatement(sql);

		sql = "select mapping_id,direction,MAPPING.seq_id,READINFO.read_id,readname"
				+ "  from MAPPING left join (SEQ2READ,READINFO)"
				+ "  on (MAPPING.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id)"
				+ "  where contig_id = ?" + "  order by cstart asc";

		pstmtMapping = conn.prepareStatement(sql);

		sql = "select MAPPING.mapping_id,SEGMENT.cstart,rstart,length"
				+ " from MAPPING left join SEGMENT using (mapping_id)"
				+ " where  contig_id = ?"
				+ " order by MAPPING.cstart asc,MAPPING.mapping_id asc,rstart asc";

		pstmtSegment = conn.prepareStatement(sql);

		sql = "select tagtype,cstart,cfinal,tagcomment"
				+ " from TAG2CONTIG left join CONTIGTAG using(tag_id)"
				+ " where contig_id = ? and tagtype is not null order by cstart asc";

		pstmtContigTag = conn.prepareStatement(sql);

		sql = "select readname,asped,strand,primer,chemistry,basecaller,status"
				+ " from READINFO where read_id = ?";

		pstmtReadBasicData = conn.prepareStatement(sql);

		sql = "select name,ligation_id"
				+ " from READINFO left join TEMPLATE using(template_id)"
				+ " where read_id = ?";

		pstmtReadCloneData = conn.prepareStatement(sql);

		sql = "select sequence,quality,seqlen from SEQUENCE where seq_id = ?";

		pstmtSequence = conn.prepareStatement(sql);

		sql = "select svleft,svright,name from SEQVEC left join SEQUENCEVECTOR using(svector_id)"
				+ " where seq_id = ?";

		pstmtSequenceVector = conn.prepareStatement(sql);

		sql = "select cvleft,cvright,name from CLONEVEC left join CLONINGVECTOR using(cvector_id)"
				+ " where seq_id = ?";

		pstmtCloningVector = conn.prepareStatement(sql);

		sql = "select qleft,qright from QUALITYCLIP where seq_id = ?";

		pstmtQualityClipping = conn.prepareStatement(sql);

		sql = "select tagtype,pstart,pfinal,comment from READTAG where seq_id = ? and"
				+ " (deprecated is null or deprecated = 'N')";

		pstmtReadTag = conn.prepareStatement(sql);
		
		sql = "select startinseq,startinscf,length from ALIGN2SCF where seq_id = ?";
		
		pstmtAlignToSCF = conn.prepareStatement(sql);
		
		sql = "select contig_id from"
				+ " CURRENTCONTIGS left join PROJECT using(project_id)"
				+ " where name=?";

		pstmtContigsForProject = conn.prepareStatement(sql);
	}

	private void createDictionaries() throws SQLException {
		Statement stmt = conn.createStatement();

		String sql = "select basecaller_id,name from BASECALLER";

		ResultSet rs = stmt.executeQuery(sql);

		while (rs.next()) {
			int basecaller_id = rs.getInt(1);
			String name = rs.getString(2);

			dictBasecaller.put(basecaller_id, name);
		}

		rs.close();

		sql = "select status_id,name from STATUS";

		rs = stmt.executeQuery(sql);

		while (rs.next()) {
			int status_id = rs.getInt(1);
			String name = rs.getString(2);

			dictReadStatus.put(status_id, name);
		}

		rs.close();

		sql = "select clone_id,name from CLONE";

		rs = stmt.executeQuery(sql);

		while (rs.next()) {
			int clone_id = rs.getInt(1);
			String name = rs.getString(2);

			dictClone.put(clone_id, name);
		}

		rs.close();

		sql = "select ligation_id,name,clone_id,silow,sihigh from LIGATION";

		rs = stmt.executeQuery(sql);

		while (rs.next()) {
			int ligation_id = rs.getInt(1);
			String name = rs.getString(2);
			int clone_id = rs.getInt(3);
			int silow = rs.getInt(4);
			int sihigh = rs.getInt(5);

			String cloneName = dictClone.get(clone_id);

			Ligation ligation = new Ligation(name, cloneName, silow, sihigh);

			dictLigation.put(ligation_id, ligation);
		}

		stmt.close();
	}

	public int getContigReadCount(int contigid) throws ArcturusDatabaseException {
		int nreads = 0;
		
		try {
		pstmtContigData.setInt(1, contigid);

		ResultSet rs = pstmtContigData.executeQuery();

		nreads = rs.next() ? rs.getInt(1) : -1;

		rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get contig read count for contig ID=" + contigid, conn, this);
		}

		return nreads;
	}

	class Mapping {
		private int seqid;
		private int readid;
		private boolean forward;
		private String readname;

		public Mapping(int seqid, int readid, boolean forward, String readname) {
			this.seqid = seqid;
			this.readid = readid;
			this.forward = forward;
			this.readname = readname;
		}

		public int getSequenceID() {
			return seqid;
		}

		public int getReadID() {
			return readid;
		}

		public boolean isForward() {
			return forward;
		}

		public String getReadname() {
			return readname;
		}
	}
	
	public int writeContigAsCAF(Contig contig, PrintWriter pw) 
		throws ArcturusDatabaseException {
		int contigid = contig.getID();
		int nreads = contig.getReadCount();
		
		return writeContigAsCAF(contigid, nreads, pw);
	}

	public int writeContigAsCAF(int contigid, int nreads, PrintWriter pw)
			throws ArcturusDatabaseException {
		String contigname = "Contig" + decimalformat.format(contigid);

		pw.println("Sequence : " + contigname);
		pw.println("Is_contig");
		pw.println("Unpadded");

		Map<Integer, Mapping> mappings = new HashMap<Integer, Mapping>(nreads);

		try {
			pstmtMapping.setInt(1, contigid);

			ResultSet rs = pstmtMapping.executeQuery();

			while (rs.next()) {
				int mappingid = rs.getInt(1);
				String direction = rs.getString(2);
				int seqid = rs.getInt(3);
				int readid = rs.getInt(4);
				String readname = rs.getString(5);

				boolean forward = direction.equalsIgnoreCase("Forward");

				Mapping mapping = new Mapping(seqid, readid, forward, readname);

				mappings.put(mappingid, mapping);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get mappings for contig ID=" + contigid, conn, this);
		}

		try {
			pstmtSegment.setInt(1, contigid);

			ResultSet rs = pstmtSegment.executeQuery();

			int lastmappingid = -1;
			boolean forward = false;
			String readname = null;

			while (rs.next()) {
				int mappingid = rs.getInt(1);
				int cstart = rs.getInt(2);
				int rstart = rs.getInt(3);
				int seglen = rs.getInt(4);

				if (mappingid != lastmappingid) {
					Mapping mapping = mappings.get(mappingid);

					forward = mapping.isForward();
					readname = mapping.getReadname();
				}

				int rfinish = forward ? rstart + seglen - 1 : rstart - seglen
						+ 1;
				int cfinish = cstart + seglen - 1;

				if (forward)
					pw.println("Assembled_from " + readname + " " + cstart
							+ " " + cfinish + " " + rstart + " " + rfinish);
				else
					pw.println("Assembled_from " + readname + " " + cfinish
							+ " " + cstart + " " + rfinish + " " + rstart);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get segments for contig ID=" + contigid, conn, this);
		}

		try {
			pstmtContigTag.setInt(1, contigid);

			ResultSet rs = pstmtContigTag.executeQuery();

			while (rs.next()) {
				String tagtype = rs.getString(1);
				int tagstart = rs.getInt(2);
				int tagfinish = rs.getInt(3);
				String tagcomment = rs.getString(4);

				pw.print("Tag " + tagtype + " " + tagstart + " " + tagfinish);
				if (tagcomment != null)
					pw.print(" \"" + tagcomment + "\"");
				pw.println();
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get tags for contig ID=" + contigid, conn, this);
		}

		pw.println();
		
		byte[] dna = null;
		byte[] quality = null;
		int seqlen = 0;

		try {
			pstmtConsensus.setInt(1, contigid);

			ResultSet rs = pstmtConsensus.executeQuery();

			if (rs.next()) {
				dna = rs.getBytes(1);
				quality = rs.getBytes(2);
				seqlen = rs.getInt(3);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get consensus sequence for contig ID=" + contigid, conn, this);
		}

		if (dna == null || quality == null)
			return NO_CONSENSUS;

		try {
			dna = decodeCompressedData(dna, seqlen);
		} catch (DataFormatException e) {
			handleDataFormatException(e, "Failed to decompress DNA data for contig ID=" + contigid);
		}
		
		try {
			quality = decodeCompressedData(quality, seqlen);
		} catch (DataFormatException e) {
			handleDataFormatException(e, "Failed to decompress quality data for contig ID=" + contigid);
		}

		pw.println("DNA : " + contigname);

		writeDNA(dna, pw);

		pw.println();

		pw.println("BaseQuality : " + contigname);

		writeQuality(quality, pw);

		pw.println();

		for (Mapping mapping : mappings.values()) {
			int readid = mapping.getReadID();
			int seqid = mapping.getSequenceID();
			
			int rc = writeRead(readid, seqid, pw);

			if (rc != OK)
				return rc;
		}

		return OK;
	}

	private void handleDataFormatException(DataFormatException e, String message) throws ArcturusDatabaseException {
		throw new ArcturusDatabaseException(e, message);
	}

	private int writeRead(int readid, int seqid, PrintWriter pw)
			throws ArcturusDatabaseException {
		String readname = null;
		java.util.Date asped = null;
		String strand = null;
		String primer = null;
		String chemistry = null;
		String basecaller = null;
		String status = null;
		
		try {
			pstmtReadBasicData.setInt(1, readid);

			ResultSet rs = pstmtReadBasicData.executeQuery();

			if (!rs.next()) {
				rs.close();
				return READ_BASIC_DATA_NOT_FOUND;
			}

			readname = rs.getString(1);
			asped = rs.getDate(2);
			strand = rs.getString(3);
			primer = rs.getString(4);
			chemistry = rs.getString(5);

			int basecaller_id = rs.getInt(6);

			basecaller = rs.wasNull() ? null : dictBasecaller
					.get(basecaller_id);

			int status_id = rs.getInt(7);

			status = rs.wasNull() ? null : dictReadStatus.get(status_id);

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get basic data for read ID=" + readid, conn, this);
		}

		String template = null;
		String ligation = null;
		int silow = -1;
		int sihigh = -1;
		String clone = null;
		
		try {
			pstmtReadCloneData.setInt(1, readid);

			ResultSet rs = pstmtReadCloneData.executeQuery();

			template = null;
			ligation = null;
			silow = -1;
			sihigh = -1;
			clone = null;

			if (rs.next()) {
				template = rs.getString(1);
				int ligation_id = rs.getInt(2);

				Ligation l = dictLigation.get(ligation_id);

				if (l != null) {
					ligation = l.getName();
					silow = l.getSilow();
					sihigh = l.getSihigh();
					clone = l.getCloneName();
				}
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get clone data for read ID=" + readid, conn, this);
		}

		StringBuffer buffer = new StringBuffer(4096);

		buffer.append("Sequence : " + readname + "\n");
		buffer.append("Is_read\n");
		buffer.append("Unpadded\n");

		buffer.append("SCF_File " + readname + "SCF\n");

		buffer.append("Template " + template + "\n");

		if (silow > 0 && sihigh > 0)
			buffer.append("Insert_size " + silow + " " + sihigh + "\n");

		if (ligation != null)
			buffer.append("Ligation_no " + ligation + "\n");

		if (primer != null)
			buffer.append("Primer " + primer + "\n");

		if (strand != null)
			buffer.append("Strand " + strand + "\n");

		if (chemistry != null)
			buffer.append("Dye " + chemistry + "\n");

		if (clone != null)
			buffer.append("Clone " + clone + "\n");

		buffer.append("ProcessStatus " + status + "\n");

		if (asped != null)
			buffer.append("Asped " + dateformat.format(asped) + "\n");

		if (basecaller != null)
			buffer.append("Base_caller " + basecaller + "\n");

		try {
			pstmtQualityClipping.setInt(1, seqid);

			ResultSet rs = pstmtQualityClipping.executeQuery();

			while (rs.next()) {
				int qleft = rs.getInt(1);
				int qright = rs.getInt(2);
				buffer.append("Clipping QUAL " + qleft + " " + qright + "\n");
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get quality clipping data for read ID=" + readid, conn, this);
		}

		try {
			pstmtSequenceVector.setInt(1, seqid);

			ResultSet rs = pstmtSequenceVector.executeQuery();

			while (rs.next()) {
				int svleft = rs.getInt(1);
				int svright = rs.getInt(2);
				String svname = rs.getString(3);
				buffer.append("Seq_vec SVEC " + svleft + " " + svright + " \""
						+ svname + "\"" + "\n");
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get sequence vector data for read ID=" + readid, conn, this);
		}
		

		try {
			pstmtCloningVector.setInt(1, seqid);

			ResultSet rs = pstmtCloningVector.executeQuery();

			while (rs.next()) {
				int cvleft = rs.getInt(1);
				int cvright = rs.getInt(2);
				String cvname = rs.getString(3);
				buffer.append("Clone_vec CVEC " + cvleft + " " + cvright
						+ " \"" + cvname + "\"" + "\n");
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get cloning vector data for read ID=" + readid, conn, this);
		}

		try {
			pstmtReadTag.setInt(1, seqid);

			ResultSet rs = pstmtReadTag.executeQuery();

			while (rs.next()) {
				String tagtype = rs.getString(1);
				int tagstart = rs.getInt(2);
				int tagfinish = rs.getInt(3);
				String tagcomment = rs.getString(4);

				buffer.append("Tag " + tagtype + " " + tagstart + " "
						+ tagfinish);
				if (tagcomment != null)
					buffer.append(" \"" + tagcomment + "\"");
				buffer.append('\n');
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get read tag data for read ID=" + readid, conn, this);
		}

		boolean hasAlignToSCF = false;

		try {
			pstmtAlignToSCF.setInt(1, seqid);

			ResultSet rs = pstmtAlignToSCF.executeQuery();


			while (rs.next()) {
				hasAlignToSCF = true;

				int startInSequence = rs.getInt(1);
				int startInSCF = rs.getInt(2);

				int length = rs.getInt(3);

				int endInSequence = startInSequence + length - 1;
				int endInSCF = startInSCF + length - 1;

				buffer.append("Align_to_SCF " + startInSequence + " "
						+ endInSequence + " " + startInSCF + " " + endInSCF
						+ "\n");
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get AlignToSCF data for read ID=" + readid, conn, this);
		}
		
		byte[] dna = null;
		byte[] quality = null;
		int seqlen = 0;
		
		try {
			pstmtSequence.setInt(1, seqid);

			ResultSet rs = pstmtSequence.executeQuery();

			if (rs.next()) {
				dna = rs.getBytes(1);
				quality = rs.getBytes(2);
				seqlen = rs.getInt(3);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get sequence data for read ID=" + readid, conn, this);
		}
		
		if (dna == null || quality == null)
			return NO_SEQUENCE_DATA;
		
		if (!hasAlignToSCF)
			buffer.append("Align_to_SCF 1 " + seqlen + " 1 " + seqlen + "\n");

		pw.println(buffer.toString());

		pw.println();

		try {
			dna = decodeCompressedData(dna, seqlen);
		} catch (DataFormatException e) {
			handleDataFormatException(e, "Faled to decompress DNA data for read ID=" + readid);
		}
		
		try {
			quality = decodeCompressedData(quality, seqlen);
		} catch (DataFormatException e) {
			handleDataFormatException(e, "Faled to decompress quality data for read ID=" + readid);
		}

		pw.println("DNA : " + readname);

		writeDNA(dna, pw);

		pw.println();

		pw.println("BaseQuality : " + readname);

		writeQuality(quality, pw);

		pw.println();

		return OK;
	}

	private void writeReadsForContig(int contigid, PrintWriter pwReads)
			throws ArcturusDatabaseException {
		try {
		pstmtMapping.setInt(1, contigid);

		ResultSet rs = pstmtMapping.executeQuery();

		while (rs.next()) {
			int seqid = rs.getInt(3);
			int readid = rs.getInt(4);

			writeRead(readid, seqid, pwReads);
		}

		rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to write reads for contig ID=" + contigid, conn, this);
		}
	}

	private byte[] decodeCompressedData(byte[] compressed, int length)
			throws DataFormatException {
		byte[] buffer = new byte[length];

		decompresser.setInput(compressed, 0, compressed.length);
		decompresser.inflate(buffer, 0, buffer.length);
		decompresser.reset();

		return buffer;
	}

	private void writeDNA(byte[] dna, PrintWriter pw) {
		for (int i = 0; i < dna.length; i += 50) {
			int sublen = (i + 50 < dna.length) ? 50 : dna.length - i;
			String seq = new String(dna, i, sublen);
			pw.println(seq);
		}
	}

	private void writeQuality(byte[] quality, PrintWriter pw) {
		StringBuffer buffer = new StringBuffer();

		for (int i = 0; i < quality.length; i++) {
			int qual = (int) quality[i];
			buffer.append(qual);

			if ((i % 25) < 24)
				buffer.append(' ');
			else
				buffer.append('\n');
		}

		if ((quality.length % 25) != 0)
			buffer.append('\n');

		pw.print(buffer.toString());
	}

	public void close() throws ArcturusDatabaseException {
		if (conn != null) {
			try {
				conn.close();
			} catch (SQLException e) {
				adb.handleSQLException(e, "Failed to close database connection", conn, this);
			}
			
			conn = null;
		}
	}

	protected void finalize() throws ArcturusDatabaseException {
		close();
	}

	public List<Integer> getContigIDsForProject(String project)
			throws SQLException {
		pstmtContigsForProject.setString(1, project);

		ResultSet rs = pstmtContigsForProject.executeQuery();

		Vector<Integer> ids = new Vector<Integer>();

		while (rs.next()) {
			int id = rs.getInt(1);
			ids.add(id);
		}

		rs.close();

		return ids;
	}

	public static void main(String[] args) {
		try {
			String instance = null;
			String organism = null;
			String project = null;
			boolean forAssembly = false;

			for (int i = 0; i < args.length; i++) {
				if (args[i].equalsIgnoreCase("-instance"))
					instance = args[++i];

				if (args[i].equalsIgnoreCase("-organism"))
					organism = args[++i];

				if (args[i].equalsIgnoreCase("-project"))
					project = args[++i];

				if (args[i].equalsIgnoreCase("-forassembly"))
					forAssembly = true;
			}

			if (instance == null || organism == null || project == null) {
				showUsage(System.err);
				System.exit(1);
			}

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			ContigCAFWriter ccw = new ContigCAFWriter(adb);

			File file = new File(project + ".caf");

			PrintWriter pw = new PrintWriter(new BufferedWriter(new FileWriter(
					file)));

			PrintWriter pwReads = null;

			if (forAssembly) {
				file = new File(project + ".reads.caf");
				pwReads = new PrintWriter(new BufferedWriter(new FileWriter(
						file)));
			}

			List<Integer> ids = ccw.getContigIDsForProject(project);

			for (int contigid : ids) {
				int nreads = ccw.getContigReadCount(contigid);

				if (nreads > 1 || pwReads == null)
					ccw.writeContigAsCAF(contigid, nreads, pw);
				else
					ccw.writeReadsForContig(contigid, pwReads);
			}

			pw.close();

			if (pwReads != null)
				pwReads.close();
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

		Runtime runtime = Runtime.getRuntime();

		long totalmem = runtime.totalMemory();
		long freemem = runtime.freeMemory();
		long usedmem = totalmem - freemem;

		System.err
				.println("Memory usage: " + (totalmem / 1024) + "kb total, "
						+ (freemem / 1024) + "kb free, " + (usedmem / 1024)
						+ "kb used");

		System.exit(0);
	}

	protected static void showUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-project\tName of project");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps
				.println("\t-forassembly\tGenerate a separate file of single-read contigs");
	}
}
