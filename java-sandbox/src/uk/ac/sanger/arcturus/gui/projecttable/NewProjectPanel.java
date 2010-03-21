package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.Arcturus;

public class NewProjectPanel extends JPanel {
	private JTextField txtName = new JTextField(25);
	private JComboBox cbxDirectory = new JComboBox();
	private JComboBox cbxOwner = new JComboBox();
	private JComboBox cbxAssembly = new JComboBox();
	private JButton btnBrowse = new JButton("Browse...");
	
	private ArcturusDatabase adb;
	private JComponent parent;
	
	public NewProjectPanel(JComponent parent, ArcturusDatabase adb) {
		super(new GridBagLayout());
		
		this.parent = parent;
		this.adb = adb;
		
		GridBagConstraints c = new GridBagConstraints();

		c.insets = new Insets(2, 2, 2, 2);
		
		c.gridy = 0;

		c.anchor = GridBagConstraints.WEST;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 0.0;

		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		add(new JLabel("Name:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
		
		add(txtName, c);
		
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
	
	public int display() {
		refresh();
		
		return JOptionPane.showConfirmDialog(parent, this, "Create a new project",
				JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
	}
	
	private void refresh() {
		updateUserList();
		updateAssemblyList();
		updateDirectoryList();
	}
	
	private void updateDirectoryList() {
		String[] dirs = adb.getAllDirectories();
		
		cbxDirectory.removeAllItems();
		
		for (String dir : dirs)
			cbxDirectory.addItem(dir);
		
		cbxDirectory.setSelectedIndex(0);
	}
	
	private void updateUserList() {
		try {
			Person[] users = adb.getAllUsers();
			
			cbxOwner.removeAllItems();
			
			for (int i = 0; i < users.length; i++)
				cbxOwner.addItem(users[i]);
			
			cbxOwner.setSelectedItem(adb.findMe());
		} catch (SQLException e) {
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
		} catch (SQLException e) {
			Arcturus.logSevere("An error occurred whilst enumerating assemblies", e);
		}
	}
}
