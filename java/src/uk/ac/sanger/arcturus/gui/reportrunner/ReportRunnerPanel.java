package uk.ac.sanger.arcturus.gui.reportrunner;

import uk.ac.sanger.arcturus.gui.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.Arcturus;

import javax.swing.*;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.MessageFormat;
import java.util.List;
import java.util.Vector;
import java.io.*;
import java.awt.*;
import java.awt.event.*;

import javax.swing.SwingUtilities;
import javax.swing.filechooser.*;

import java.awt.*;
import java.awt.event.*;
import java.io.InputStream;

public class ReportRunnerPanel extends MinervaPanel implements ActionListener{
	
	protected JTextArea textarea = new JTextArea();
	protected JButton btnRefresh;
	protected JButton btnSave;
	protected JButton btnCancel;
	
	protected JProgressBar pbarContigProgress = new JProgressBar();
	
	protected JFileChooser fileChooser = new JFileChooser();
	
	protected Statement stmt = null;
	protected String query = "";

	static String contigString = "Save statistics about contigs";
    static String freeReadsString = "Save statistics about free reads";
    static String userString = "Save statistics about your work";

	public ReportRunnerPanel(MinervaTabbedPane parent, ArcturusDatabase adb)
	{	
		super(parent, adb);
		
	    final JCheckBox contigButton = new JCheckBox(contigString);
		final JCheckBox freeReadsButton = new JCheckBox(freeReadsString);		
		final JCheckBox userButton = new JCheckBox(userString);	
		
		contigButton.setEnabled(true);
		freeReadsButton.setEnabled(false);
		userButton.setEnabled(false);
		
        JPanel radioPanel = new JPanel(new GridLayout(0, 1));
        radioPanel.add(contigButton);
        radioPanel.add(freeReadsButton);
        radioPanel.add(userButton);
        
    	add(radioPanel, BorderLayout.NORTH);
    	
		btnSave = new JButton("Save data as CSV");

		JPanel buttonPanel = new JPanel(new FlowLayout());
		buttonPanel.add(btnSave);

		add(buttonPanel, BorderLayout.SOUTH);

		btnSave.addActionListener(this);		
	}
	
	public void actionPerformed(ActionEvent event) {
			
			if (event.getActionCommand() == contigString) {
				query = "contig query";
			}
			else if (event.getActionCommand() == freeReadsString) {
				query = "free read query";
			}
			else if (event.getActionCommand() == userString) {
				query = "user query";
			}
			else if (event.getSource() == btnSave) {		
				Connection conn;
				try {
					conn = adb.getPooledConnection(this);
				
					stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
		              java.sql.ResultSet.CONCUR_READ_ONLY);		
					stmt.setFetchSize(Integer.MIN_VALUE);		
				} catch (ArcturusDatabaseException exception) {
					Arcturus.logSevere("An error occurred when trying to find your report output from the Arcturus database", exception);
					exception.printStackTrace();
				} catch (SQLException exception) {
					Arcturus.logSevere("An error occurred when trying to run the query to find your report output from the database", exception);
				}
				try {
					 ResultSet rs = stmt.executeQuery(query);
					 saveStatsToFile(rs);
				}
				catch (Exception exception) {
					Arcturus.logSevere("An error occurred when trying to save your report output", exception);
				}
			}
			else {
				// Do nothing
			}
	}
	
	protected void saveStatsToFile(ResultSet rs) throws SQLException {
		
		final JFileChooser fc = new JFileChooser();
		fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);

		int returnVal = fc.showSaveDialog(this);
		File file = fc.getSelectedFile();
		
		if (returnVal == JFileChooser.APPROVE_OPTION) {
			try {
				Arcturus.logWarning("Saving: " + file.getName() + ".\n");
				
				BufferedWriter writer = new BufferedWriter(new FileWriter(file));
				ResultSetMetaData rsmd = rs.getMetaData();
				int cols = rsmd.getColumnCount();	
				 
				while (rs.next()) {
					for (int col = 1; col <= cols; col++) {
						writer.write((String) rs.getObject(col));
					}
				} 
				writer.close();
			} 
			catch (IOException ioe) {
				Arcturus.logWarning("Error encountered whilst writing file "
						+ file.getPath(), ioe);
			}
		}
		else {
			Arcturus.logWarning("Save command cancelled by user\n");
		}
	}

	@Override
	public void refresh() throws ArcturusDatabaseException {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void closeResources() {
		// TODO Auto-generated method stub
		
	}

	@Override
	protected void createActions() {
		// TODO Auto-generated method stub
		
	}

	@Override
	protected void createClassSpecificMenus() {
		// TODO Auto-generated method stub
		
	}

	@Override
	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	protected boolean isRefreshable() {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	protected void addClassSpecificViewMenuItems(JMenu menu) {
		// TODO Auto-generated method stub
		
	}

	@Override
	protected void doPrint() {
		// TODO Auto-generated method stub
		
	}

}
	
