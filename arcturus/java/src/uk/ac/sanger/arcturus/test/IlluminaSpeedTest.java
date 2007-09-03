package uk.ac.sanger.arcturus.test;

import javax.swing.*;
import java.sql.*;
import java.awt.*;
import java.awt.event.*;
import java.util.zip.Inflater;
import java.util.zip.DataFormatException;

public class IlluminaSpeedTest {
	private static final String HOST = "mcs1a";
	private static final int PORT = 15001;
	private static final String DATABASE = "SUIS";
	private static final String USERNAME = "arcturus";
	private static final String PASSWORD = "***REMOVED***";

	private static final int DEFAULT_HASHSIZE = 10;

	private static final int BASE_A = 65;
	private static final int BASE_C = 67;
	private static final int BASE_G = 71;
	private static final int BASE_T = 84;

	private Connection conn;

	private PreparedStatement pstmtFetchAll;

	private int rowcount = 0;

	private Inflater decompresser = new Inflater();

	private byte[] refseq = null;

	private int hashsize = DEFAULT_HASHSIZE;
	private int hashmask = 0;

	private HashEntry[] lookup;

	private JProgressBar pbar = new JProgressBar();

	private JLabel lblHits = new JLabel("-- HITS --");
	
	private JButton btnRunQuery = new JButton("Run");

	public IlluminaSpeedTest(int hashsize) {
		this.hashsize = hashsize;
	}
	
	public void run() {
		makeConnection();
		makeHashTable();
		createUI();
	}

	class HashEntry {
		private int offset = 0;
		private HashEntry next = null;

		public HashEntry(int offset, HashEntry next) {
			this.offset = offset;
			this.next = next;
		}

		public int getOffset() {
			return offset;
		}

		public HashEntry getNext() {
			return next;
		}
	}

	private void makeHashTable() {
		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
		}

		int lookupsize = 1 << (2 * hashsize);

		System.err.println("Lookup table size is " + lookupsize);

		lookup = new HashEntry[lookupsize];

		int start_pos = 0;
		int end_pos = 0;
		int bases_in_hash = 0;
		int hash = 0;
		int seqlen = refseq.length;

		for (start_pos = 0; start_pos < seqlen - hashsize + 1; start_pos++) {
			byte c = refseq[start_pos];

			if (isValid(c)) {
				while (end_pos < seqlen && bases_in_hash < hashsize) {
					byte e = refseq[end_pos];

					if (isValid(e)) {
						hash = updateHash(hash, e);
						bases_in_hash++;
					}

					end_pos++;
				}

				if (bases_in_hash == hashsize)
					processHashMatch(start_pos, hash);

				bases_in_hash--;
			}

			if (bases_in_hash < 0)
				bases_in_hash = 0;

			if (end_pos < start_pos) {
				end_pos = start_pos;
				bases_in_hash = 0;
			}
		}

		int occupied = 0;

		for (int i = 0; i < lookupsize; i++)
			if (lookup[i] != null)
				occupied++;

