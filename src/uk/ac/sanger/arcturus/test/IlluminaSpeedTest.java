package uk.ac.sanger.arcturus.test;

import javax.swing.*;
import java.sql.*;
import java.awt.*;
import java.util.*;
import java.awt.event.*;

public class IlluminaSpeedTest {
	private static final String HOST = "mcs1a";
	private static final int PORT = 15001;
	private static final String DATABASE = "SUIS";
	private static final String USERNAME = "arcturus";
	private static final String PASSWORD ="***REMOVED***";
	
	private static final int ALL_AT_ONCE = 1;
	private static final int ROW_AT_A_TIME = 2;
	private static final int BLOCK_AT_A_TIME = 3;
	
	private int mode = ALL_AT_ONCE;
	
	private Connection conn;
	
	private PreparedStatement pstmtFetchAll;
	private PreparedStatement pstmtFetchNextBlock;

	private int rowcount = 0;
	
	private JProgressBar pbar = new JProgressBar();
	
	private JButton btnRunQuery = new JButton("Run");
	
	private JTextField txtChunk = new JTextField("10000", 10);

	private JRadioButton rbDefault = new JRadioButton("Default");
	private JRadioButton rbRowAtATime = new JRadioButton("One row at a time");
	private JRadioButton rbBlockAtATime = new JRadioButton("One block at a time");
	
	public void run() {
		makeConnection();
		createUI();
	}
	
	private void makeConnection() {
		String url = "jdbc:mysql://" + HOST + ":" + PORT + "/" + DATABASE;
		String driver = "com.mysql.jdbc.Driver";

		try {
			Class.forName(driver);

			conn = DriverManager.getConnection(url, USERNAME, PASSWORD);
			
			String sql = "select id,name,sequence from SOLEXA";
			
			pstmtFetchAll = conn.prepareStatement(sql, 
					ResultSet.TYPE_FORWARD_ONLY,
					ResultSet.CONCUR_READ_ONLY);
			
			sql = "select id,name,sequence from SOLEXA where id > ? limit ?";
			
			pstmtFetchNextBlock = conn.prepareStatement(sql);
			
			sql = "select count(*) from SOLEXA";
			
			Statement stmt = conn.createStatement();
			
			ResultSet rs = stmt.executeQuery(sql);
			
			rowcount = rs.next() ? rs.getInt(1) : 0;
			
			pbar.setMinimum(0);
			pbar.setMaximum(rowcount);
			pbar.setValue(0);
			
			System.err.println("The table has " + rowcount + " rows");
			
			rs.close();
			
			stmt.close();
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
	
	private void createUI() {
		JFrame frame = new JFrame(this.getClass().getName());
		
		JPanel mainPanel = new JPanel(new BorderLayout());
		
		ButtonGroup group = new ButtonGroup();
		group.add(rbDefault);
		group.add(rbRowAtATime);
		group.add(rbBlockAtATime);
		
		rbDefault.setSelected(true);
		txtChunk.setEnabled(false);
		
		rbDefault.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				txtChunk.setEnabled(rbBlockAtATime.isSelected());
				mode = ALL_AT_ONCE;
			}			
		});
	
		rbRowAtATime.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				txtChunk.setEnabled(rbBlockAtATime.isSelected());
				mode = ROW_AT_A_TIME;
			}			
		});
	
		rbBlockAtATime.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				txtChunk.setEnabled(rbBlockAtATime.isSelected());
				mode = BLOCK_AT_A_TIME;
			}			
		});
		
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
		
		JPanel panel2 = new JPanel(new FlowLayout());
		
		panel2.add(rbDefault);
		panel2.add(rbRowAtATime);
		panel2.add(rbBlockAtATime);
		
		panel2.add(new JLabel("Block size: "));
		panel2.add(txtChunk);
		
		panel.add(panel2, BorderLayout.CENTER);
		
		panel.add(pbar, BorderLayout.SOUTH);
		
		return panel;
	}
	
	private void runQuery() {
		SQLWorker worker = new SQLWorker(mode);
		worker.execute();
	}

	class SQLWorker extends SwingWorker<Void, Integer> {		
		private int mode;
		private int counter;

		public SQLWorker(int mode) {
			this.mode = mode;
		}

		protected Void doInBackground() throws Exception {
			try {
				counter = 0;
				pbar.setValue(counter);
				
				long clock0 = System.currentTimeMillis();

				pstmtFetchAll.setFetchSize(mode == ALL_AT_ONCE ? 0 : Integer.MIN_VALUE);
				
				System.err.print("About to execute query ...");
				ResultSet rs = pstmtFetchAll.executeQuery();
				System.err.println(" done.");

				while (rs.next()) {
					int id = rs.getInt(1);
					String name = rs.getString(2);
					byte[] sequence = rs.getBytes(3);
					
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

		protected void process(java.util.List<Integer> results) {
			for (int counter : results)
				pbar.setValue(counter);
		}

		protected void done() {
			pbar.setValue(pbar.getMaximum());
			btnRunQuery.setEnabled(true);
		}
	}

	public static void main(String[] args) {
		IlluminaSpeedTest ist = new IlluminaSpeedTest();
		ist.run();
	}
}
