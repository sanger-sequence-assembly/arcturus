// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.consensusreadimporter;

import java.io.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.*;
import java.util.List;
import java.util.Vector;
import java.util.zip.Deflater;

import com.mysql.jdbc.MysqlErrorNumbers;

import javax.swing.JFileChooser;
import javax.swing.JOptionPane;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.OrganismChooserPanel;

public class ConsensusReadImporter {
	private static final String FASTA_PREFIX = ">";
	
	private static final String DNA_PATTERN = "^[ACGTNXacgtnx]+$";
	
	private static final int DEFAULT_QUALITY = 2;
	
	private static final String DEFAULT_TAGTYPE = "CONS";
	
	private static final String DEFAULT_TAG_COMMENT = "Consensus read";
	
	private PreparedStatement pstmtGetPassStatus = null;
	private static final String GET_PASS_STATUS = "select status_id from STATUS where name = ?";
	
	private PreparedStatement pstmtInsertReadInfo = null;
	private static final String INSERT_READINFO = "insert into READINFO(readname,status) values (?,?)";
	
	private PreparedStatement pstmtGetTemplateID = null;
	private static final String GET_TEMPLATE_ID = "select template_id from TEMPLATE where name = ?";
	
	private PreparedStatement pstmtInsertTemplate = null;
	private static final String INSERT_TEMPLATE = "insert into TEMPLATE(name) values (?)";
	
	private PreparedStatement pstmtUpdateReadInfo = null;
	private static final String UPDATE_READINFO = "update READINFO set template_id = ? where read_id = ?" +
		" and template_id is null";
	
	private PreparedStatement pstmtInsertSequence = null;
	private static final String INSERT_SEQUENCE = "insert into SEQUENCE(seqlen,seq_hash,qual_hash,sequence,quality)" +
		" values (?,?,?,?,?)";
	
	private PreparedStatement pstmtInsertSeq2Read = null;
	private static final String INSERT_SEQ2READ = "insert into SEQ2READ(read_id, seq_id,version)" +
		" values (?,?,1)";
	
	private PreparedStatement pstmtInsertReadTag = null;
	private static final String INSERT_READTAG = "insert into READTAG(seq_id,tagtype,pstart,pfinal,comment)" +
		" values (?,?,?,?,?)";
	
	private PreparedStatement pstmtInsertQualityClip = null;
	private static final String INSERT_QUALITYCLIP = "insert into QUALITYCLIP(seq_id,qleft,qright)" +
		" values (?,?,?)";
	
	private ConsensusReadImporterListener listener = null;
	private Connection conn = null;
	
	private int qualityValue = DEFAULT_QUALITY;
	
	private int passValue = 0;
	
	private MessageDigest digester;
	private Deflater compresser = new Deflater();

	public ConsensusReadImporter() {
		try {
			digester = MessageDigest.getInstance("MD5");
		} catch (NoSuchAlgorithmException e) {
			Arcturus.logWarning(e);
		}
	}
	
	public void importReads(ArcturusDatabase adb, File file, int quality,
			ConsensusReadImporterListener listener) throws IOException, SQLException {
		this.listener = listener;
		this.qualityValue = quality;

		conn = adb.getPooledConnection(this);
		
		boolean oldAutoCommit = conn.getAutoCommit();
		int oldTransactionIsolationLevel = conn.getTransactionIsolation();
		
		prepareStatements();
		
		getPassValue();
		
		conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);
		conn.setAutoCommit(false);

		FileReader fr = new FileReader(file);
		BufferedReader br = new BufferedReader(fr);
		
		processFASTAFile(br);
		
		conn.setAutoCommit(oldAutoCommit);
		conn.setTransactionIsolation(oldTransactionIsolationLevel);
		
		closeStatements();
		
		br.close();
		fr.close();
		
		conn.close();
		conn = null;
		
