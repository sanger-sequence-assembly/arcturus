package uk.ac.sanger.arcturus.test;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class TestSmithWaterman2 extends JFrame implements ActionListener {
    private JTextArea txtSequenceA = new JTextArea(10, 60);
    private JTextArea txtSequenceB = new JTextArea(10, 60);
    private JButton btnCalculate = new JButton("Calculate");
    private JTextField txtMatch = new JTextField("1", 4);
    private JTextField txtMismatch = new JTextField("-1", 4);
    private JTextField txtGapInit = new JTextField("-3", 4);
    private JTextField txtGapExt = new JTextField("-2", 4);

    private SmithWatermanPanel swPanel = new SmithWatermanPanel();

    public TestSmithWaterman2() {
	super("TestSmithWaterman");

	Font fixed = new Font("Monospaced", Font.PLAIN, 10);

	txtSequenceA.setFont(fixed);
	txtSequenceB.setFont(fixed);

	JScrollPane scrollA = new JScrollPane(txtSequenceA);
	scrollA.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createTitledBorder("Sequence A"),
							     BorderFactory.createEmptyBorder(5,5,5,5)));

	JScrollPane scrollB = new JScrollPane(txtSequenceB);
	scrollB.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createTitledBorder("Sequence B"),
							     BorderFactory.createEmptyBorder(5,5,5,5)));

	JPanel sequencePanel = new JPanel();
	BoxLayout boxlayout = new BoxLayout(sequencePanel, BoxLayout.X_AXIS);

	sequencePanel.add(scrollA);
	sequencePanel.add(scrollB);

	JPanel scorePanel = new JPanel(new FlowLayout());

	scorePanel.add(new JLabel("Match:"));
	scorePanel.add(txtMatch);

	scorePanel.add(new JLabel("   Mismatch:"));
	scorePanel.add(txtMismatch);

	scorePanel.add(new JLabel("   GapInit:"));
	scorePanel.add(txtGapInit);

	scorePanel.add(new JLabel("   GapExt:"));
	scorePanel.add(txtGapExt);

	JPanel inputPanel = new JPanel(new BorderLayout());

	inputPanel.add(BorderLayout.CENTER, sequencePanel);
	inputPanel.add(BorderLayout.SOUTH, scorePanel);

	JPanel buttonPanel = new JPanel(new FlowLayout());

	buttonPanel.add(btnCalculate);

	JComponent contentPane = (JComponent)getContentPane();

	contentPane.setOpaque(true);

	contentPane.setLayout(new BorderLayout());

	contentPane.add(BorderLayout.NORTH, inputPanel);
	contentPane.add(BorderLayout.CENTER, swPanel);
	contentPane.add(BorderLayout.SOUTH, buttonPanel);

	btnCalculate.addActionListener(this);

	setSize(980, 760);
    }

    public void actionPerformed(ActionEvent ae) {
	try {
	    int sMatch = Integer.parseInt(txtMatch.getText());
	    int sMismatch = Integer.parseInt(txtMismatch.getText());
	    int sGapInit = Integer.parseInt(txtGapInit.getText());
	    int sGapExt = Integer.parseInt(txtGapExt.getText());

	    String sequenceA = txtSequenceA.getText().replaceAll("\n","");
	    String sequenceB = txtSequenceB.getText().replaceAll("\n","");

	    swPanel.display(sequenceA, sequenceB, sMatch, sMismatch, sGapInit, sGapExt);
	}
	catch (Exception e) {
	    e.printStackTrace();
	}
    }

    public static void main(String args[]) {
	TestSmithWaterman2 frame = new TestSmithWaterman2();

	frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

	frame.setVisible(true);
    }
}
