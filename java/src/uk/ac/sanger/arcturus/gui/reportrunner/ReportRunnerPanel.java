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
	
	static String contigString = "Save statistics about contigs";
    static String freeReadsString = "Save statistics about free reads";
    static String userString = "Save statistics about your work";
    static String saveString = "Save statistics to a comma-separated file on your machine";

    protected JButton btnSave = new JButton(saveString);
	
	final JCheckBox contigButton = new JCheckBox(contigString);
	final JCheckBox freeReadsButton = new JCheckBox(freeReadsString);		
	final JCheckBox userButton = new JCheckBox(userString);	
	
	protected JProgressBar pbarContigProgress = new JProgressBar();
	
	protected JFileChooser fileChooser = new JFileChooser();
	
	protected Statement stmt = null;
	protected String query = "";
	protected String titleString = "";

	public ReportRunnerPanel(MinervaTabbedPane parent, ArcturusDatabase adb)
	{	
		super(parent, adb);
		
		contigButton.setEnabled(true);
		freeReadsButton.setEnabled(true);
		userButton.setEnabled(true);
		
        JPanel radioPanel = new JPanel(new GridLayout(0, 1));
        radioPanel.add(contigButton);
        radioPanel.add(freeReadsButton);
        radioPanel.add(userButton);
        
    	add(radioPanel, BorderLayout.NORTH);

		JPanel buttonPanel = new JPanel(new GridLayout(0, 1));
		radioPanel.add(btnSave);

		add(buttonPanel, BorderLayout.SOUTH);

		contigButton.addActionListener(this);
		freeReadsButton.addActionListener(this);
		userButton.addActionListener(this);
		btnSave.addActionListener(this);
		
		createMenus();
	}
	
	public void actionPerformed(ActionEvent event) {
			
		Arcturus.logInfo("in actionPerformed because " +
				event.getSource() + "" +
				"has been pressed and query holds: " + query);
		
			//if (event.getActionCommand() == contigString) {
			if (event.getSource() == contigButton) {
				query = "select " +
						"project_id, ','," +
						"statsdate, ',', " +
						"name, ',', " +
						"total_contigs, ',', " +
						"total_reads, ',', " +
						"total_contig_length, ',', " +
						"mean_contig_length, ',', " +
						"stddev_contig_length, ',', " +
						"max_contig_length, ',' ," +
						"n50_contig_length " +
						"from PROJECT_CONTIG_HISTORY order by project_id";
				titleString =  
				"project_id," +
				"statsdate," +
				"name," +
				"total_contigs," +
				"total_reads," +
				"total_contig_length," +
				"mean_contig_length," +
				"stddev_contig_length," +
				"max_contig_length," +
				"n50_contig_length";
				
				contigButton.setSelected(true);
				freeReadsButton.setSelected(false);
				userButton.setSelected(false);
				btnSave.setEnabled(true);
			}
			else if (event.getActionCommand() == freeReadsString) {
				query = "select " +
						"organism, ',', " +
						"statsdate, ',', " +
						"total_reads, ',', " +
						"reads_in_contigs, ',', " +
						"free_reads " +
						"from ORGANISM_HISTORY " +
						"order by statsdate ASC";
				titleString = 
				"organism," +
				"statsdate," +
				"total_reads," +
				"reads_in_contigs," +
				"free_reads";
				
				contigButton.setSelected(false);
				freeReadsButton.setSelected(false);
				userButton.setSelected(true);
				btnSave.setEnabled(true);
			}
			else if (event.getActionCommand() == userString) {
				query = "select count(*) from USER";
				titleString = "count";
				
				contigButton.setSelected(false);
				freeReadsButton.setSelected(false);
				userButton.setSelected(true);
				btnSave.setEnabled(true);
			}
			else if (event.getSource() == btnSave) {		
				
				contigButton.setEnabled(false);
				freeReadsButton.setEnabled(false);
				userButton.setEnabled(true);
				
				Arcturus.logInfo("query being run is: " + query);
				Connection conn;
				try {
					conn = adb.getPooledConnection(this);
				
					stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
		              java.sql.ResultSet.CONCUR_READ_ONLY);		
					stmt.setFetchSize(Integer.MIN_VALUE);		
					
					ResultSet rs = stmt.executeQuery(query);
					saveStatsToFile(rs);
				} catch (ArcturusDatabaseException exception) {
					Arcturus.logSevere("An error occurred when trying to find your report output from the Arcturus database", exception);
					exception.printStackTrace();
				} catch (SQLException exception) {
					Arcturus.logSevere("An error occurred when trying to run the query to find your report output from the database", exception);
				} catch (Exception exception) {
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
				Arcturus.logInfo("Saving: " + file.getName() + ".\n");
				
				BufferedWriter writer = new BufferedWriter(new FileWriter(file));
				ResultSetMetaData rsmd = rs.getMetaData();
				int cols = rsmd.getColumnCount();	

				Arcturus.logInfo("There are " + cols +" columns in the data set");
				
				//writer.newLine();
				writer.write(titleString);
				
				while (rs.next()) {
					for (int col = 1; col <= cols; col++) {
						writer.write((String) rs.getObject(col));
					}
				} 
				writer.close();
				Arcturus.logInfo("File " + file.getName() + " saved successfully");
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
	
