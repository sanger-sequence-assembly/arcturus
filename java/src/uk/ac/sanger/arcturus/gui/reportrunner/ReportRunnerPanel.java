package uk.ac.sanger.arcturus.gui.reportrunner;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectListModel;
import uk.ac.sanger.arcturus.gui.common.projectlist.ProjectProxy;

import java.util.Calendar.*;
import java.util.Locale.*;

import uk.ac.sanger.arcturus.people.PeopleManager;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.people.role.Role;
import uk.ac.sanger.arcturus.utils.CheckConsistency;

import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.Arcturus;

import com.toedter.calendar.*;
import java.util.Calendar;
import java.util.Date;
import java.util.EventListener;
import java.util.GregorianCalendar;
import java.util.Locale;
import java.util.Set;


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
import java.awt.BorderLayout;

import javax.swing.*;
import javax.swing.border.Border;
import javax.swing.border.EtchedBorder;
import javax.swing.SwingUtilities;
import javax.swing.border.Border;
import javax.swing.event.ListDataEvent;
import javax.swing.event.ListDataListener;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;
import javax.swing.filechooser.*;

import java.awt.*;
import java.awt.event.*;
import java.io.InputStream;

public class ReportRunnerPanel extends MinervaPanel implements ActionListener{
	
	static String contigString = "Save statistics about contigs";
    static String freeReadsString = "Save statistics about free reads";
    static String contigTransferString = "Save statistics about contig transfers";
    static String projectActivityString = "Save statistics about project activity";
    static String saveString = "Save statistics to a comma-separated file on your machine";
    static String splitExplanationString ="You can save only the data that you are authorised to see in Minerva";
    static String dateStartExplanationString ="Please enter the start date";
    static String dateEndExplanationString ="Please enter the end date";
    static String dateFormatString = "YYYY-MM-DD";
    static String projectFormatString = "nnnnnn";
    static String emailFormatString = "email";
    static String emailExplanationString = "Please enter the email login name";
    static String projectStartExplanationString ="Please enter the start project id";
    static String projectEndExplanationString ="Please enter the end project id";
    static String allSplitsString="All projects"; 
    
    protected JButton btnSave = new JButton(saveString);
    protected JCheckBox allSplitsBox = new JCheckBox(allSplitsString);
    
	final JCheckBox contigBox = new JCheckBox(contigString);
	final JCheckBox freeReadsBox = new JCheckBox(freeReadsString);		
	final JCheckBox contigTransferBox = new JCheckBox(contigTransferString);	
	final JCheckBox projectActivityBox = new JCheckBox(projectActivityString);	
	
	final JLabel splitExplanation = new JLabel(splitExplanationString);
	final JLabel statusLine = new JLabel("");
	
	final JFormattedTextField sinceField = new JFormattedTextField(dateFormatString);
	final JFormattedTextField untilField = new JFormattedTextField(dateFormatString);
     	
	final JFormattedTextField startProjectField = new JFormattedTextField(projectFormatString);
	final JFormattedTextField endProjectField = new JFormattedTextField(projectFormatString);
	
	final JFormattedTextField emailField = new JFormattedTextField(emailFormatString);
	
	final static int maxGap = 20;
	private final Border LOWERED_ETCHED_BORDER = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
	
	protected JFileChooser fileChooser = new JFileChooser();
	
	protected JList projectList;
	protected ProjectListModel plm = new ProjectListModel(adb);
	// replace message line with this? 
	// protected JTextArea txtMessages = new JTextArea(20, 40);
	
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
    
    protected String freeReadsTitleString = 
		"organism," +
		"statsdate," +
		"total_reads," +
		"reads_in_contigs," +
		"free_reads," +
		"asped_reads," +
		"next_gen_reads\n";
    protected String freeReadsQueryStart = "select " +
	"organism, " +
	"statsdate,  " +
	"total_reads,  " +
	"reads_in_contigs,  " +
	"free_reads, " +
	"asped_reads, " +
	"next_gen_reads "+
	"from ORGANISM_HISTORY ";
    
