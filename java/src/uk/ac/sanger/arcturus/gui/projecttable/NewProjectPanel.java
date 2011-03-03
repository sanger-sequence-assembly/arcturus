package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import javax.swing.border.Border;
import javax.swing.border.EtchedBorder;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;

import java.awt.*;
import java.awt.event.HierarchyEvent;
import java.awt.event.HierarchyListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;

import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.repository.Repository;
import uk.ac.sanger.arcturus.repository.RepositoryException;
import uk.ac.sanger.arcturus.repository.RepositoryManager;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.gui.common.InputDialog;

public class NewProjectPanel extends JPanel {
	private static final String ENTER_A_VALID_NAME = "You must enter a valid project name";
	private static final String NAME_IS_IN_USE = "That project name is already in use in the selected assembly";

	private Border loweredetched = BorderFactory
	.createEtchedBorder(EtchedBorder.LOWERED);
	
	private JTextField txtName = new JTextField(25);
	
	private JLabel lblMessage = new JLabel(ENTER_A_VALID_NAME);
	
	private JComboBox cbxOwner = new JComboBox();
	private JComboBox cbxAssembly = new JComboBox();
	
	private JRadioButton btnRelativeToAssembly = new JRadioButton("Relative to assembly repository");
	private JRadioButton btnRelativeToProject = new JRadioButton("Relative to project repository");
	private JRadioButton btnAbsolutePath = new JRadioButton("Absolute path");
	
	private JTextField txtAssemblyPrefix = new JTextField(30);
	private JTextField txtAssemblySuffix = new JTextField(20);
	private boolean autocompleteAssemblySuffix;
	
	private JTextField txtProjectPrefix = new JTextField(30);
	private JTextField txtProjectSuffix = new JTextField(20);
	
	private JTextField txtAbsolutePath = new JTextField(40);
	
	private Assembly selectedAssembly;
	
	private Container ancestor;
	
	private ArcturusDatabase adb;
	
	private RepositoryManager rm = Arcturus.getRepositoryManager();
	
