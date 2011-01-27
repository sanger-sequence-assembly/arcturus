package uk.ac.sanger.arcturus.gui.reportrunner;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.utils.CheckConsistency;

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
    static String splitString = "Save statistics for all splits";
    static String splitExplanationString ="Selecting 'Save statistics for all splits' will save only the data that you are authorised to see in Minerva";
    static String dateStartExplanationString ="Please enter the start date for the data you want to export";
    static String dateEndExplanationString ="Please enter the end date for the data you want to export";
    static String dateFormatString = "YYYY-MM-DD";
    
    protected JButton btnSave = new JButton(saveString);
	
	final JCheckBox contigBox = new JCheckBox(contigString);
	final JCheckBox freeReadsBox = new JCheckBox(freeReadsString);		
	final JCheckBox userBox = new JCheckBox(userString);	
	final JCheckBox allSplitsBox = new JCheckBox(splitString);
	final JLabel splitExplanation = new JLabel(splitExplanationString);
	final JLabel statusLine = new JLabel("");
	
	final JFormattedTextField sinceField = new JFormattedTextField(20);
	final JFormattedTextField untilField = new JFormattedTextField(20);
     	
	protected JFileChooser fileChooser = new JFileChooser();
	
	protected Statement stmt = null;
	protected String query = "";
	protected String titleString = "";

	public ReportRunnerPanel(MinervaTabbedPane parent, ArcturusDatabase adb)
	{	
		super(parent, adb);
		
		contigBox.setEnabled(true);
		freeReadsBox.setEnabled(true);
		userBox.setEnabled(true);
		
		allSplitsBox.setEnabled(true);
		allSplitsBox.setSelected(true);
		
		btnSave.setEnabled(true);
		
		sinceField.setText(dateFormatString);
		untilField.setText(dateFormatString);
		
		sinceField.setColumns(11);
		untilField.setColumns(11);
		
        JPanel mainPanel = new JPanel(new GridLayout(0,3));
        mainPanel.add(contigBox);
        mainPanel.add(new Label(" "));
        mainPanel.add(new Label(" "));
        
        mainPanel.add(freeReadsBox);
        mainPanel.add(new Label(" "));
        mainPanel.add(new Label(" "));

        mainPanel.add(userBox);
        mainPanel.add(new Label(" "));
        mainPanel.add(new Label(" "));

        mainPanel.add(sinceField);
        mainPanel.add(new Label(dateStartExplanationString));
        mainPanel.add(new Label(" "));
        
        mainPanel.add(untilField);
        mainPanel.add(new Label(dateEndExplanationString));
        mainPanel.add(new Label(" "));
        
        mainPanel.add(allSplitsBox);
        mainPanel.add(new Label(" "));
        mainPanel.add(new Label(" "));
		
        mainPanel.add(splitExplanation);
		mainPanel.add(btnSave);
		mainPanel.add(new Label(" "));

		contigBox.addActionListener(this);
		freeReadsBox.addActionListener(this);
		userBox.addActionListener(this);
		
		sinceField.addActionListener(this);
		untilField.addActionListener(this);
		
		allSplitsBox.addActionListener(this);
		btnSave.addActionListener(this);
		
		add(mainPanel, BorderLayout.NORTH);

		createMenus();
	}
	
	public void actionPerformed(ActionEvent event) {
			
		String since = this.sinceField.getText();
		String until = this.untilField.getText();
	
		Arcturus.logInfo("in actionPerformed because " +
				event.getActionCommand() + 
				" has been pressed and the dates entered are " + since + " and " + until);
	
		if (event.getSource()== contigBox) {		
			if ((since.equals(dateFormatString) )|| (until.equals(dateFormatString)) )
			{
				if (allSplitsBox.isEnabled()) {
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
					"from PROJECT_CONTIG_HISTORY " +
					" order by project_id";
				}
				else {
					// display a message to type in valid dates
					statusLine.setText("Please enter valid dates for your report");
					// sort out the validation for FormattedField
				}
			}
			else {
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
						"from PROJECT_CONTIG_HISTORY " +
						"where statsdate >= " +  since +
						" and statsdate <= " + until +
						" order by project_id";
			}
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
				
			contigBox.setSelected(true);
			contigBox.setEnabled(false);				
			freeReadsBox.setEnabled(false);
			userBox.setEnabled(false);
			allSplitsBox.setEnabled(false);
			btnSave.setEnabled(true);
		}
		else if (event.getSource() == freeReadsBox) {
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
				
				contigBox.setEnabled(false);		
				freeReadsBox.setSelected(true);
				freeReadsBox.setEnabled(true);	
				userBox.setEnabled(false);
				allSplitsBox.setEnabled(false);
				btnSave.setEnabled(true);
			}
			else if (event.getSource() == userBox) {
				query = "select count(*) from USER";
				titleString = "count";
				
				contigBox.setEnabled(false);
				freeReadsBox.setEnabled(false);			
				userBox.setSelected(true);
				userBox.setEnabled(false);
				allSplitsBox.setEnabled(false);
				btnSave.setEnabled(true);
			}
			else if (event.getSource() == btnSave) {		
				
				contigBox.setEnabled(false);
				freeReadsBox.setEnabled(false);
				userBox.setEnabled(false);
				allSplitsBox.setEnabled(true);
				
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
		Arcturus.logInfo("at the end of actionPerformed query holds: " + query);
	}
	
	protected void resetAllBoxes() {
		contigBox.setEnabled(true);
		contigBox.setSelected(false);
		
		freeReadsBox.setEnabled(true);		
		freeReadsBox.setSelected(false);
		
		userBox.setEnabled(true);
		userBox.setSelected(false);
		
		allSplitsBox.setEnabled(true);
		allSplitsBox.setSelected(false);
		
		btnSave.setEnabled(true);
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
			// User has cancelled, so reset all the buttons to enabled and unchecked 
			resetAllBoxes();
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
	
	class Worker extends SwingWorker<Void, String> {
		protected Void doInBackground() throws Exception {
			try {
		//checker.checkConsistency(adb, this, true);
			}
			catch (Exception e) {
				Arcturus.logWarning("An error occurred whilst checking the database", e);
			}
			return null;
		}

		protected void done() {
			if (isCancelled())
				//checker.cancel();
	
				actionRefresh.setEnabled(true);
				//btnCancel.setEnabled(false);
		}

		protected void process(List<String> messages) {
			for (String message : messages) {
				//textarea.append(message);
				//textarea.append("\n");
			}
		}

		public void report(String message) {
			publish(message);
		}
}


}
	