    protected String contigTransferTitleString = "statsdate, name, contig_transfers\n";
    protected String projectActivityTitleString = "statsdate, name, total_contigs, total_contig_length, n50_contig_length\n";
    
    protected String since = dateFormatString;
    protected String until = dateFormatString;
    protected String projectName = "";
    protected String email = "";
    
    protected JCalendar calendarSince = new JCalendar();
	protected JCalendar calendarUntil = new JCalendar();
	
	protected Person loggedInUser = new Person(PeopleManager.getEffectiveUID());
	
	public ReportRunnerPanel(MinervaTabbedPane parent, ArcturusDatabase adb) throws ArcturusDatabaseException
	{	
		
		super(parent, adb);
		
		int vfill = 5;
		
		plm = new ProjectListModel(adb);
		emailField.setText(loggedInUser.toString());
		
		contigBox.addActionListener(this);
		freeReadsBox.addActionListener(this);
		contigTransferBox.addActionListener(this);
		projectActivityBox.addActionListener(this);
		allSplitsBox.addActionListener(this);
		
		sinceField.addActionListener(this);
		untilField.addActionListener(this);
		startProjectField.addActionListener(this);
		endProjectField.addActionListener(this);
		emailField.addActionListener(this);
	
		btnSave.addActionListener(this);
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));
		
		add(createButtonPanel());
		add(Box.createVerticalStrut(vfill));
		add(createDatePanel());
		add(Box.createVerticalStrut(vfill));
		add(createProjectPanel());
		add(Box.createVerticalStrut(vfill));
		add(createSavePanel());
		add(Box.createVerticalStrut(vfill));
		add(createTopPanel());
		
		startButtons();
		createMenus();
	}
	
	public void actionPerformed(ActionEvent event) {
			
		Arcturus.logInfo("in actionPerformed because " + event.getSource() + 
				" has been pressed and the dates entered are " + since + " and " + until + " and the chosen project is " + projectName + "and the email is " + email);
	
		if (event.getSource()== contigBox) {		
			query = contigQueryStart;
			titleString =  contigTitleString;
			preventOtherSelection();
		}
		else if (event.getSource() == freeReadsBox) {
			query = freeReadsQueryStart;
			titleString =  freeReadsTitleString;
			preventOtherSelection();
		}
		else if (event.getSource() == contigTransferBox) {
			sinceField.setEnabled(false);
			untilField.setEnabled(false);
			allSplitsBox.setEnabled(false);
			titleString = contigTransferTitleString;
			preventOtherSelection();
		}
		else if (event.getSource() == projectActivityBox) {
			sinceField.setEnabled(false);
			untilField.setEnabled(false);
			allSplitsBox.setEnabled(false);		
			titleString = projectActivityTitleString;
			preventOtherSelection();
		}
		else if (event.getSource() ==allSplitsBox) {
			if (allSplitsBox.isSelected()) {
				startProjectField.setEnabled(false);
				endProjectField.setEnabled(false);
				projectList.setEnabled(false);
			}
			else {
				startProjectField.setEnabled(true);
				endProjectField.setEnabled(true);
				projectList.setEnabled(true);
			}
		}
		else if (event.getSource() == btnSave) {			
			sinceField.setEnabled(false);
			untilField.setEnabled(false);
			emailField.setEnabled(false);
			since = sinceField.getText();
			until = untilField.getText();
			email = emailField.getText();
			
			if ( (contigBox.isSelected()) || freeReadsBox.isSelected()) {
				if ((since.equals(dateFormatString) )|| (until.equals(dateFormatString)) ) {
					reportError("Please enter valid dates for your report");
					sinceField.setEnabled(true);
					untilField.setEnabled(true);
				}
			}
			else if (email.equals(emailFormatString)){
				reportError("Please enter your login address that you use for email e.g. kt6");
				emailField.setEnabled(true);
			}
			else {
				// all these should become adb reports
				if (contigBox.isSelected() || freeReadsBox.isSelected()) {
					if (allSplitsBox.isSelected()) {
						query = query + " where statsdate >= '" +  since +
							"' and statsdate <= '" + until + "' order by statsdate";
					}
					else {
						query = query + " where statsdate >= '" +  since +
						"' and statsdate <= '" + until + "' and name = " + projectName + " order by statsdate";
					}
				}
				else if (contigTransferBox.isSelected()) {
					query = "select H.statsdate,H.name,total_contigs, H.total_contig_length,H.n50_contig_length" +
					" from PROJECT_CONTIG_HISTORY H left join PROJECT P using (project_id) where P.owner = '" + email +"'";
				}
				else if (projectActivityBox.isSelected()){
					query = "select date(CTR.opened) as opendate,P.name,count(*) as requests" +
					" from CONTIGTRANSFERREQUEST CTR left join PROJECT P on (CTR.new_project_id=P.project_id) " +
					" where CTR.requester= '" + email + "' and CTR.status='done' and CTR.requester=P.owner group by opendate,name";
					titleString = "open_date,name,contig_transfers";
				}
				preventOtherSelection();
				boolean doQuery = false;
				
				if (contigTransferBox.isSelected()) {
					doQuery = checkLoggedInUserCanRunUserReports();
				}
				else if (projectActivityBox.isSelected()) {
					doQuery = checkLoggedInUserCanRunUserReports();
				}
				else {
					doQuery = checkDates();
					if (!(doQuery)) {	
						sinceField.setEnabled(true);
						untilField.setEnabled(true);
					}
				}
				Arcturus.logInfo("Save button pressed: query holds: " + query + " and doQuery is " + doQuery);
				if (doQuery) {
					Connection conn;	
					try {
							conn = adb.getPooledConnection(this);
						
							stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
				              java.sql.ResultSet.CONCUR_READ_ONLY);		
							stmt.setFetchSize(Integer.MIN_VALUE);		
							
							ResultSet rs = stmt.executeQuery(query);
							saveStatsToFile(rs);
						} catch (ArcturusDatabaseException exception) {
							reportException("An error occurred when trying to find your report output from the Arcturus database", exception);
						} catch (SQLException exception) {
							reportException("An error occurred when trying to run the query to find your report output from the database", exception);
						} catch (Exception exception) {
							reportException("An error occurred when trying to save your report output", exception);
					}	
					resetAllButtons();
				}
			}
		}
		else {
				// Do nothing
		}	
		
	}
	
	protected void reportException( String message, Exception exception) {
		statusLine.setText(loggedInUser + ": " + message);
		Arcturus.logSevere(message, exception);
		resetAllButtons();
		exception.printStackTrace();
	}
	
	protected void reportError( String message) {
		statusLine.setText(loggedInUser + ": " + message);
		Arcturus.logInfo(message);
	}
	
	protected void startButtons() {
		contigBox.setEnabled(true);
		freeReadsBox.setEnabled(true);
		contigTransferBox.setEnabled(true);
		contigTransferBox.setEnabled(true);
		projectActivityBox.setEnabled(true);
		
		btnSave.setEnabled(true);
	}
	
	protected void preventOtherSelection() {
		contigBox.setEnabled(false);				
		freeReadsBox.setEnabled(false);
		contigTransferBox.setEnabled(false);
		contigTransferBox.setEnabled(false);
		projectActivityBox.setEnabled(false);
		
		btnSave.setEnabled(true);
	}
	
	protected void resetAllButtons() {
		contigBox.setEnabled(true);
		contigBox.setSelected(false);
		
		freeReadsBox.setEnabled(true);		
		freeReadsBox.setSelected(false);
		
		contigTransferBox.setEnabled(true);
		contigTransferBox.setSelected(false);
		
		contigTransferBox.setEnabled(true);
		contigTransferBox.setSelected(false);
		
		projectActivityBox.setEnabled(true);
		projectActivityBox.setSelected(false);
		
		allSplitsBox.setEnabled(true);
		allSplitsBox.setSelected(false);
		
		sinceField.setEnabled(true);
		untilField.setEnabled(true);
		emailField.setEnabled(true);
		
		btnSave.setEnabled(false);
		query = "";
		titleString = "";
	}
	
	protected boolean checkDates() {
		Calendar now = Calendar.getInstance();
		GregorianCalendar sinceCal = new GregorianCalendar();
		GregorianCalendar untilCal = new GregorianCalendar();
		int sinceYear = 0;
		int sinceMonth = 0;
		int sinceDay = 0;
		int untilYear = 0;
		int untilMonth = 0;
		int untilDay = 0;
		
		String[] sinceDateParts = since.split("-");
		String[] untilDateParts = until.split("-");
		
		// find a suitable check to avoid text strings
		
		if (sinceDateParts.length == 0) {
			reportError("Invalid date" + since);
			return false;
		}
		
		if (untilDateParts.length == 0) {
			reportError("Invalid date" + until);
			return false;
		}
	
		sinceYear = Integer.parseInt(sinceDateParts[0].trim());
		sinceMonth = Integer.parseInt(sinceDateParts[1].trim());
		sinceDay = Integer.parseInt(sinceDateParts[2].trim());
		sinceCal.set(sinceYear, sinceMonth, sinceDay);
	
		untilYear = Integer.parseInt(untilDateParts[0].trim());
		untilMonth = Integer.parseInt(untilDateParts[1].trim());
		untilDay = Integer.parseInt(untilDateParts[2].trim());
		untilCal.set(untilYear, untilMonth, untilDay);
		
		Arcturus.logInfo("Comparing since:" + sinceYear + "-" + sinceMonth + "-" + sinceDay + 
								  " to until:" + untilYear + "-" + untilMonth + "-" + untilDay);	
		
		boolean sinceDateValid = checkDate(now, sinceYear, sinceMonth, sinceDay);
		
		if (sinceDateValid) {
			boolean untilDateValid = checkDate(now, untilYear, untilMonth, untilDay);
			if (untilDateValid) {
				//if (sinceCal.before(untilCal)) {
					if (untilCal.before(sinceCal)) {
						reportError("Date " + since + " is not before date " + until);	
					return false;
				}
				else {
					return true;
				}
			}
			else {
				return false;
			}
		}
		else {
			return false;
		}
	
	}
	
	protected String printAsDate(int year, int month, int day){
		return(year + "-" + month + "-" + day);
	}
	
	protected boolean checkDate(Calendar now, int year, int month, int day) {
		boolean check = true;
		
		if (year < 2010) {
			reportError("We do not have statistics for " + year + ". ");
			return false;
		}
		if ((month > 12) || (month < 1)){
			reportError("Invalid month: " + month + ". ");
			return false;
		}
		if ((day > 31) || (day < 1)){
			reportError("Invalid day: " + day + ". ");
			return false;
		}	
		return check;
	}
	
	protected boolean checkLoggedInUserCanRunContigReports(){
		// For the contig stats, the owner can generate statistics for their own projects whilst the team leader, coordinator and administrator can see all projects.

		try {
			Set<Project> projects = adb.getProjectsForOwner(loggedInUser);
		
			Assembly[] assemblies = adb.getAllAssemblies();
			Assembly assembly;
			Project project = new Project();
			
			for (int i = 0; i < assemblies.length; i++) {
				assembly = assemblies[i];
				project = adb.getProjectByName(assembly, projectName);
			}
			
			if (projectName.equals(project.getName())) {
				return true;
			}
			else {
				if (adb.hasFullPrivileges(loggedInUser)){
					return true;
				}
				else {
					reportError("You do not have privileges to run this report for all data");	
					return false;
				}
			}
		} catch (ArcturusDatabaseException exception) {
			reportException("An error occurred when trying to check your priviliges in the Arcturus database", exception);
			return false;
		}
	}
	
	protected boolean checkLoggedInUserCanRunUserReports(){
		// For the user stats, anyone with team leader role can generate statistics for all users, whilst anyone else sees only their own.
		if (loggedInUser.toString().equals(email)) {
			return true;
		}
		else {
			Role loggedInUserRole = loggedInUser.getRole();
			String role = "role";
			if (role.equals("team leader")){
				return true;
			}
			else {
				reportError("You do not have privileges to run this report for all data");	
				return false;
			}
		}
	}
	
	
	protected void saveStatsToFile(ResultSet rs) throws SQLException {
		final JFileChooser fc = new JFileChooser();
		fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);

		int returnVal = fc.showSaveDialog(this);
		File file = fc.getSelectedFile();
		
		if (returnVal == JFileChooser.APPROVE_OPTION) {
			try {
				//Arcturus.logInfo("Saving: " + file.getName() + ".\n");
				
				BufferedWriter writer = new BufferedWriter(new FileWriter(file));
				ResultSetMetaData rsmd = rs.getMetaData();
				int cols = rsmd.getColumnCount();	

				//Arcturus.logInfo("There are " + cols +" columns in the data set");
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
				statusLine.setText("Your data has been saved to " + file.getName());
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
	protected void refreshList() {
		boolean allSelected = allSplitsBox.isSelected();
		
		setAllProjectsSelected(allSelected);
	}
	
	protected void setAllProjectsSelected(boolean allSelected) {
		if (allSelected) {
			int start = 0;
			int end = projectList.getModel().getSize() - 1;
			
			if (end >= 0) {
				projectList.setSelectionInterval(start, end);
				projectList.setEnabled(false);
			}
		} else {
			projectList.clearSelection();
			projectList.setEnabled(true);
		}

	}

	// Private methods
	
	private JPanel decoratePanel(JPanel panel, String caption) {
		Border border = BorderFactory.createTitledBorder(LOWERED_ETCHED_BORDER, caption);

		panel.setBorder(border);
		
		return panel;
	}
	
	private JPanel createButtonPanel() {
		JPanel buttonPanel = new JPanel(new FlowLayout());
		
        buttonPanel.add(contigBox);   
        buttonPanel.add(freeReadsBox);
        buttonPanel.add(contigTransferBox);
        buttonPanel.add(projectActivityBox);
       
        return decoratePanel(buttonPanel, "Step 1: Choose the kind of report to run");
	}
	
	private JPanel createTopPanel() {
		JPanel topPanel = new JPanel(new FlowLayout());
		
		topPanel.add(statusLine);
		statusLine.setText("Please choose the kind of report you want to run, then the dates and the projects to find");
        
		return decoratePanel(topPanel, "Messages");
	}

	
	private JPanel createDatePanel() {
		JPanel datePanel = new JPanel (new FlowLayout());
		
		datePanel.add(sinceField);
		datePanel.add(new Label(dateStartExplanationString)); 
		datePanel.add(untilField);
		datePanel.add(new Label(dateEndExplanationString));
		datePanel.add(emailField);
		datePanel.add(new Label(emailExplanationString));

        return decoratePanel(datePanel, "Step 2: Choose the start and end dates");
	}

	private JPanel createProjectPanel() {
		JPanel projectPanel = new JPanel (new FlowLayout());
		
		projectPanel.add(createProjectList());
		projectPanel.add(allSplitsBox);

        return decoratePanel(projectPanel, "Step 3: Choose the project");
	}
	
	private JPanel createSavePanel() {
		JPanel savePanel = new JPanel (new FlowLayout());
		savePanel.add(splitExplanation);
		savePanel.add(btnSave);
        return decoratePanel(savePanel, "Step 4: save the CSV file to the machine you are running Minerva on");
	}
	
	private JPanel createProjectList () {
		
		JPanel panel = new JPanel(new BorderLayout());

		plm.addListDataListener(new ListDataListener() {
			public void contentsChanged(ListDataEvent e) {
				refreshList();
			}
			public void intervalAdded(ListDataEvent e) {
				refreshList();
			}
			public void intervalRemoved(ListDataEvent e) {
				refreshList();
			}		
		});

		projectList = new JList(plm);
		projectList.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
		projectList.addListSelectionListener(new ListSelectionListener() {
			public void valueChanged(ListSelectionEvent e) {
				Object[] selectedProjects = projectList.getSelectedValues();
				for (int i = 0; i < selectedProjects.length; i++) {
					projectName = selectedProjects[i].toString();
					reportError("Looking for data for project " + projectName);
				}
			}
		});

		JScrollPane scrollpane = new JScrollPane(projectList);
		panel.add(scrollpane, BorderLayout.CENTER);
		return panel;
	}
}




