package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import java.awt.*;

public class OrganismChooserPanel extends JPanel {
	protected JTextField instance = null;
	protected JTextField organism = null;

	public OrganismChooserPanel() {
		super(new GridBagLayout());
		GridBagConstraints c = new GridBagConstraints();

		c.insets = new Insets(2, 2, 2, 2);

		c.anchor = GridBagConstraints.WEST;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 0.0;

		add(new JLabel("Please specify the instance and organism"), c);

		c.gridwidth = 1;
		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.NONE;
		c.weightx = 0.0;
		add(new JLabel("Instance:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 1.0;
		instance = new JTextField("pathogen", 20);
		add(instance, c);

		c.gridwidth = 1;
		c.fill = GridBagConstraints.NONE;
		c.anchor = GridBagConstraints.EAST;
		c.weightx = 0.0;

		add(new JLabel("Organism:"), c);

		c.anchor = GridBagConstraints.EAST;
		c.fill = GridBagConstraints.HORIZONTAL;
		c.gridwidth = GridBagConstraints.REMAINDER;
		c.weightx = 1.0;
		organism = new JTextField("", 20);
		add(organism, c);
	}
	
	public void setInstance(String name) {
		instance.setText(name);
	}

	public String getInstance() {
		return instance.getText();
	}
	
	public void setOrganism(String name) {
		organism.setText(name);
	}

	public String getOrganism() {
		return organism.getText();
	}
	
	public int showDialog(Component parent) {
		return JOptionPane.showConfirmDialog(parent, this,
				"Specify instance and organism",
				JOptionPane.OK_CANCEL_OPTION, JOptionPane.QUESTION_MESSAGE);
	}
}