		this.listener = null;
		this.qualityValue = DEFAULT_QUALITY;
	}
	
	private void prepareStatements() throws SQLException {
		pstmtGetPassStatus = conn.prepareStatement(GET_PASS_STATUS);
		
		pstmtInsertReadInfo =  conn.prepareStatement(INSERT_READINFO, Statement.RETURN_GENERATED_KEYS);
		
		pstmtGetTemplateID = conn.prepareStatement(GET_TEMPLATE_ID);
		
		pstmtInsertTemplate = conn.prepareStatement(INSERT_TEMPLATE, Statement.RETURN_GENERATED_KEYS);
		
		pstmtUpdateReadInfo = conn.prepareStatement(UPDATE_READINFO);
		
		pstmtInsertSequence = conn.prepareStatement(INSERT_SEQUENCE, Statement.RETURN_GENERATED_KEYS);
		
		pstmtInsertSeq2Read = conn.prepareStatement(INSERT_SEQ2READ);
		
		pstmtInsertReadTag = conn.prepareStatement(INSERT_READTAG);
		
		pstmtInsertQualityClip = conn.prepareStatement(INSERT_QUALITYCLIP);
	}
	
	private void closeStatements() throws SQLException {
		pstmtGetPassStatus = null;		
		pstmtInsertReadInfo =  null;
		pstmtGetTemplateID = null;
		pstmtInsertTemplate = null;
		pstmtUpdateReadInfo = null;
		pstmtInsertSequence = null;
		pstmtInsertSeq2Read = null;
		pstmtInsertReadTag = null;
		pstmtInsertQualityClip = null;
	}
	
	private void getPassValue() throws SQLException {
		pstmtGetPassStatus.setString(1, "PASS");
		ResultSet rs = pstmtGetPassStatus.executeQuery();
		
		passValue = rs.next() ? rs.getInt(1) : 0;
			
		rs.close();
		pstmtGetPassStatus.close();
	}
	
	private void processFASTAFile(BufferedReader br) throws IOException, SQLException {
		StringBuilder sb = null;
		
		String seqname = null;
		
		String line;
		
		List<String> readsLoaded = new Vector<String>();
		
		while ((line = br.readLine()) != null) {
			if (line.startsWith(FASTA_PREFIX)) {
				if (seqname != null) {
					boolean ok = processSequence(seqname, sb.toString());
					if (ok)
						readsLoaded.add(seqname);
				}
				
				line = line.substring(1);
				
				String[] words = line.split("\\s+");
				
				seqname = words[0];
				
				sb = new StringBuilder();
			} else if (line.matches(DNA_PATTERN)){
				sb.append(line);
			}
		}
		
		if (seqname != null) {
			boolean ok = processSequence(seqname, sb.toString());
			if (ok)
				readsLoaded.add(seqname);
		}
		
		if (!readsLoaded.isEmpty()) {
			notify("\n\nThe following consensus reads were successfully stored:\n");
			
			for (String readname : readsLoaded)
				notify(readname);
			
			notify("\n");
		}
	}
	
	private void notify(String message) {
		if (listener != null)
			listener.report(message);
	}

	private boolean processSequence(String seqname, String dna) throws SQLException {
		notify("\nStoring consensus read \"" + seqname + "\" (" + dna.length() + " bp)");
		
		try {
			int read_id;
			
			try {
				read_id = insertReadInfo(seqname);
			}
			catch (SQLException e) {
				if (e.getErrorCode() == MysqlErrorNumbers.ER_DUP_ENTRY) {
					notify("  -- A read named " + seqname +" already exists in the database");
					conn.rollback();
					return false;
				} else
					throw e;
			}
			
			notify("  -- Read ID is " + read_id);
			
			int template_id;
			
			String[] words = seqname.split("\\.");
			
			String template_name = words[0];
			
			notify("  -- Looking up template "+ template_name);
			
			pstmtGetTemplateID.setString(1, template_name);
			
			ResultSet rs = pstmtGetTemplateID.executeQuery();
			
			template_id = rs.next() ? rs.getInt(1) : -1;
			
			rs.close();
			
			if (template_id < 0) {
				notify("  -- Creating new template " + template_name);
				template_id = insertTemplate(template_name);
			}
			
			notify("  -- Template ID is " + template_id);
			
			setTemplateForRead(read_id, template_id);
			
			int seq_id = insertSequence(dna);
			
			notify("  -- Sequence ID is " + seq_id);
			
			insertSeq2Read(read_id, seq_id);
			
			insertReadTag(seq_id, DEFAULT_TAGTYPE, 1, dna.length(), DEFAULT_TAG_COMMENT);
			
			insertQualityClip(seq_id, 1, dna.length());
			
			conn.commit();
			
			notify("Consensus read " + seqname + " successfully stored.");
			
			return true;
		}
		catch (SQLException sqle) {
			Arcturus.logWarning(sqle);
			conn.rollback();
			notify("***** The sequence was NOT stored because a database exception occurred : " + 
					sqle.getMessage() + " *****");
			return false;
		}
	}
	
	private int insertReadInfo(String readname) throws SQLException {
		pstmtInsertReadInfo.setString(1, readname);
		pstmtInsertReadInfo.setInt(2, passValue);
		
		pstmtInsertReadInfo.executeUpdate();
		
		ResultSet rs = pstmtInsertReadInfo.getGeneratedKeys();
		
		int read_id = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		return read_id;
	}
	
	private int insertTemplate(String templateName) throws SQLException {
		pstmtInsertTemplate.setString(1, templateName);
		
		pstmtInsertTemplate.executeUpdate();
		
		ResultSet rs = pstmtInsertTemplate.getGeneratedKeys();
		
		int template_id = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		return template_id;
	}
	
	private void setTemplateForRead(int read_id, int template_id) throws SQLException {
		pstmtUpdateReadInfo.setInt(1, template_id);
		pstmtUpdateReadInfo.setInt(2, read_id);

		pstmtUpdateReadInfo.executeUpdate();
	}
	
	private int insertSequence(String dna) throws SQLException {
		int seqlen = dna.length();
		
		byte[] sequence = null;
		
		try {
			sequence = dna.getBytes("US-ASCII");
		} catch (UnsupportedEncodingException e) {
			Arcturus.logWarning(e);
		}
		
		byte[] quality = createQualityArray(seqlen);
		
		byte[] seq_hash = calculateMD5Hash(sequence);
		
		byte[] qual_hash = calculateMD5Hash(quality);
		
		sequence = compress(sequence);
		
		quality = compress(quality);
		
		pstmtInsertSequence.setInt(1, seqlen);
		pstmtInsertSequence.setBytes(2, seq_hash);
		pstmtInsertSequence.setBytes(3, qual_hash);
		pstmtInsertSequence.setBytes(4, sequence);
		pstmtInsertSequence.setBytes(5, quality);
		
		pstmtInsertSequence.executeUpdate();
		
		ResultSet rs = pstmtInsertSequence.getGeneratedKeys();
		
		int seq_id = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		return seq_id;
	}
	
	private byte[] createQualityArray(int seqlen) {
		byte[] quality = new byte[seqlen];
		
		byte q = (byte)qualityValue;
		
		for (int i = 0; i < quality.length; i++)
			quality[i] = q;
		
		return quality;
	}
	
	private byte[] calculateMD5Hash(byte[] data) {
		if (digester == null)
			return null;
		
		digester.reset();
		
		return digester.digest(data);
	}
	
	private byte[] compress(byte[] data) {
		byte[] buffer = new byte[12 + (5 * data.length) / 4];

		compresser.reset();
		compresser.setInput(data);
		compresser.finish();
		
		int compressedLength = compresser.deflate(buffer);
		
		byte[] compressedData = new byte[compressedLength];
		
		for (int i = 0; i < compressedLength; i++)
			compressedData[i] = buffer[i];

		return compressedData;
	}
	
	private void insertSeq2Read(int read_id, int seq_id) throws SQLException {
		pstmtInsertSeq2Read.setInt(1, read_id);
		pstmtInsertSeq2Read.setInt(2, seq_id);
		
		pstmtInsertSeq2Read.executeUpdate();
	}
	
	private void insertReadTag(int seq_id, String tagtype, int pstart, int pfinal, String comment)
		throws SQLException {
		pstmtInsertReadTag.setInt(1, seq_id);
		pstmtInsertReadTag.setString(2, tagtype);
		pstmtInsertReadTag.setInt(3, pstart);
		pstmtInsertReadTag.setInt(4, pfinal);
		pstmtInsertReadTag.setString(5, comment);
		
		pstmtInsertReadTag.executeUpdate();
	}
	
	private void insertQualityClip(int seq_id, int qleft, int qright) throws SQLException {
		pstmtInsertQualityClip.setInt(1, seq_id);
		pstmtInsertQualityClip.setInt(2, qleft);
		pstmtInsertQualityClip.setInt(3, qright);
		
		pstmtInsertQualityClip.executeUpdate();
	}

	public static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-filename\tName of FASTA file to import");
	}

	public static void main(String args[]) {
		String instance = null;
		String organism = null;
		String filename = null;
		int quality = 2;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
			
			if (args[i].equalsIgnoreCase("-filename"))
				filename = args[++i];
			
			if (args[i].equalsIgnoreCase("-quality"))
				quality = Integer.parseInt(args[++i]);
		}
		
		File file = null;
		
		if (filename != null) {
			file = new File(filename);
		} else {
			JFileChooser chooser = new JFileChooser();
		
			File cwd = new File(System.getProperty("user.home"));
			chooser.setCurrentDirectory(cwd);

			int returnVal = chooser.showOpenDialog(null);

			if (returnVal == JFileChooser.APPROVE_OPTION)
				file = chooser.getSelectedFile();
		}

		if (instance == null || organism == null) {
			OrganismChooserPanel orgpanel = new OrganismChooserPanel();

			int result = orgpanel.showDialog(null);

			if (result == JOptionPane.OK_OPTION) {
				instance = orgpanel.getInstance();
				organism = orgpanel.getOrganism();
			}
		}

		if (instance == null || instance.length() == 0 || organism == null
				|| organism.length() == 0 || file == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			ConsensusReadImporter importer = new ConsensusReadImporter();
			
			ConsensusReadImporterListener listener = new ConsensusReadImporterListener() {
				public void report(String message) {
					System.out.println(message);
				}
			};
			
			importer.importReads(adb, file, quality, listener);
			
			System.exit(0);
		} catch (Exception e) {
			Arcturus.logWarning(e);
			System.exit(1);
		}
	}
}
