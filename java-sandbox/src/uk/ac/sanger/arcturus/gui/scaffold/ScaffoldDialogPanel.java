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
	
	private JRadioButton btnIncludeFromSeedProject = new JRadioButton("Seed project only");
	private JRadioButton btnIncludeFromSeedProjectAndBin  = new JRadioButton("Seed project and BIN");
	private JRadioButton btnIncludeFromAll = new JRadioButton("All projects");
	
	private JRadioButton btnAnyLength = new JRadioButton("Any length");
	private JRadioButton btnAtLeast2kb = new JRadioButton("At least 2kb");
	private JRadioButton btnAtLeast5kb = new JRadioButton("At least 5kb");
	
	private JRadioButton btnAnyNumber = new JRadioButton("Any number");
	private JRadioButton btnAtLeast2 = new JRadioButton("At least 2");
	
	private JRadioButton btnOnlyBestBridge = new JRadioButton("Only the best bridge");
	private JRadioButton btnBestTwoBridges = new JRadioButton("The best two bridges");
	private JRadioButton btnAllBridges = new JRadioButton("All bridges");
		
	public ScaffoldDialogPanel() {
		super(null);
		
		int vfill = 5;
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));
		
		add(createContigSelectionPanel());
		
		add(Box.createVerticalStrut(vfill));
		
		add(createIncludeProjectsPanel());
		
		add(Box.createVerticalStrut(vfill));
	
		add(createLengthCriterionPanel());
		
		add(Box.createVerticalStrut(vfill));
	
		add(createSubCloneCriterionPanel());
		
		add(Box.createVerticalStrut(vfill));
	
		add(createBridgeCriterionPanel());
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
	
	private JPanel createIncludeProjectsPanel() {
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
			       loweredetched, "Which projects to include?");
		
		panel.setBorder(border);
		
		return panel;
	}
	
	private JPanel createLengthCriterionPanel() {
		JPanel panel = new JPanel(new GridLayout(0,1));

		ButtonGroup group = new ButtonGroup();
		group.add(btnAnyLength);
		group.add(btnAtLeast2kb);
		group.add(btnAtLeast5kb);
		
		panel.add(btnAnyLength);
		panel.add(btnAtLeast2kb);
		panel.add(btnAtLeast5kb);
		
		btnAtLeast2kb.setSelected(true);
		
		Border border = BorderFactory.createTitledBorder(
			       loweredetched, "Minimum length for contigs to include?");
		
		panel.setBorder(border);
		
		return panel;
	}

	private JPanel createSubCloneCriterionPanel() {
		JPanel panel = new JPanel(new GridLayout(0,1));

		ButtonGroup group = new ButtonGroup();
		group.add(btnAnyNumber);
		group.add(btnAtLeast2);
		
		panel.add(btnAnyNumber);
		panel.add(btnAtLeast2);
	
		btnAtLeast2.setSelected(true);
		
		Border border = BorderFactory.createTitledBorder(
			       loweredetched, "How many sub-clones to validate a bridge?");
		
		panel.setBorder(border);
		
		return panel;
	}
	
	private JPanel createBridgeCriterionPanel() {
		JPanel panel = new JPanel(new GridLayout(0,1));

		ButtonGroup group = new ButtonGroup();
		group.add(btnOnlyBestBridge);
		group.add(btnBestTwoBridges);
		group.add(btnAllBridges);
		
		panel.add(btnOnlyBestBridge);
		panel.add(btnBestTwoBridges);
		panel.add(btnAllBridges);
		
		btnBestTwoBridges.setSelected(true);
		
		Border border = BorderFactory.createTitledBorder(
			       loweredetched, "Which bridges to include?");
		
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
		
		frame.setResizable(false);
		
		frame.setVisible(true);
	}
}
