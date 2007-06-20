package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.util.zip.*;
import java.util.List;
import java.util.Vector;
import java.io.*;
import java.text.*;

public class ContigCAFWriter {
	public static final int OK = 0;
	public static final int CONTIG_NOT_FOUND = 1;
	public static final int NO_CONSENSUS = 2;
	public static final int READ_BASIC_DATA_NOT_FOUND = 3;
	public static final int READ_CLONE_DATA_NOT_FOUND = 4;
	public static final int NO_SEQUENCE_DATA = 5;

	private Connection conn;

	private PreparedStatement pstmtContigData;
	private PreparedStatement pstmtConsensus;
	private PreparedStatement pstmtMapping;
	private PreparedStatement pstmtSegment;
	private PreparedStatement pstmtReadBasicData;
	private PreparedStatement pstmtReadCloneData;
	private PreparedStatement pstmtSequence;
	private PreparedStatement pstmtSequenceVector;
	private PreparedStatement pstmtCloningVector;
	private PreparedStatement pstmtQualityClipping;
	private PreparedStatement pstmtReadTag;

	private PreparedStatement pstmtContigsForProject;

	private DateFormat dateformat = new SimpleDateFormat("yyyy-MM-dd");

	private DecimalFormat decimalformat = new DecimalFormat("00000000");

	private Inflater decompresser = new Inflater();

	public ContigCAFWriter(ArcturusDatabase adb) throws SQLException {
		conn = adb.getPooledConnection(this);

		prepareStatements();
	}

	private void prepareStatements() throws SQLException {
		String sql = "select gap4name,length,nreads from CONTIG where contig_id = ?";

		pstmtContigData = conn.prepareStatement(sql);

		sql = "select sequence,quality,length from CONSENSUS where contig_id = ?";

		pstmtConsensus = conn.prepareStatement(sql);

		sql = "select mapping_id,direction,MAPPING.seq_id,READINFO.read_id,readname"
				+ "  from MAPPING,SEQ2READ,READINFO"
				+ "  where contig_id = ? and MAPPING.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id"
				+ "  order by cstart asc";

		pstmtMapping = conn.prepareStatement(sql);

		sql = "select cstart,rstart,length from SEGMENT where mapping_id = ? order by rstart asc";

		pstmtSegment = conn.prepareStatement(sql);

		sql = "select readname,asped,strand,primer,chemistry,BASECALLER.name,STATUS.name"
				+ " from READINFO,BASECALLER,STATUS where read_id = ?"
				+ " and READINFO.basecaller = BASECALLER.basecaller_id and READINFO.status = STATUS.status_id";

		pstmtReadBasicData = conn.prepareStatement(sql);

		sql = "select TEMPLATE.name,LIGATION.name,LIGATION.silow,LIGATION.sihigh,CLONE.name"
				+ " from READINFO,TEMPLATE,LIGATION,CLONE"
				+ " where read_id = ? and READINFO.template_id = TEMPLATE.template_id"
				+ " and TEMPLATE.ligation_id = LIGATION.ligation_id and LIGATION.clone_id = CLONE.clone_id";

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

		sql = "select tagtype,pstart,pfinal,comment from READTAG where seq_id = ? and deprecated is null";

		pstmtReadTag = conn.prepareStatement(sql);

		sql = "select contig_id from"
				+ " CURRENTCONTIGS left join PROJECT using(project_id)"
				+ " where nreads > 1 and name=?";
		
		pstmtContigsForProject = conn.prepareStatement(sql);
	}