	public NewProjectPanel(ArcturusDatabase adb) {
		super(null);
		
		this.adb = adb;
		
		int vfill = 5;

		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));

		add(createBasicInformationPanel());

		add(Box.createVerticalStrut(vfill));
		
		add(createDirectoryPanel());

		createActions();
	}
	
	private void createActions() {		
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
				validateNameField();
			}

			public void removeUpdate(DocumentEvent e) {
				validateNameField();
			}
		});
		
		cbxAssembly.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				if (e.getStateChange() == ItemEvent.SELECTED) {
					selectedAssembly = (Assembly)e.getItem();
					validateAssembly();
				}
			}			
		});
		
		txtAssemblySuffix.addKeyListener(new KeyAdapter() {
			public void keyTyped(KeyEvent e) {
				autocompleteAssemblySuffix = false;
			}
		});
	}
	
	private JPanel createBasicInformationPanel() {
		JPanel panel = new JPanel(new GridBagLayout());
		
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
		
		panel.add(new JLabel("Name:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
		
		panel.add(txtName, c);
		
		// Add message label and text field
		
		c.gridy++;
				
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		panel.add(new JLabel(""), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
				
		panel.add(lblMessage, c);

		lblMessage.setForeground(Color.red);
		
		// Add assembly label and combo box
		
		c.gridy++;
				
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		panel.add(new JLabel("Assembly:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
				
		panel.add(cbxAssembly, c);

		// Add owner label and combo box
		
		c.gridy++;
		
		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		panel.add(new JLabel("Owner:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.weightx = 1.0;
				
		panel.add(cbxOwner, c);

		Border border = BorderFactory.createTitledBorder(loweredetched,
				"Basic project information");

		panel.setBorder(border);
	
		return panel;
	}
	
	private JPanel createDirectoryPanel() {
		JPanel panel = new JPanel(new GridBagLayout());
		
		GridBagConstraints c = new GridBagConstraints();

		c.insets = new Insets(2, 2, 2, 2);
		
		c.gridy = 0;
		
		// Relative to assembly
		
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.anchor = GridBagConstraints.WEST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		panel.add(btnRelativeToAssembly, c);
		
		c.gridy++;

		c.gridwidth = 1;
		
		panel.add(txtAssemblyPrefix, c);
		
		txtAssemblyPrefix.setEditable(false);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 1.0;
		
		panel.add(txtAssemblySuffix, c);
		
		c.gridy++;
		
		// Relative to project
				
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.anchor = GridBagConstraints.WEST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		panel.add(btnRelativeToProject, c);
		
		c.gridy++;

		c.gridwidth = 1;
		
		panel.add(txtProjectPrefix, c);
		
		txtProjectPrefix.setEditable(false);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 1.0;
		
		panel.add(txtProjectSuffix, c);
		
		c.gridy++;
	
		// Absolute path
				
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.anchor = GridBagConstraints.WEST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		
		panel.add(btnAbsolutePath, c);
		
		c.gridy++;

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 1.0;
		
		panel.add(txtAbsolutePath, c);
		
		// Create the button group for the radio buttons 
		
		ButtonGroup group = new ButtonGroup();
		
		group.add(btnRelativeToAssembly);
		group.add(btnRelativeToProject);
		group.add(btnAbsolutePath);
		
		// Add border
				
		Border border = BorderFactory.createTitledBorder(loweredetched,
			"Project directory");

		panel.setBorder(border);

		return panel;
	}

	private void validateNameField() {
		String text = txtName.getText();
		
		boolean empty = text == null || text.length() == 0;
		
		boolean nameInUse = isProjectNameInUse(text);
		
		if (empty)
			lblMessage.setText(ENTER_A_VALID_NAME);
		else if (nameInUse)
			lblMessage.setText(NAME_IS_IN_USE);
		else
			lblMessage.setText(" ");

		if (ancestor instanceof InputDialog)		
			((InputDialog)ancestor).setOKActionEnabled(! (empty || nameInUse));
		
		try {
			Repository repo = empty ? null : rm.getRepository(text);
			
			if (repo != null) {
				btnRelativeToProject.setEnabled(true);
				btnRelativeToProject.setSelected(true);
				txtProjectSuffix.setEnabled(true);
				txtProjectPrefix.setText(repo.getPath());
			} else {
				btnRelativeToProject.setEnabled(false);
				txtProjectSuffix.setEnabled(false);
				txtProjectPrefix.setText("");
				
				if (btnRelativeToProject.isSelected())
					setDefaultDirectoryButton();			
			}
		} catch (RepositoryException e) {
			Arcturus.logWarning("An error occurred during a repository lookup on \"" + text + "\"", e);
		}
		
	
		if (autocompleteAssemblySuffix) {
				txtAssemblySuffix.setText(this.getAssemblySuffix() + text);
		}
	}
	
	private void validateAssembly() {
		validateNameField();
		
		String name = selectedAssembly.getName();
		
		try {
			Repository repo = rm.getRepository(name);
			
			if (repo != null) {
				btnRelativeToAssembly.setEnabled(true);
				txtAssemblySuffix.setEnabled(true);
				txtAssemblyPrefix.setText(repo.getPath());
			} else {
				btnRelativeToAssembly.setEnabled(false);
				txtAssemblySuffix.setEnabled(false);
				txtAssemblyPrefix.setText("");
				
				if (btnRelativeToAssembly.isSelected())
					setDefaultDirectoryButton();			
			}
		} catch (RepositoryException e) {
			Arcturus.logWarning("An error occurred during a repository lookup on \"" + name + "\"", e);
		}
	}
	
	private boolean isProjectNameInUse(String name) {
		if (name == null || name.length() == 0)
			return false;
		
		try {
			Project p = adb.getProjectByName(selectedAssembly, name);
			
			return p != null;
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to fetch project by name", e);
		}
		
		return false;
	}
	
	public String getName() {
		return txtName.getText();
	}
	
	public void setName(String name) {
		txtName.setText(name);
	}
	
	public Person getOwner() {
		return (Person)cbxOwner.getSelectedItem();
	}
	
	public Assembly getAssembly() {
		return (Assembly)cbxAssembly.getSelectedItem();
	}
	
	public String getDirectory() {
		if (btnRelativeToAssembly.isSelected()) {
			String suffix = txtAssemblySuffix.getText();
			return ":ASSEMBLY:" + (suffix.startsWith("/") ? "" : "/") + suffix;
		} else if (btnRelativeToProject.isSelected()) {
			String suffix = txtProjectSuffix.getText();
			return ":PROJECT:" + (suffix.startsWith("/") ? "" : "/") + suffix;
		} else if (btnAbsolutePath.isSelected())
			return txtAbsolutePath.getText();
		else
			return null;
	}
	
	public void refresh() {
		txtName.setText("");
		txtAbsolutePath.setText("");
		
		updateUserList();
		updateAssemblyList();
		
		validateAssembly();
		
		setDefaultDirectoryButton();
		
		if (btnRelativeToAssembly.isEnabled()) {
			
			txtAssemblySuffix.setText(getAssemblySuffix());
			autocompleteAssemblySuffix = true;
		}
		
		if (btnRelativeToProject.isEnabled()) {
			txtProjectSuffix.setText("/");
		}
	}
	
	private void setDefaultDirectoryButton() {
		if (btnRelativeToAssembly.isEnabled())
			btnRelativeToAssembly.setSelected(true);
		else if (btnRelativeToProject.isEnabled())
			btnRelativeToProject.setSelected(true);
		else if (btnAbsolutePath.isEnabled())
			btnAbsolutePath.setSelected(true);
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
	
	private String getAssemblySuffix() {
		
		// make the default pathname dependent on the organism being used to avoid overwriting live data
		String organism = adb.getName();
		//txtAbsolutePath.setText("organism is " + organism);
		
		if (organism.startsWith("TEST")) {
			return("/test/");
		}
		else if (organism.startsWith("TRAIN")) {
			return("/training/");
		}
		else {
			return("/split/");
		}
	}
}
