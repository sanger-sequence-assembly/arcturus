package uk.ac.sanger.arcturus.gui.checkconsistency;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.utils.CheckConsistency;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.Arcturus;

import javax.swing.*;

import java.sql.SQLException;
import java.util.List;

import java.awt.*;
import java.awt.event.*;
import java.io.InputStream;

public class CheckConsistencyPanel extends MinervaPanel {
	protected CheckConsistency checker;
	protected JTextArea textarea = new JTextArea();
	protected JButton btnRefresh;
	protected JButton btnClear;
	protected JButton btnCancel;
	
	protected Worker worker;

	public CheckConsistencyPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);
		
		try {
			InputStream is = getClass().getResourceAsStream("/resources/xml/checkconsistency.xml");
			checker = new CheckConsistency(is);
			is.close();
		}
		catch (Exception e) {
			Arcturus.logSevere("An error occurred when trying to initialise the consistency checker", e);
		}
		
		createMenus();

		btnRefresh = new JButton(actionRefresh);
		btnClear = new JButton("Clear all messages");
		btnCancel = new JButton("Cancel");

		JScrollPane scrollpane = new JScrollPane(textarea);

		add(scrollpane, BorderLayout.CENTER);

		JPanel buttonpanel = new JPanel(new FlowLayout());

		buttonpanel.add(btnRefresh);
		buttonpanel.add(btnClear);
		buttonpanel.add(btnCancel);
		
		btnCancel.setEnabled(false);

		add(buttonpanel, BorderLayout.SOUTH);

		btnClear.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				textarea.setText("");
			}
		});

		btnCancel.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				cancelTask();
			}
		});

		getPrintAction().setEnabled(false);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	public void closeResources() {
	}

	protected void createActions() {
	}

	protected void createClassSpecificMenus() {
	}

	protected void doPrint() {
	}

	protected boolean isRefreshable() {
		return true;
	}

	private void cancelTask() {
		System.err.println("Cancel button pressed");
		worker.cancel(true);
	}

	public void refresh() {
		actionRefresh.setEnabled(false);
		worker = new Worker();
		worker.execute();
		btnCancel.setEnabled(true);
	}

	class Worker extends SwingWorker<Void, String> implements
			CheckConsistency.CheckConsistencyListener {
		protected Void doInBackground() throws Exception {
			try {
				checker.checkConsistency(adb, this, true);
			}
			catch (SQLException sqle) {
				int errorCode = sqle.getErrorCode();
				Arcturus.logWarning("An error occurred whilst checking the database [Error code: " +
							errorCode + "]", sqle);
			}
			return null;
		}

		protected void done() {
			if (isCancelled())
				checker.cancel();
			
			actionRefresh.setEnabled(true);
			btnCancel.setEnabled(false);
		}

		protected void process(List<String> messages) {
			for (String message : messages) {
				textarea.append(message);
				textarea.append("\n");
			}
		}

		public void report(String message) {
			publish(message);
		}
	}
}