	public int writeContigAsCAF(int contigid, PrintWriter pw)
			throws SQLException, DataFormatException {
		pstmtContigData.setInt(1, contigid);

		ResultSet rs = pstmtContigData.executeQuery();

		if (!rs.next()) {
			rs.close();
			return CONTIG_NOT_FOUND;
		}

		String gap4name = rs.getString(1);
		int ctglen = rs.getInt(2);
		int nreads = rs.getInt(3);

		String contigname = "Contig" + decimalformat.format(contigid);

		pw.println("Sequence : " + contigname);
		pw.println("Is_contig");
		pw.println("Unpadded");

		int[] readids = new int[nreads];
		int[] seqids = new int[nreads];

		pstmtMapping.setInt(1, contigid);

		rs = pstmtMapping.executeQuery();

		int i = 0;

		while (rs.next()) {
			int mappingid = rs.getInt(1);
			String direction = rs.getString(2);
			int seqid = rs.getInt(3);
			int readid = rs.getInt(4);
			String readname = rs.getString(5);

			readids[i] = readid;
			seqids[i] = seqid;
			i++;

			boolean forward = direction.equalsIgnoreCase("Forward");

			pstmtSegment.setInt(1, mappingid);

			ResultSet rs2 = pstmtSegment.executeQuery();

			while (rs2.next()) {
				int cstart = rs2.getInt(1);
				int rstart = rs2.getInt(2);
				int seglen = rs2.getInt(3);

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

			rs2.close();
		}

		rs.close();

		pw.println();

		pstmtConsensus.setInt(1, contigid);

		rs = pstmtConsensus.executeQuery();

		if (!rs.next()) {
			rs.close();
			return NO_CONSENSUS;
		}

		byte[] dna = rs.getBytes(1);
		byte[] quality = rs.getBytes(2);
		int seqlen = rs.getInt(3);

		dna = decodeCompressedData(dna, seqlen);
		quality = decodeCompressedData(quality, seqlen);

		pw.println("DNA : " + contigname);

		writeDNA(dna, pw);

		pw.println();

		pw.println("BaseQuality : " + contigname);

		writeQuality(quality, pw);

		pw.println();

		for (i = 0; i < readids.length; i++) {
			int rc = writeRead(readids[i], seqids[i], pw);

			if (rc != OK)
				return rc;
		}

		return OK;
	}

	private int writeRead(int readid, int seqid, PrintWriter pw)
			throws SQLException, DataFormatException {
		pstmtReadBasicData.setInt(1, readid);

		ResultSet rs = pstmtReadBasicData.executeQuery();

		if (!rs.next()) {
			rs.close();
			return READ_BASIC_DATA_NOT_FOUND;
		}

		String readname = rs.getString(1);
		java.util.Date asped = rs.getDate(2);
		String strand = rs.getString(3);
		String primer = rs.getString(4);
		String chemistry = rs.getString(5);
		String basecaller = rs.getString(6);
		String status = rs.getString(7);

		rs.close();

		pstmtReadCloneData.setInt(1, readid);

		rs = pstmtReadCloneData.executeQuery();

		if (!rs.next()) {
			rs.close();
			return READ_CLONE_DATA_NOT_FOUND;
		}

		String template = rs.getString(1);
		String ligation = rs.getString(2);
		int silow = rs.getInt(3);
		int sihigh = rs.getInt(4);
		String clone = rs.getString(5);

		rs.close();

		pw.println("Sequence : " + readname);
		pw.println("Is_read");
		pw.println("Unpadded");

		pw.println("SCF_File " + readname + "SCF");

		pw.println("Template " + template);
		pw.println("Insert_size " + silow + " " + sihigh);
		pw.println("Ligation_no " + ligation);
		pw.println("Primer " + primer);
		pw.println("Strand " + strand);
		pw.println("Dye " + chemistry);
		pw.println("Clone " + clone);
		pw.println("Status " + status);
		pw.println("Asped " + dateformat.format(asped));
		pw.println("Base_caller " + basecaller);

		pstmtQualityClipping.setInt(1, seqid);

		rs = pstmtQualityClipping.executeQuery();

		while (rs.next()) {
			int qleft = rs.getInt(1);
			int qright = rs.getInt(2);
			pw.println("Clipping QUAL " + qleft + " " + qright);
		}

		rs.close();

		pstmtSequenceVector.setInt(1, seqid);

		rs = pstmtSequenceVector.executeQuery();

		while (rs.next()) {
			int svleft = rs.getInt(1);
			int svright = rs.getInt(2);
			String svname = rs.getString(3);
			pw.println("Seq_vec SVEC " + svleft + " " + svright + " \""
					+ svname + "\"");
		}

		rs.close();

		pstmtCloningVector.setInt(1, seqid);

		rs = pstmtCloningVector.executeQuery();

		while (rs.next()) {
			int cvleft = rs.getInt(1);
			int cvright = rs.getInt(2);
			String cvname = rs.getString(3);
			pw.println("Clone_vec CVEC " + cvleft + " " + cvright + " \""
					+ cvname + "\"");
		}

		rs.close();

		pstmtReadTag.setInt(1, seqid);

		rs = pstmtReadTag.executeQuery();

		while (rs.next()) {
			String tagtype = rs.getString(1);
			int tagstart = rs.getInt(2);
			int tagfinish = rs.getInt(3);
			String tagcomment = rs.getString(4);

			pw.print("TAG " + tagtype + " " + tagstart + " " + tagfinish);
			if (tagcomment != null)
				pw.print(" \"" + tagcomment + "\"");
			pw.println();
		}

		rs.close();

		pstmtSequence.setInt(1, seqid);

		rs = pstmtSequence.executeQuery();

		if (!rs.next()) {
			rs.close();
			return NO_SEQUENCE_DATA;
		}

		byte[] dna = rs.getBytes(1);
		byte[] quality = rs.getBytes(2);
		int seqlen = rs.getInt(3);

		pw.println("Align_to_SCF 1 " + seqlen + " 1 " + seqlen);

		pw.println();

		dna = decodeCompressedData(dna, seqlen);
		quality = decodeCompressedData(quality, seqlen);

		pw.println("DNA : " + readname);

		writeDNA(dna, pw);

		pw.println();

		pw.println("BaseQuality : " + readname);

		writeQuality(quality, pw);

		pw.println();

		return OK;
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

	public void close() throws SQLException {
		if (conn != null)
			conn.close();

		conn = null;
	}

	protected void finalize() {
		try {
			close();
		} catch (SQLException sqle) {
		}
	}
	
	public List<Integer> getContigIDsForProject(String project) throws SQLException {
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
			
			for (int i = 0; i < args.length; i++) {
				if (args[i].equalsIgnoreCase("-instance"))
					instance = args[++i];
				
				if (args[i].equalsIgnoreCase("-organism"))
					organism = args[++i];
				
				if (args[i].equalsIgnoreCase("-project"))
					project = args[++i];
			}
			
			if (instance == null || organism == null || project == null) {
				showUsage(System.err);
				System.exit(1);
			}
			
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			ContigCAFWriter ccw = new ContigCAFWriter(adb);
			
			File file = new File(project + ".caf");
			
			PrintWriter pw = new PrintWriter(new BufferedWriter(
					new FileWriter(file)));
			
			List<Integer> ids = ccw.getContigIDsForProject(project);

			for (int contigid : ids)
				ccw.writeContigAsCAF(contigid, pw);
			
			pw.close();
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

	}
	
	protected static void showUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-project\tName of project");
	}
}
