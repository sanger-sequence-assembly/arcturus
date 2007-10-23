package uk.ac.sanger.arcturus.jobrunner;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.FlowLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import javax.swing.*;
import javax.swing.text.*;
import javax.swing.border.Border;
import javax.swing.border.EtchedBorder;

public class StyledJobRunnerFrame extends JFrame implements JobRunnerClient {
	protected JLabel lblStatus = new JLabel("Not yet started");
	protected JProgressBar pbar = new JProgressBar();

	protected JobRunner runner;
	
	protected JobRunnerStyledDocument document = new JobRunnerStyledDocument();

	protected JTextPane textpane = new JTextPane(document);
	
	protected JButton btnClose = new JButton("Close");
	
	public StyledJobRunnerFrame(String hostname, String workingDirectory,
			String command) {
		super(command);
		
		JPanel mainpanel = new JPanel(new BorderLayout());

		runner = new JobRunner(hostname, workingDirectory, command, this);
		
		JScrollPane scrollpane = new JScrollPane(textpane);
		
		mainpanel.add(scrollpane, BorderLayout.CENTER);
		
		JPanel bottompanel = new JPanel(new BorderLayout());
		
		bottompanel.add(lblStatus, BorderLayout.WEST);
		bottompanel.add(pbar, BorderLayout.EAST);
		
		JPanel buttonpanel = new JPanel(new FlowLayout());
		buttonpanel.add(btnClose);
		
		bottompanel.add(buttonpanel, BorderLayout.CENTER);
		
		btnClose.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				closeParentFrame();
			}			
		});
		
		pbar.setMinimum(0);
		pbar.setMaximum(100);

		mainpanel.add(bottompanel, BorderLayout.SOUTH);
		
		getContentPane().add(mainpanel);
		
		pack();
	}

	protected Border etchedTitledBorder(String title) {
		Border etched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		return BorderFactory.createTitledBorder(etched, title);
	}

	public void run() {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				lblStatus.setText("Started...");
				pbar.setIndeterminate(true);
				btnClose.setEnabled(false);
			}
		});

		runner.execute();
	}

	public void appendToStdout(String text) {
		document.appendToStdout(text);
	}

	public void appendToStderr(String text) {
		document.appendToStderr(text);
	}

	public void setStatus(String text) {
		lblStatus.setText(text);
	}
	
	public void done(int rc) {
		pbar.setIndeterminate(false);
		pbar.setValue(pbar.getMaximum());
		btnClose.setEnabled(true);
	}
	
	private void closeParentFrame() {
		setVisible(false);
		dispose();
	}
	
	public class JobRunnerStyledDocument extends DefaultStyledDocument {
		public static final String STDOUT = "stdout";
		public static final String STDERR = "stderr";
		public static final String MINERVA = "minerva";
		
		private Style styleStdout;
		private Style styleStderr;
		private Style styleMinerva;

		public JobRunnerStyledDocument() {
			super();
			addStylesToDocument();
		}

		private void addStylesToDocument() {
			Style def = StyleContext.getDefaultStyleContext().getStyle(
					StyleContext.DEFAULT_STYLE);

			StyleConstants.setFontFamily(def, "MonoSpaced");
			StyleConstants.setFontSize(def, 12);

			styleStdout = addStyle(STDOUT, def);

			styleStderr = addStyle(STDERR, styleStdout);
			StyleConstants.setForeground(styleStderr, Color.red);
			
			styleMinerva = addStyle(MINERVA, styleStdout);
			StyleConstants.setForeground(styleMinerva, Color.blue);
		}
		
		public void appendToStdout(String text) {
			appendString(text, styleStdout);
		}
		
		public void appendToStderr(String text) {
			String[] lines = text.split("\\n");
			
			for (int i = 0; i < lines.length; i++) {
				if (lines[i].startsWith("#"))
					appendString(lines[i] + "\n", styleMinerva);
				else
					appendString(lines[i] + "\n", styleStderr);
			}
		}

		protected void appendString(String text, AttributeSet attrs) {
			try {
				insertString(getLength(), text, attrs);
			} catch (BadLocationException ble) {
				ble.printStackTrace();
			}
		}

	}
}
