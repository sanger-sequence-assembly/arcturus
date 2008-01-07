package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.io.IOException;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.Arcturus;

public class NewProjectPanel extends JPanel {
	private JTextField txtName = new JTextField(25);
	private JTextField txtDirectory = new JTextField(40);
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
		
		add(txtDirectory, c);

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
		File workdir = new File(txtDirectory.getText());
		
		JFileChooser chooser = new JFileChooser();
		
		if (workdir.isDirectory())
			chooser.setCurrentDirectory(workdir);
		
		chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		
		int rc = chooser.showOpenDialog(this);

		if (rc == JFileChooser.APPROVE_OPTION) {
			workdir = chooser.getSelectedFile();
			txtDirectory.setText(workdir.getPath());
		}
	}
	
	public String getName() {
		return txtName.getText();
	}
	
	public void setName(String name) {
		txtName.setText(name);
	}
	
	public String getDirectory() {
		return txtDirectory.getText();
	}
	
	public void setDirectory(String directory) {
		txtDirectory.setText(directory);
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
		
		String dirname = adb.getDefaultDirectory();
		
		if (dirname == null)
			dirname = System.getProperty("user.dir");
		
		txtDirectory.setText(dirname);
	}
	
	private void updateUserList() {
		try {
			Person[] users = adb.getAllUsers();
			
			cbxOwner.removeAllItems();
			
			for (int i = 0; i < users.length; i++)
				cbxOwner.addItem(users[i]);
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
