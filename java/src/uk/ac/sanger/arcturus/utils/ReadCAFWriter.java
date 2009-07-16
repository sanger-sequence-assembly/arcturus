package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.util.zip.*;
import java.util.Map;
import java.util.HashMap;
import java.io.*;
import java.text.*;

public class ReadCAFWriter {
	private Connection conn;

	private PreparedStatement pstmtReadBasicData;
	private PreparedStatement pstmtReadCloneData;
	private PreparedStatement pstmtSequence;
	private PreparedStatement pstmtSequenceVector;
	private PreparedStatement pstmtCloningVector;
	private PreparedStatement pstmtQualityClipping;
	private PreparedStatement pstmtReadTag;
	private PreparedStatement pstmtAlignToSCF;

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

	private Inflater decompresser = new Inflater();

	public ReadCAFWriter(ArcturusDatabase adb) throws SQLException {
		conn = adb.getPooledConnection(this);

		prepareStatements();
		createDictionaries();
	}

	private void prepareStatements() throws SQLException {
		String sql = "select READINFO.read_id,seq_id,asped,strand,primer,chemistry,basecaller,status,version"
				+ " from READINFO left join SEQ2READ using(read_id) where readname = ? order by version asc";

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

	public void writeRead(String readname, PrintWriter pw) throws SQLException,
			DataFormatException {
		pstmtReadBasicData.setString(1, readname);

		ResultSet rsRead = pstmtReadBasicData.executeQuery();

		while (rsRead.next()) {
			int readid = rsRead.getInt(1);
			int seqid = rsRead.getInt(2);
			java.util.Date asped = rsRead.getDate(3);
			String strand = rsRead.getString(4);
			String primer = rsRead.getString(5);
			String chemistry = rsRead.getString(6);

			int basecaller_id = rsRead.getInt(7);

			String basecaller = rsRead.wasNull() ? null : dictBasecaller
					.get(basecaller_id);

			int status_id = rsRead.getInt(8);

			String status = rsRead.wasNull() ? null : dictReadStatus
					.get(status_id);

			int version = rsRead.getInt(9);

			pstmtReadCloneData.setInt(1, readid);

			ResultSet rs = pstmtReadCloneData.executeQuery();

			String template = null;
			String ligation = null;
			int silow = -1;
			int sihigh = -1;
			String clone = null;

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

			pw.println("Sequence : " + readname);
			pw.println("Version " + version);
			pw.println("Is_read");
			pw.println("Unpadded");

			pw.println("SCF_File " + readname + "SCF");

			pw.println("Template " + template);

			if (silow > 0 && sihigh > 0)
				pw.println("Insert_size " + silow + " " + sihigh);

			if (ligation != null)
				pw.println("Ligation_no " + ligation);

			if (primer != null)
				pw.println("Primer " + primer);

			if (strand != null)
				pw.println("Strand " + strand);

			if (chemistry != null)
				pw.println("Dye " + chemistry);

			if (clone != null)
				pw.println("Clone " + clone);

			if (status != null)
				pw.println("ProcessStatus " + status);

			if (asped != null)
				pw.println("Asped " + dateformat.format(asped));

			if (basecaller != null)
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

				pw.print("Tag " + tagtype + " " + tagstart + " " + tagfinish);
				if (tagcomment != null)
					pw.print(" \"" + tagcomment + "\"");
				pw.println();
			}

			rs.close();

			pstmtAlignToSCF.setInt(1, seqid);

			rs = pstmtAlignToSCF.executeQuery();

			boolean hasAlignToSCF = false;

			while (rs.next()) {
				hasAlignToSCF = true;

				int startInSequence = rs.getInt(1);
				int startInSCF = rs.getInt(2);

				int length = rs.getInt(3);

				int endInSequence = startInSequence + length - 1;
				int endInSCF = startInSCF + length - 1;

				pw.println("Align_to_SCF " + startInSequence + " "
						+ endInSequence + " " + startInSCF + " " + endInSCF);
			}

			rs.close();

			pstmtSequence.setInt(1, seqid);

			rs = pstmtSequence.executeQuery();

			if (!rs.next()) {
				rs.close();
				pw.println("### Could not find sequence data for version " + version + " ###");
			}

			byte[] dna = rs.getBytes(1);
			byte[] quality = rs.getBytes(2);
			int seqlen = rs.getInt(3);

			if (!hasAlignToSCF)
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
		}
		
		rsRead.close();
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
		for (int i = 0; i < quality.length; i++) {
			int qual = (int) quality[i];
			pw.print(qual);

			if ((i % 25) < 24)
				pw.print(' ');
			else
				pw.println();
		}

		if ((quality.length % 25) != 0)
			pw.println();
	}

	public static void main(String[] args) {
		try {
			String instance = null;
			String organism = null;

			for (int i = 0; i < args.length; i++) {
				if (args[i].equalsIgnoreCase("-instance"))
					instance = args[++i];

				if (args[i].equalsIgnoreCase("-organism"))
					organism = args[++i];
			}

			if (instance == null || organism == null) {
				showUsage(System.err);
				System.exit(1);
			}

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			PrintWriter pw = new PrintWriter(System.out, true);

			ReadCAFWriter writer = new ReadCAFWriter(adb);

			BufferedReader reader = new BufferedReader(new InputStreamReader(
					System.in));

			while (true) {
				System.out.print(">");

				String line = reader.readLine();

				if (line == null)
					break;

				String[] words = line.split("\\s+");

				if (words.length == 0)
					continue;

				String readname = words[0];

				writer.writeRead(readname, pw);
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

		System.exit(0);
	}

	protected static void showUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
	}
}
