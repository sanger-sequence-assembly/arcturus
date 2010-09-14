package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;

import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.HierarchyEvent;
import java.awt.event.HierarchyListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.io.File;

import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.gui.common.InputDialog;

public class NewProjectPanel extends JPanel {
	private static final String ENTER_A_VALID_NAME = "You must enter a valid project name";
	private static final String NAME_IS_IN_USER = "That project name is already in use in the selected assembly";
	
	private JTextField txtName = new JTextField(25);
	private JLabel lblMessage = new JLabel(ENTER_A_VALID_NAME);
	private JComboBox cbxDirectory = new JComboBox();
	private JComboBox cbxOwner = new JComboBox();
	private JComboBox cbxAssembly = new JComboBox();
	private JButton btnBrowse = new JButton("Browse...");
	
	private Assembly selectedAssembly;
	
	private Container ancestor;
	
	private ArcturusDatabase adb;
	
	public NewProjectPanel(ArcturusDatabase adb) {
		super(new GridBagLayout());
		this.adb = adb;
		
		GridBagConstraints c = new GridBagConstraints();

		c.insets = new Insets(2, 2, 2, 2);
		
		c.gridy = 0;

		c.anchor = GridBagConstraints.WEST;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 0.0;

		// Add name label and text field
		
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		add(new JLabel("Name:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
		
		add(txtName, c);
		
		// Add message label and text field
		
		c.gridy++;
				
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		add(new JLabel(""), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
				
		add(lblMessage, c);

		lblMessage.setForeground(Color.red);
		
		// Add assembly label and combo box
		
		c.gridy++;
				
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		add(new JLabel("Assembly:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
				
		add(cbxAssembly, c);

		// Add directory label and combo box
		
		c.gridy++;
		
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		add(new JLabel("Directory:"), c);

		c.gridwidth = 2;
		
		add(cbxDirectory, c);
		
		cbxDirectory.setEditable(true);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.gridwidth = 1;
		c.weightx = 1.0;
		
		add(btnBrowse, c);
		
		btnBrowse.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				browseWorkDir();
			}			
		});
		
		// Disable the directory browser unless we are running on Linux
		btnBrowse.setEnabled(Arcturus.isLinux());

		// Add owner label and combo box
		
		c.gridy++;
		
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		add(new JLabel("Owner:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
				
		add(cbxOwner, c);
		
		addHierarchyListener(new HierarchyListener() {
			public void hierarchyChanged(HierarchyEvent e) {
				ancestor = getTopLevelAncestor();
			}
		});
		
		txtName.getDocument().addDocumentListener(new DocumentListener() {
			public void changedUpdate(DocumentEvent e) {
				// Do nothing
			}

			public void insertUpdate(DocumentEvent e) {
				verifyNameField();
			}

			public void removeUpdate(DocumentEvent e) {
				verifyNameField();
			}
		});
		
		cbxAssembly.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				if (e.getStateChange() == ItemEvent.SELECTED) {
					selectedAssembly = (Assembly)e.getItem();
					verifyNameField();
				}
			}			
		});
	}

	private void verifyNameField() {
		String text = txtName.getText();
		
		boolean empty = text == null || text.length() == 0;
		
		boolean nameInUse = false;
		
		if (!empty) {			
			try {
				Project p = adb.getProjectByName(selectedAssembly, text);
				
				nameInUse = p != null;
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to fetch project by name", e);
			}		
		}
		
		if (empty)
			lblMessage.setText(ENTER_A_VALID_NAME);
		else if (nameInUse)
			lblMessage.setText(NAME_IS_IN_USER);
		else
			lblMessage.setText(" ");

		if (ancestor instanceof InputDialog)		
			((InputDialog)ancestor).setOKActionEnabled(! (empty || nameInUse));
	}
	
	protected void browseWorkDir() {
		File workdir = new File((String)cbxDirectory.getSelectedItem());
		
		JFileChooser chooser = new JFileChooser();
		
		if (workdir.isDirectory())
			chooser.setCurrentDirectory(workdir);
		
		chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		
		int rc = chooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			workdir = chooser.getSelectedFile();
			cbxDirectory.setSelectedItem(workdir.getPath());
		}
	}
	
	public String getName() {
		return txtName.getText();
	}
	
	public void setName(String name) {
		txtName.setText(name);
	}
	
	public String getDirectory() {
		return ((String)cbxDirectory.getSelectedItem()).trim();
	}
	
	public void setDirectory(String directory) {
		cbxDirectory.setSelectedItem(directory);
	}
	
	public Person getOwner() {
		return (Person)cbxOwner.getSelectedItem();
	}
	
	public Assembly getAssembly() {
		return (Assembly)cbxAssembly.getSelectedItem();
	}
	
	public void refresh() {
		updateUserList();
		updateAssemblyList();
		updateDirectoryList();
	}
	
	private void updateDirectoryList() {
		String[] dirs = null;
		
		try {
			dirs = adb.getAllDirectories();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logSevere("An error occurred whilst enumerating directories", e);
		}
		
		if (dirs != null) {
			cbxDirectory.removeAllItems();

			for (String dir : dirs)
				cbxDirectory.addItem(dir);

			cbxDirectory.setSelectedIndex(0);
		}
	}
	
	private void updateUserList() {
		try {
			Person[] users = adb.getAllUsers();
			
			cbxOwner.removeAllItems();
			
			for (int i = 0; i < users.length; i++)
				cbxOwner.addItem(users[i]);
			
			cbxOwner.setSelectedItem(adb.findMe());
		} catch (ArcturusDatabaseException e) {
			Arcturus.logSevere("An error occurred whilst enumerating users", e);
		}
	}
	
	private void updateAssemblyList() {
		try {
			Assembly[] assemblies = adb.getAllAssemblies();
			
			cbxAssembly.removeAllItems();
			
			for (int i = 0; i < assemblies.length; i++)
				cbxAssembly.addItem(assemblies[i]);
			
			cbxAssembly.setEnabled(cbxAssembly.getItemCount() > 1);
		} catch (ArcturusDatabaseException e) {
			Arcturus.logSevere("An error occurred whilst enumerating assemblies", e);
		}
	}
}