		System.err.println("Lookup table has " + occupied
				+ " occupied entries and " + (lookupsize - occupied)
				+ " free entries");
	}

	private int updateHash(int hash, byte c) {
		int value = hashCode(c);

		hash <<= 2;

		if (value > 0)
			hash |= value;

		return hash & hashmask;
	}

	public static int hashCode(byte c) {
		switch (c) {
			case BASE_A:
				return 0;

			case BASE_C:
				return 1;

			case BASE_G:
				return 2;

			case BASE_T:
				return 3;

			default:
				return 0;
		}
	}

	private void processHashMatch(int offset, int hash) {
		HashEntry entry = new HashEntry(offset, lookup[hash]);

		lookup[hash] = entry;
	}

	public static boolean isValid(byte c) {
		return c == BASE_A || c == BASE_C || c == BASE_G || c == BASE_T;
	}

	private void makeConnection() {
		String url = "jdbc:mysql://" + HOST + ":" + PORT + "/" + DATABASE;
		String driver = "com.mysql.jdbc.Driver";

		try {
			Class.forName(driver);

			conn = DriverManager.getConnection(url, USERNAME, PASSWORD);

			String sql = "select id,name,sequence from SOLEXA";

			pstmtFetchAll = conn.prepareStatement(sql,
					ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY);

			pstmtFetchAll.setFetchSize(Integer.MIN_VALUE);

			sql = "select count(*) from SOLEXA";

			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(sql);

			rowcount = rs.next() ? rs.getInt(1) : 0;

			pbar.setMinimum(0);
			pbar.setMaximum(rowcount);
			pbar.setValue(0);

			System.err.println("The table has " + rowcount + " rows");

			rs.close();

			sql = "select length,sequence from CONSENSUS where contig_id = 119";

			rs = stmt.executeQuery(sql);

			if (rs.next()) {
				int length = rs.getInt(1);
				byte[] cdata = rs.getBytes(2);
				refseq = inflate(cdata, length);
			}

			System.err.println("The reference sequence is " + refseq.length
					+ " bases long");

			rs.close();

			stmt.close();
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
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

	private void initHash(int hashsize) {
		this.hashsize = hashsize;

		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
		}
	}

	private void createUI() {
		JFrame frame = new JFrame(this.getClass().getName());

		JPanel mainPanel = new JPanel(new BorderLayout());

		JPanel centrePanel = makeCentrePanel();

		mainPanel.add(centrePanel, BorderLayout.CENTER);

		JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));
		buttonPanel.add(btnRunQuery);
		mainPanel.add(buttonPanel, BorderLayout.SOUTH);

		btnRunQuery.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				btnRunQuery.setEnabled(false);
				runQuery();
			}
		});

		frame.getContentPane().add(mainPanel);

		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

		frame.pack();
		frame.setVisible(true);
	}

	private JPanel makeCentrePanel() {
		JPanel panel = new JPanel(new BorderLayout());

		Dimension d = pbar.getPreferredSize();
		d.width = 600;
		pbar.setPreferredSize(d);

		panel.add(pbar, BorderLayout.NORTH);
		
		JPanel panel2 = new JPanel(new FlowLayout());
		
		panel2.add(new JLabel("Hits: "));
		panel2.add(lblHits);
		
		panel.add(panel2, BorderLayout.CENTER);

		return panel;
	}

	private void runQuery() {
		SQLWorker worker = new SQLWorker();
		worker.execute();
	}

	class SQLWorker extends SwingWorker<Void, Integer> {
		private int counter;
		private int hits;
		private int hitsf, hitsr;
		private int hitseqs;

		public SQLWorker() {
		}

		protected Void doInBackground() throws Exception {
			try {
				counter = 0;
				hits = 0;
				hitsf = 0;
				hitsr = 0;
				hitseqs = 0;
				
				pbar.setValue(counter);
				lblHits.setText("" + hits);

				long clock0 = System.currentTimeMillis();

				ResultSet rs = pstmtFetchAll.executeQuery();

				while (rs.next()) {
					int id = rs.getInt(1);
					String name = rs.getString(2);
					byte[] sequence = rs.getBytes(3);
					
					int j1 = findHits(sequence);
					
					reverseComplement(sequence);
					
					int j2 = findHits(sequence);
					
					if (j1 > 0 || j2 > 0) {
						hitsf += j1;
						hitsr += j2;
						hits += j1 + j2;
						hitseqs++;
					}

					counter++;
					
					if ((counter % 1000) == 0)
						publish(counter);
				}

				rs.close();

				long ticks = System.currentTimeMillis() - clock0;
				System.err.println("Completed in " + ticks + " ms");
			} catch (SQLException e) {
				e.printStackTrace();
			}

			return null;
		}
		
		private void reverseComplement(byte[] sequence) {
			int seqlen = sequence.length;
			int halflen = seqlen / 2;
			
			for (int i = 0; i < halflen; i++) {
				byte a = sequence[i];
				byte b = sequence[seqlen - 1 - i];
				
				sequence[i] = complement(b);
				sequence[seqlen - 1 - i] = complement(a);
			}
		}
		
		private byte complement(byte c) {
			switch (c) {
				case BASE_A:
					return BASE_T;

				case BASE_C:
					return BASE_G;

				case BASE_G:
					return BASE_C;

				case BASE_T:
					return BASE_A;

				default:
					return c;
			}
		}
		
		private int findHits(byte[] sequence) {
			int k = 0;
			
			int myhash = 0;
			
			for (int i = 0; i < hashsize; i++) {
				myhash <<= 2;
				myhash |= IlluminaSpeedTest.hashCode(sequence[i]);
			}
			
			for (HashEntry entry = lookup[myhash]; entry != null; entry = entry.getNext())
				if (testSequenceMatch(sequence, entry))
					k++;
			
			return k;
		}
		
		private boolean testSequenceMatch(byte[] sequence, HashEntry entry) {
			return comparePaddedSequence(sequence, entry.getOffset());
		}
		
		private boolean comparePaddedSequence(byte[] sequence, int offset) {
			int seqlen = refseq.length;

			if (offset + sequence.length > seqlen)
				return false;

			for (int i = 0; i < sequence.length; i++) {
				byte oc = sequence[i];

				while (offset < seqlen && !isValid(refseq[offset]))
					offset++;

				if (offset < seqlen) {
					byte sc = refseq[offset];

					if (oc != sc)
						return false;

					offset++;
				} else
					return false;
			}

			return true;

		}

		protected void process(java.util.List<Integer> results) {
			for (int counter : results)
				pbar.setValue(counter);
			
			lblHits.setText("" + hits + " (" + hitsf + " F, " + hitsr + " R) "+ hitseqs + "/" + counter);
		}

		protected void done() {
			pbar.setValue(pbar.getMaximum());
			btnRunQuery.setEnabled(true);
		}
	}

	public static void main(String[] args) {
		int hashsize = Integer.getInteger("hashsize", DEFAULT_HASHSIZE);
		IlluminaSpeedTest ist = new IlluminaSpeedTest(hashsize);
		ist.run();
	}
}
