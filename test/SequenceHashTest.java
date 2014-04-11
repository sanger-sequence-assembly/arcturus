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

import java.sql.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.zip.DataFormatException;
import java.util.zip.Inflater;

public class SequenceHashTest {
	private MessageDigest digester;
	private Inflater inflater;
	private Connection conn;

	public static void main(String[] args) {
		String url = null;
		String username = null;
		String password = null;
		String seqs = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-url"))
				url = args[++i];
			else if (args[i].equalsIgnoreCase("-username"))
				username = args[++i];
			else if (args[i].equalsIgnoreCase("-password"))
				password = args[++i];
			else if (args[i].equalsIgnoreCase("-seqids"))
				seqs = args[++i];
		}

		if (url == null || username == null || password == null || seqs == null) {
			System.err
					.println("You must supply a database URL, username, password and a list of sequence IDs");
			System.exit(1);
		}

		try {
			Class.forName("com.mysql.jdbc.Driver");

			Connection conn = DriverManager.getConnection(url, username,
					password);

			SequenceHashTest tester = new SequenceHashTest(conn);

			int[] seqids = parseIntegers(seqs);

			tester.check(seqids);

			conn.close();

			System.exit(0);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(2);
		}
	}

	private static int[] parseIntegers(String seqs) {
		String[] words = seqs.split(",");

		int[] seqids = new int[words.length];

		for (int i = 0; i < words.length; i++)
			seqids[i] = Integer.parseInt(words[i]);

		return seqids;
	}

	public SequenceHashTest(Connection conn) throws NoSuchAlgorithmException {
		this.conn = conn;
		digester = MessageDigest.getInstance("MD5");
		inflater = new Inflater();
	}

	public void check(int[] seqids) throws SQLException, DataFormatException {
		String query = "select R.readname, SR.version from SEQ2READ SR left join READINFO R using(read_id) where seq_id = ?";
		
		PreparedStatement stmtReadNameAndVersion = conn.prepareStatement(query);
		
		query = "select seqlen,seq_hash,qual_hash,sequence,quality from SEQUENCE where seq_id = ?";

		PreparedStatement stmtSequenceData = conn.prepareStatement(query);

		for (int i = 0; i < seqids.length; i++) {
			int seq_id = seqids[i];
			
			stmtReadNameAndVersion.setInt(1, seq_id);
			
			ResultSet rs = stmtReadNameAndVersion.executeQuery();
			
			String readname = null;
			int version = -1;
			
			if (rs.next()) {
				readname = rs.getString(1);
				version = rs.getInt(2);
			}
			
			rs.close();
			
			stmtSequenceData.setInt(1, seq_id);

			rs = stmtSequenceData.executeQuery();

			while (rs.next()) {
				int seqlen = rs.getInt(1);
				byte[] seqHash = rs.getBytes(2);
				byte[] qualHash = rs.getBytes(3);
				byte[] sequence = rs.getBytes(4);
				byte[] quality = rs.getBytes(5);
				
				System.out.println("##### Sequence " + seq_id);
				System.out.println("##### Read     " + readname);
				System.out.println("##### Version  " + version);
				System.out.println("##### Length   " + seqlen);

				sequence = decodeCompressedData(sequence, seqlen);
				quality = decodeCompressedData(quality, seqlen);

				byte[] mySeqHash = calculateMD5Hash(sequence);
				byte[] myQualHash = calculateMD5Hash(quality);
				
				System.out.println();
				showHash("Sequence hash in database ", seqHash);
				showHash("Sequence hash recalculated", mySeqHash);
				
				System.out.println();
				showHash("Quality hash in database ", qualHash);
				showHash("Quality hash recalculated", myQualHash);
				
				System.out.println();
			}

			rs.close();

		}
		
		stmtReadNameAndVersion.close();
		stmtSequenceData.close();
	}
	
	private static final char[] hexChars = {
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
	};

	private void showHash(String message, byte[] hash) {
		System.out.println(message);
		
		for (int i = 0; i < hash.length; i++) {
			if (i > 0)
				System.out.print(' ');
			
			int value = (int)hash[i];
			
			if (value < 0)
				value += 256;
			
			int hiByte = value / 16;
			int loByte = value % 16;
			
			System.out.print(hexChars[hiByte]);
			System.out.print(hexChars[loByte]);
		}
		
		System.out.println();
	}

	private byte[] calculateMD5Hash(byte[] data) {
		if (digester == null)
			return null;

		digester.reset();

		return digester.digest(data);
	}

	private byte[] decodeCompressedData(byte[] compressed, int length)
			throws DataFormatException {
		byte[] buffer = new byte[length];

		inflater.setInput(compressed, 0, compressed.length);
		inflater.inflate(buffer, 0, buffer.length);
		inflater.reset();

		return buffer;
	}

	private boolean compareByteArrays(byte[] array1, byte[] array2) {
		if (array1 == null || array2 == null || array1.length != array2.length)
			return false;

		for (int i = 0; i < array1.length; i++)
			if (array1[i] != array2[i])
				return false;

		return true;
	}
	
	
}
