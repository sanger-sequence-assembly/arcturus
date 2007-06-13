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

public class CheckConsistencyPanel extends MinervaPanel {
	protected CheckConsistency checker = new CheckConsistency();
	protected JTextArea textarea = new JTextArea();
	protected JButton btnRefresh;
	protected JButton btnClear;

	public CheckConsistencyPanel(ArcturusDatabase adb, MinervaTabbedPane parent) {
		super(new BorderLayout(), parent, adb);

		createMenus();

		btnRefresh = new JButton(actionRefresh);
		btnClear = new JButton("Clear all messages");

		JScrollPane scrollpane = new JScrollPane(textarea);

		add(scrollpane, BorderLayout.CENTER);

		JPanel buttonpanel = new JPanel(new FlowLayout());

		buttonpanel.add(btnRefresh);
		buttonpanel.add(btnClear);

		add(buttonpanel, BorderLayout.SOUTH);

		btnClear.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				textarea.setText("");
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

	public void refresh() {
		actionRefresh.setEnabled(false);
		new Worker().execute();
	}

	class Worker extends SwingWorker<Void, String> implements
			CheckConsistency.CheckConsistencyListener {
		protected Void doInBackground() throws Exception {
			try {
				checker.checkConsistency(adb, this);
			}
			catch (SQLException sqle) {
				Arcturus.logWarning("An error occurred whilst checking the database", sqle);
			}
			return null;
		}

		protected void done() {
			actionRefresh.setEnabled(true);
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
