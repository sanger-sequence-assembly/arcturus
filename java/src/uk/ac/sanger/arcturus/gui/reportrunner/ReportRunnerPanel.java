package uk.ac.sanger.arcturus.gui.reportrunner;

import uk.ac.sanger.arcturus.gui.*;

import uk.ac.sanger.arcturus.consistencychecker.ReportRunnerEvent;
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
	
	protected Worker worker;
	
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
	
	public void actionPerformed(ActionEvent e) {
			
			if (e.getActionCommand() == contigString) {
				query = "contig query";
			}
			else if (e.getActionCommand() == freeReadsString) {
				query = "free read query";
			}
			else if (e.getActionCommand() == userString) {
				query = "user query";
			}
			else if (e.getSource() == btnSave) {		
				Connection conn = adb.getPooledConnection(this);
				stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
		              java.sql.ResultSet.CONCUR_READ_ONLY);		
				stmt.setFetchSize(Integer.MIN_VALUE);		
			
				try {
					 rs = stmt.executeQuery(query);
					 ResultSetMetaData rsmd = rs.getMetaData();
					 int cols = rsmd.getColumnCount();	
					 saveStatsToFile(rs);
				}
				catch (Exception e) {
					Arcturus.logSevere("An error occurred when trying to save your report output to ", e);
				}
			}
			else {
				// Do nothing
			}
	}
	
	protected void saveStatsToFile(ResultSet rs) {
		int rc = fileChooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			//Create a file chooser that can see files and directories to help user decide where to save
			final JFileChooser fc = new JFileChooser();
			fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
			
			int returnVal = fc.showSaveDialog(this);
		    if (returnVal == JFileChooser.APPROVE_OPTION) {
		        Arcturus.logWarning("Saving: " + file.getName() + "." + newline);
		            
		     try {
		            File file = fc.getSelectedFile();
		            BufferedWriter bw = new BufferedWriter(new FileWriter(file));

		            while (rs.next()) {
		            	for (int col = 1; col <= cols; col++) {
		            		bw.write((String) rs.getObject(col));
		            	}
		            } 
		            br.close();
				} 
		        catch (IOException ioe) {
					Arcturus.logWarning("Error encountered whilst reading file "
								+ file.getPath(), ioe);
		        }
		      }
			else {
		          log.append("Save command cancelled by user." + newline);
		    }
		}
	}

}
	
