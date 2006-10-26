package uk.ac.sanger.arcturus.test;

import javax.swing.*;
import java.sql.*;
import java.awt.*;
import java.util.*;
import java.awt.event.*;
import javax.naming.Context;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

public class TestConnection implements ActionListener {
	JProgressBar pbTask1 = new JProgressBar();
	JProgressBar pbTask2 = new JProgressBar();
	JCheckBox cbxTwoConn = new JCheckBox("Two Connections", true);
	JCheckBox cbxNoBatch = new JCheckBox("No Batch", true);
	ArcturusDatabase adb;
	String columns;
	String tablename;
	
	public TestConnection(ArcturusDatabase adb, String columns, String tablename) {
		this.adb = adb;
		this.columns = columns;
		this.tablename = tablename;
	}
	
	public static void main(String[] args) {
		if (args.length < 4) {
			System.err.println("You must supply instance, organism, columns and table name");
			System.exit(1);
		}
		
		String instance = args[0];
		String organism = args[1];
		String columns = args[2];
		String tablename = args[3];
		
		Properties props = new Properties();

		Properties env = System.getProperties();

		props.put(Context.INITIAL_CONTEXT_FACTORY,
					env.get(Context.INITIAL_CONTEXT_FACTORY));
		
		props.put(Context.PROVIDER_URL,
					env.get(Context.PROVIDER_URL));

		try {
			ArcturusInstance ai = new ArcturusInstance(props, instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
	
			TestConnection tc = new TestConnection(adb, columns, tablename);
			tc.run();
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public void run() {
		createUI();
	}
	
	public void createUI() {
		JFrame frame = new JFrame("TestConnection");
		
		JPanel mainPanel = new JPanel(new BorderLayout());
		
		JPanel panel = new JPanel(new GridLayout(2, 1));
		
		panel.add(pbTask1);
		panel.add(pbTask2);
		
		mainPanel.add(panel, BorderLayout.CENTER);
		
		JPanel controlPanel = new JPanel(new FlowLayout());
		
		JButton btnGo = new JButton("Go!");
		btnGo.addActionListener(this);
		
		controlPanel.add(btnGo);
		controlPanel.add(cbxTwoConn);
		controlPanel.add(cbxNoBatch);

		mainPanel.add(controlPanel, BorderLayout.SOUTH);
		
		frame.setContentPane(mainPanel);
		
		frame.pack();
		
		frame.setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
		
		frame.show();
	}

	public void actionPerformed(ActionEvent e) {
		try {
			Connection conn = adb.getConnection();
			
			boolean noBatch = cbxNoBatch.isSelected();

			Task task1 = new Task(conn, pbTask1, columns, tablename, noBatch);
			Thread thread1 = new Thread(task1);
			thread1.start();
			
			if (cbxTwoConn.isSelected())
				conn = adb.getUniqueConnection();
		
			Task task2 = new Task(conn, pbTask2, columns, tablename, noBatch);
			
			Thread thread2 = new Thread(task2);
			thread2.start();
		}
		catch (SQLException sqle) {
			sqle.printStackTrace();
		}
	}
	
	class Task implements Runnable {
		JProgressBar pb;
		Connection conn;
		String columns;
		String tablename;
		boolean noBatch;
		Random rand = new Random();
		
		public Task(Connection conn, JProgressBar pb, String columns, String tablename, boolean noBatch) {
			this.pb = pb;
			this.conn = conn;
			this.columns = columns;
			this.tablename = tablename;
			this.noBatch = noBatch; 
		}
		
		public void run() {
			try {
				String query = "select count(*) from " + tablename;

				Statement stmt;
				
				if (noBatch) {
					stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
							java.sql.ResultSet.CONCUR_READ_ONLY);
					stmt.setFetchSize(Integer.MIN_VALUE);		
				
				} else
					stmt = conn.createStatement();
		
				ResultSet rs = stmt.executeQuery(query);
				rs.next();
				
				pb.setMaximum(rs.getInt(1));
			
				query = "select " + columns + " from " + tablename;
				
				rs = stmt.executeQuery(query);
				
				int i = 0;
				
				while (rs.next())
					pb.setValue(++i);
				
				stmt.close();
			}
			catch (Exception e) {
				e.printStackTrace();
			}
		}
	}
}
