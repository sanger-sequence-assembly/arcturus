package uk.ac.sanger.arcturus.smithwaterman;

import java.io.*;
import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class TestSmithWaterman extends JFrame implements ActionListener {
	private JTextArea txtSequenceA = new JTextArea(10, 60);
	private JTextArea txtSequenceB = new JTextArea(10, 60);
	private JButton btnCalculate = new JButton("Calculate");
	private JTextField txtMatch = new JTextField("1", 4);
	private JTextField txtMismatch = new JTextField("-1", 4);
	private JTextField txtGapInit = new JTextField("-3", 4);
	private JTextField txtGapExt = new JTextField("-2", 4);
	private JCheckBox chkBanded = new JCheckBox("Banded");
	private JTextField txtBandwidth = new JTextField("10", 4);

	private SmithWatermanPanel swPanel = new SmithWatermanPanel();

	public TestSmithWaterman() {
		super("TestSmithWaterman");

		Font fixed = new Font("Monospaced", Font.PLAIN, 10);

		txtSequenceA.setFont(fixed);
		txtSequenceB.setFont(fixed);

		JScrollPane scrollA = new JScrollPane(txtSequenceA);
		scrollA.setBorder(BorderFactory.createCompoundBorder(BorderFactory
				.createTitledBorder("Sequence A"), BorderFactory
				.createEmptyBorder(5, 5, 5, 5)));

		JScrollPane scrollB = new JScrollPane(txtSequenceB);
		scrollB.setBorder(BorderFactory.createCompoundBorder(BorderFactory
				.createTitledBorder("Sequence B"), BorderFactory
				.createEmptyBorder(5, 5, 5, 5)));

		JPanel sequencePanel = new JPanel();

		sequencePanel.add(scrollA);
		sequencePanel.add(scrollB);

		JPanel scorePanel = new JPanel(new FlowLayout());

		scorePanel.add(new JLabel("Match:"));
		scorePanel.add(txtMatch);

		scorePanel.add(new JLabel(" Mismatch:"));
		scorePanel.add(txtMismatch);

		scorePanel.add(new JLabel(" GapInit:"));
		scorePanel.add(txtGapInit);

		scorePanel.add(new JLabel(" GapExt:"));
		scorePanel.add(txtGapExt);

		scorePanel.add(new JLabel("   "));
		scorePanel.add(chkBanded);

		scorePanel.add(new JLabel("   Bandwidth"));
		scorePanel.add(txtBandwidth);

		JPanel inputPanel = new JPanel(new BorderLayout());

		inputPanel.add(BorderLayout.CENTER, sequencePanel);
		inputPanel.add(BorderLayout.SOUTH, scorePanel);

		JPanel buttonPanel = new JPanel(new FlowLayout());

		buttonPanel.add(btnCalculate);

		JComponent contentPane = (JComponent) getContentPane();

		contentPane.setOpaque(true);

		contentPane.setLayout(new BorderLayout());

		contentPane.add(BorderLayout.NORTH, inputPanel);
		contentPane.add(BorderLayout.CENTER, swPanel);
		contentPane.add(BorderLayout.SOUTH, buttonPanel);

		btnCalculate.addActionListener(this);
		
		chkBanded.addItemListener(new ItemListener() {
			public void itemStateChanged(ItemEvent e) {
				txtBandwidth.setEnabled(chkBanded.isSelected());
			}	
		});
		
		chkBanded.setSelected(true);
		txtBandwidth.setEnabled(true);

		setSize(980, 760);
	}

	public void actionPerformed(ActionEvent ae) {
		try {
			int sMatch = Integer.parseInt(txtMatch.getText());
			int sMismatch = Integer.parseInt(txtMismatch.getText());
			int sGapInit = Integer.parseInt(txtGapInit.getText());
			int sGapExt = Integer.parseInt(txtGapExt.getText());

			boolean banded = chkBanded.isSelected();
			int bandwidth = banded ? Integer.parseInt(txtBandwidth.getText()) : 0;

			String sequenceA = txtSequenceA.getText().replaceAll("\n", "");
			String sequenceB = txtSequenceB.getText().replaceAll("\n", "");

			swPanel.display(sequenceA, sequenceB, sMatch, sMismatch, sGapInit,
					sGapExt, banded, bandwidth);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public void loadSequenceAFromFile(String filename) {
		loadFromFile(filename, txtSequenceA);
	}

	public void loadSequenceBFromFile(String filename) {
		loadFromFile(filename, txtSequenceB);
	}

	private void loadFromFile(String filename, JTextArea textarea) {
		try {
			BufferedReader br = new BufferedReader(new FileReader(filename));

			boolean headerseen = false;

			StringBuffer sb = new StringBuffer();

			String line = null;

			while ((line = br.readLine()) != null) {
				if (line.startsWith(">")) {
					if (headerseen)
						break;

					headerseen = true;
				} else {
					sb.append(line);
					sb.append('\n');
				}
			}

			br.close();

			textarea.setText(sb.toString());
		} catch (IOException ioe) {
			ioe.printStackTrace();
		}
	}

	public static void main(String args[]) {
		TestSmithWaterman frame = new TestSmithWaterman();

		if (args.length > 0)
			frame.loadSequenceAFromFile(args[0]);

		if (args.length > 1)
			frame.loadSequenceBFromFile(args[1]);

		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

		frame.setVisible(true);
	}
}
