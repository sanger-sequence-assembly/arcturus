package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.util.zip.*;
import java.io.*;
import java.sql.*;

import java.util.logging.*;

import javax.naming.Context;

public class CalculateQualityClipping {
	private final int DEFAULT_THRESH = 15;

	public final int MODE_UPDATE_NULLS = 1;
	public final int MODE_UPDATE_ALL = 2;
	public final int MODE_CALCULATE_ALL = 3;

	private String instance = null;
	private String organism = null;

	private ArcturusDatabase adb = null;

	private boolean debug = false;

	private long lasttime;
	private Runtime runtime = Runtime.getRuntime();

	private Inflater decompresser = new Inflater();

	private PreparedStatement pstmtInsert;
	private PreparedStatement pstmtUpdate;

	public void execute(String[] args) {
		int thresh = DEFAULT_THRESH;

		Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

		lasttime = System.currentTimeMillis();

		System.err.println("CalculateQualityClipping");
		System.err.println("========================");
		System.err.println();

		Properties props = new Properties();

		Properties env = System.getProperties();

		props.put(Context.INITIAL_CONTEXT_FACTORY, env
				.get(Context.INITIAL_CONTEXT_FACTORY));

		props.put(Context.PROVIDER_URL, env.get(Context.PROVIDER_URL));

		int mode = MODE_UPDATE_NULLS;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-debug"))
				debug = true;

			if (args[i].equalsIgnoreCase("-updateall"))
				mode = MODE_UPDATE_ALL;

			if (args[i].equalsIgnoreCase("-processall"))
				mode = MODE_CALCULATE_ALL;

			if (args[i].equalsIgnoreCase("-thresh"))
				thresh = Integer.parseInt(args[++i]);
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = new ArcturusInstance(props, instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			adb = ai.findArcturusDatabase(organism);

			Connection conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			String insertQuery = "insert into QUALITYCLIP(seq_id,qleft,qright) VALUES(?,?,?)";

			pstmtInsert = conn.prepareStatement(insertQuery);

			String updateQuery = "update QUALITYCLIP set qleft=?, qright=? where seq_id=?";

			pstmtUpdate = conn.prepareStatement(updateQuery);

			calculateQualityClipping(conn, thresh, mode);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-thresh\tThreshold for clipping [DEFAULT: "
				+ DEFAULT_THRESH + "]");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-updateall", "-calculateall" };

		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);

		ps.println();
	}

