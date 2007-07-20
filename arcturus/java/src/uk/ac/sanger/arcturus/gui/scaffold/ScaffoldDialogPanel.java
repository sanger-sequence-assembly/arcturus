package uk.ac.sanger.arcturus.gui.scaffold;

import javax.swing.*;
import javax.swing.border.*;
import java.awt.GridLayout;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;

public class ScaffoldDialogPanel extends JPanel {
	private Border loweredetched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);	

	private JRadioButton btnExplicitList = new JRadioButton("Explicit list");
	private JRadioButton btnAllFromProject = new JRadioButton("All from project");
	private JTextField txtContigIDList = new JTextField(20);
	String[] projects = {"BIN", "PKN1", "PKN2", "PKN3", "PKN4" };
	private JComboBox cbxProjectList = new JComboBox(projects);
	
	private JRadioButton btnIncludeFromSeedProject = new JRadioButton("From seed project only");
	private JRadioButton btnIncludeFromSeedProjectAndBin  = new JRadioButton("From seed project and BIN");
	private JRadioButton btnIncludeFromAll = new JRadioButton("From all projects");
		
	public ScaffoldDialogPanel() {
		super(null);
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));
		
		add(createContigSelectionPanel());
		
		add(createIncludeContigsPanel());
		
		//add(createLengthCriterionPanel());
		
		//add(createSubCloneCriterionPanel());
		
		//add(createBridgeCriterionPanel());
	}
	
	private JPanel createContigSelectionPanel() {
		JPanel panel = new JPanel(new GridLayout(2,2));
		
		ButtonGroup group = new ButtonGroup();
		group.add(btnExplicitList);
		group.add(btnAllFromProject);
		
		panel.add(btnExplicitList);
		panel.add(txtContigIDList);
		
		txtContigIDList.setEnabled(false);
		
		panel.add(btnAllFromProject);
		panel.add(cbxProjectList);
		
		cbxProjectList.setEnabled(false);
		
		btnExplicitList.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				boolean selected = e.getStateChange() == ItemEvent.SELECTED;
					
				txtContigIDList.setEnabled(selected);
				cbxProjectList.setEnabled(!selected);
			}			
		});
				
		btnAllFromProject.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				boolean selected = e.getStateChange() == ItemEvent.SELECTED;
					
				txtContigIDList.setEnabled(!selected);
				cbxProjectList.setEnabled(selected);
			}			
		});
		
		btnExplicitList.setSelected(true);
		
		Border border = BorderFactory.createTitledBorder(
			       loweredetched, "Which seed contigs?");
		
		panel.setBorder(border);
		
		return panel;
	}
	
	private JPanel createIncludeContigsPanel() {
		JPanel panel = new JPanel(new GridLayout(0,1));

		ButtonGroup group = new ButtonGroup();
		group.add(btnIncludeFromSeedProject);
		group.add(btnIncludeFromSeedProjectAndBin);
		group.add(btnIncludeFromAll);
	
		panel.add(btnIncludeFromSeedProject);
		panel.add(btnIncludeFromSeedProjectAndBin);
		panel.add(btnIncludeFromAll);
		
		btnIncludeFromSeedProject.setSelected(true);
		
		Border border = BorderFactory.createTitledBorder(
			       loweredetched, "Which contigs to include?");
		
		panel.setBorder(border);
		
		return panel;
	}

	public static void main(String[] args) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				showUI();
			}
		});
	}

	private static void showUI() {
		ScaffoldDialogPanel panel = new ScaffoldDialogPanel();
		
		JFrame frame = new JFrame("Scaffolding options");
		
		frame.getContentPane().add(panel);
		
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		
		frame.pack();
		
		frame.setVisible(true);
	}
}
