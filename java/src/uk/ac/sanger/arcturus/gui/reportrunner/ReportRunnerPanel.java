package uk.ac.sanger.arcturus.gui.reportrunner;

import uk.ac.sanger.arcturus.gui.*;
import java.util.Calendar.*;
import java.util.Locale.*;

import uk.ac.sanger.arcturus.utils.CheckConsistency;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.Arcturus;

import com.toedter.calendar.*;
import java.util.Calendar;
import java.util.Date;
import java.util.EventListener;
import java.util.Locale;

import javax.swing.*;

import java.lang.String;
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
    static String splitExplanationString ="You can save only the data that you are authorised to see in Minerva";
    static String dateStartExplanationString ="Please enter the start date for the data you want to export";
    static String dateEndExplanationString ="Please enter the end date for the data you want to export";
    static String dateFormatString = "YYYY-MM-DD";
    
    protected JButton btnSave = new JButton(saveString);
	
	final JCheckBox contigBox = new JCheckBox(contigString);
	final JCheckBox freeReadsBox = new JCheckBox(freeReadsString);		
	final JCheckBox userBox = new JCheckBox(userString);	
	final JLabel splitExplanation = new JLabel(splitExplanationString);
	final JLabel statusLine = new JLabel("");
	
	final JFormattedTextField sinceField = new JFormattedTextField(dateFormatString);
	final JFormattedTextField untilField = new JFormattedTextField(dateFormatString);
     	
	protected JFileChooser fileChooser = new JFileChooser();
	
	protected Statement stmt = null;
	protected String query = "";
	protected String titleString = "";
	
	protected String contigTitleString = 
		"project_id," +
		"statsdate," +
		"name," +
		"total_contigs," +
		"total_reads," +
		"total_contig_length," +
		"mean_contig_length," +
		"stddev_contig_length," +
		"max_contig_length," +
		"n50_contig_length\n";
    protected String contigQueryStart = "select " +
	"project_id, " +
	"statsdate, " +
	"name,  " +
	"total_contigs,  " +
	"total_reads,  " +
	"total_contig_length,  " +
	"mean_contig_length,  " +
	"stddev_contig_length,  " +
	"max_contig_length, " +
	"n50_contig_length " +
	"from PROJECT_CONTIG_HISTORY ";
    protected String contigQueryEnd = " order by project_id";
    
    protected String freeReadsTitleString = 
		"organism," +
		"statsdate," +
		"total_reads," +
		"reads_in_contigs," +
		"free_reads\n";
    protected String freeReadsQueryStart = "select " +
	"organism, " +
	"statsdate,  " +
	"total_reads,  " +
	"reads_in_contigs,  " +
	"free_reads " +
	"from ORGANISM_HISTORY ";
    protected String freeReadsQueryEnd = "order by statsdate ASC";
    
    protected String since = dateFormatString;
    protected String until = dateFormatString;
    
    protected JCalendar calendarSince = new JCalendar();
	protected JCalendar calendarUntil = new JCalendar();
	
	
	public ReportRunnerPanel(MinervaTabbedPane parent, ArcturusDatabase adb)
	{	
		super(parent, adb);
		
		sinceField.setName(dateFormatString);  // crashes here time for lunch
		//sinceField.setText(dateFormatString);
		untilField.setText(dateFormatString);
		statusLine.setText("Please enter valid dates for your report or tick the 'Save all statistics box");
		
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
        //mainPanel.add(calendarSince);
        mainPanel.add(new Label(dateStartExplanationString));
        mainPanel.add(new Label(" "));
        
        mainPanel.add(untilField);
        //mainPanel.add(calendarUntil);
        mainPanel.add(new Label(dateEndExplanationString));
        mainPanel.add(new Label(" "));
		
        mainPanel.add(splitExplanation);
		mainPanel.add(btnSave);
		mainPanel.add(new Label(" "));
		
		mainPanel.add(statusLine);
		mainPanel.add(new Label(" "));
		mainPanel.add(new Label(" "));

		contigBox.addActionListener(this);
		freeReadsBox.addActionListener(this);
		userBox.addActionListener(this);
		
	    sinceField.addActionListener(this);
		untilField.addActionListener(this);
	
		btnSave.addActionListener(this);
		
		add(mainPanel, BorderLayout.NORTH);
		startButtons();
		createMenus();
	}
	
	public void actionPerformed(ActionEvent event) {
			
		Arcturus.logInfo("in actionPerformed because " + event.getActionCommand() + 
				" has been pressed and the dates entered are " + since + " and " + until);
	
		if (event.getSource()== contigBox) {		
			query = contigQueryStart;
			preventOtherSelection();
			titleString =  contigTitleString;					
		}
		else if (event.getSource() == freeReadsBox) {
			query = freeReadsQueryStart;
			preventOtherSelection();
			titleString =  freeReadsTitleString;
		}
		else if (event.getSource() == userBox) {
			// add in checks as for other reports and David's SQL
				query = "select count(*) from USER";
				titleString = "count";
		}
		else if ((event.getSource() == sinceField) || (event.getSource() == untilField)) {
			
		}
		else if (event.getSource() == btnSave) {			
			sinceField.setEnabled(false);
			untilField.setEnabled(false);
			since = sinceField.getText();
			until = untilField.getText();
			
			if ((since.equals(dateFormatString) )|| (until.equals(dateFormatString)) ) {
					statusLine.setText("Please enter valid dates for your report or tick the 'All data' box");
				}
			else {
				query = query + " where statsdate >= '" +  since +
			"' and statsdate <= '" + until + "' order by statsdate";
			}
			
			preventOtherSelection();
			
			//Date sinceDate = (Date) sinceField.getValue();
			//Date sinceDate = calendarSince.getDate();
			//since = sinceDate.toString();
			//split into year, month, day on the -
			// create the matching Date
		
			//Date untilDate = calendarUntil.getDate();
			//Date untilDate = (Date) untilField.getValue();
			//until = untilDate.toString();
			Arcturus.logInfo("query being run is: " + query);
			
			//if (sinceDate.before(untilDate)) {
			if (true) {
				Connection conn;	
				try {
						conn = adb.getPooledConnection(this);
					
						stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
			              java.sql.ResultSet.CONCUR_READ_ONLY);		
						stmt.setFetchSize(Integer.MIN_VALUE);		
						
						ResultSet rs = stmt.executeQuery(query);
						saveStatsToFile(rs);
					} catch (ArcturusDatabaseException exception) {
						statusLine.setText("An error occurred when trying to find your report output from the Arcturus database");
						Arcturus.logSevere("An error occurred when trying to find your report output from the Arcturus database", exception);
						resetAllButtons();
						exception.printStackTrace();
					} catch (SQLException exception) {
						statusLine.setText("An error occurred when trying to run the query to find your report output from the database");
						Arcturus.logSevere("An error occurred when trying to run the query to find your report output from the database", exception);
						resetAllButtons();
					} catch (Exception exception) {
						statusLine.setText("An error occurred when trying to save your report output");
						Arcturus.logSevere("An error occurred when trying to save your report output", exception);
						resetAllButtons();
				}	
			}
			else {
				statusLine.setText("Date" + since + " is not before date " + until);
				Arcturus.logInfo("Date" + since + " is not before date " + until);					
			}
		}
		else {
				// Do nothing
		}	
		Arcturus.logInfo("at the end of actionPerformed query holds: " + query);
	}
	
	protected void startButtons() {
		contigBox.setEnabled(true);
		freeReadsBox.setEnabled(true);
		userBox.setEnabled(true);
		
		btnSave.setEnabled(true);
	}
	
	protected void preventOtherSelection() {
		contigBox.setEnabled(false);				
		freeReadsBox.setEnabled(false);
		userBox.setEnabled(false);
		
		btnSave.setEnabled(true);
	}
	
	protected void resetAllButtons() {
		contigBox.setEnabled(true);
		contigBox.setSelected(false);
		
		freeReadsBox.setEnabled(true);		
		freeReadsBox.setSelected(false);
		
		userBox.setEnabled(true);
		userBox.setSelected(false);
		
		sinceField.setEnabled(true);
		untilField.setEnabled(true);
		
		btnSave.setEnabled(false);
		query = "";
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
				
				String colValue = "";
				
				while (rs.next()) {
					for (int col = 1; col <= cols; col++) {
						if (col>1) {
							writer.write(",");
						}
						colValue = String.valueOf(rs.getObject(col));
						writer.write(colValue);			
					}
					writer.write("\n");
				} 
				writer.close();
				Arcturus.logInfo("File " + file.getName() + " saved successfully");
				statusLine.setText("Your data has been successfully saved to " + file.getName());
				resetAllButtons();
			} 
			catch (IOException ioe) {
				Arcturus.logWarning("Error encountered whilst writing file "
						+ file.getPath(), ioe);
				resetAllButtons();
			}
		}
		else {
			// User has cancelled, so reset all the buttons to enabled and unchecked 
			Arcturus.logWarning("Save command cancelled by user\n");
			resetAllButtons();
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
	