	public void report() {
		long timenow = System.currentTimeMillis();

		System.out.println("******************** REPORT ********************");
		System.out.println("Time: " + (timenow - lasttime));

		System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()
				/ 1024 + "/" + runtime.totalMemory() / 1024);
		System.out.println("************************************************");
		System.out.println();
	}

	private void calculateQualityClipping(Connection conn, int thresh, int mode)
			throws SQLException {
		switch (mode) {
			case MODE_UPDATE_NULLS:
				updateNulls(conn, thresh);
				break;

			case MODE_UPDATE_ALL:
				calculateAndUpdateAll(conn, thresh, true);
				break;

			case MODE_CALCULATE_ALL:
				calculateAndUpdateAll(conn, thresh, false);
				break;

			default:
				System.err.println("Unknown mode: " + mode);
				System.exit(1);
		}
	}

	private void updateNulls(Connection conn, int thresh) throws SQLException {
		String query = "select SEQUENCE.seq_id,seqlen,quality"
				+ " from SEQUENCE left join QUALITYCLIP using(seq_id)"
				+ " where qleft is null";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int seqlen = rs.getInt(2);
			byte[] quality = decodeCompressedData(rs.getBytes(3), seqlen);

			if (debug)
				System.err.println("Clipping for sequence " + seq_id);

			int[] qclip = calculateClipping(quality, thresh);

			if (debug)
				System.err
						.println("\n---------------------------------------------------------------\n");

			boolean success = insertClipping(seq_id, qclip[0], qclip[1]);

			if (success)
				System.err.println("Added quality clipping for seq_id = "
						+ seq_id + " : " + qclip[0] + " " + qclip[1]);
		}
	}

	private int[] calculateClipping(byte[] quality, int thresh) {
		int[] q = new int[quality.length];

		int N = q.length;

		for (int i = 0; i < N; i++)
			q[i] = (int) quality[i] - thresh;

		int Left = 0;

		int[] cleft = new int[N];
		cleft[0] = q[0] > 0 ? q[0] : 0;

		int[] l = new int[N];
		l[0] = Left;

		for (int i = 1; i < N; i++) {
			cleft[i] = cleft[i - 1] + q[i];

			if (cleft[i] <= 0) {
				cleft[i] = 0;
				Left = i;
			}

			l[i] = Left;
		}

		int Right = N - 1;

		int[] cright = new int[N];
		cright[N - 1] = q[N - 1] > 0 ? q[N - 1] : 0;

		int[] r = new int[N];
		r[N - 1] = Right;

		for (int i = N - 2; i >= 0; i--) {
			cright[i] = cright[i + 1] + q[i];

			if (cright[i] <= 0) {
				cright[i] = 0;
				Right = i;
			}

			r[i] = Right;
		}

		int best = 0;
		int coord = 0;

		for (int i = 0; i < N; i++) {
			int s = cright[i] + cleft[i];

			if (best < s) {
				best = s;
				coord = i;
			}
		}

		int[] qclip = new int[2];

		qclip[0] = l[coord] + 1;
		qclip[1] = r[coord] + 1;

		return qclip;
	}

	private boolean insertClipping(int seq_id, int qleft, int qright)
			throws SQLException {
		pstmtInsert.setInt(1, seq_id);
		pstmtInsert.setInt(2, qleft);
		pstmtInsert.setInt(3, qright);

		return pstmtInsert.executeUpdate() == 1;
	}

	private boolean updateClipping(int seq_id, int qleft, int qright)
			throws SQLException {
		pstmtUpdate.setInt(3, seq_id);
		pstmtUpdate.setInt(1, qleft);
		pstmtUpdate.setInt(2, qright);

		return pstmtUpdate.executeUpdate() == 1;
	}

	private byte[] decodeCompressedData(byte[] compressed, int length) {
		byte[] buffer = new byte[length];

		try {
			decompresser.setInput(compressed, 0, compressed.length);
			decompresser.inflate(buffer, 0, buffer.length);
			decompresser.reset();
		} catch (DataFormatException dfe) {
			buffer = null;
			dfe.printStackTrace();
		}

		return buffer;
	}

	private void calculateAndUpdateAll(Connection conn, int thresh,
			boolean update) throws SQLException {
		int nDone = 0;
		int nMismatch = 0;
		
		String query = "select seq_id from SEQUENCE";

		Statement stmt = conn.createStatement();

		ResultSet rs_seqid = stmt.executeQuery(query);

		query = "select seqlen,quality,qleft,qright"
				+ " from SEQUENCE left join QUALITYCLIP using(seq_id) where SEQUENCE.seq_id=?";

		PreparedStatement pstmt = conn.prepareStatement(query);

		while (rs_seqid.next()) {
			int seq_id = rs_seqid.getInt(1);
			
			pstmt.setInt(1, seq_id);
			ResultSet rs = pstmt.executeQuery();
			
			rs.next();
			
			int seqlen = rs.getInt(1);
			byte[] quality = decodeCompressedData(rs.getBytes(2), seqlen);
			int oldqleft = rs.getInt(3);
			if (rs.wasNull())
				oldqleft = -1;
			int oldqright = rs.getInt(4);
			if (rs.wasNull())
				oldqright = -1;

			int[] qclip = calculateClipping(quality, thresh);
			
			nDone++;

			if (oldqleft != qclip[0] || oldqright != qclip[1]) {
				System.out.println(seq_id + " " + oldqleft + " " + qclip[0] + " "
						+ oldqright + " " + qclip[1]);
				nMismatch++;
			}
			
			if (debug && (nDone %100) == 0)
				System.err.println("Done " + nDone + ", " + nMismatch + " mismatches");

			if (update) {
				boolean success = updateClipping(seq_id, qclip[0], qclip[1]);

				if (success)
					System.err.println("Updated quality clipping for seq_id = "
							+ seq_id + " : " + qclip[0] + " " + qclip[1]);
			}
		}
		
		stmt.close();
		pstmt.close();

		System.out.println("Processed " + nDone + " sequences, found " + nMismatch + " mismatches");
	} 

	public static void main(String args[]) {
		CalculateQualityClipping cqc = new CalculateQualityClipping();
		cqc.execute(args);
	}
}
