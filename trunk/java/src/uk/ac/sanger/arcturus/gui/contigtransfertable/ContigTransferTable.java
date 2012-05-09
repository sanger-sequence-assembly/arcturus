package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.table.*;
import javax.swing.ListSelectionModel;

import java.sql.SQLException;
import java.text.*;
import java.util.Set;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.contigtransfer.*;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.gui.SortableTable;
import uk.ac.sanger.arcturus.gui.WarningFrame;

import uk.ac.sanger.arcturus.gui.genericdisplay.InfoPanel;
import uk.ac.sanger.arcturus.gui.genericdisplay.InvalidClientObjectException;
import uk.ac.sanger.arcturus.gui.genericdisplay.PopupManager;

import uk.ac.sanger.arcturus.people.*;

public class ContigTransferTable extends SortableTable implements PopupManager {
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);
	private final DateFormat formatter = new SimpleDateFormat(
			"yyyy MMM dd HH:mm");

	protected ContigInfoPanel cip;

	protected Popup popup;

	protected ContigRequestPopupMenu singleRequestPopupMenu;

	protected JMenuItem itemCancelRequest = new JMenuItem("Cancel request...");
	protected JMenuItem itemRefuseRequest = new JMenuItem("Refuse request...");
	protected JMenuItem itemApproveRequest = new JMenuItem("Approve request...");
	protected JMenuItem itemExecuteRequest = new JMenuItem("Execute request...");

	protected JPopupMenu multipleRequestPopupMenu;

	protected JMenuItem itemCancelMultipleRequests = new JMenuItem(
			"Cancel selected requests...");
	protected JMenuItem itemRefuseMultipleRequests = new JMenuItem(
			"Refuse selected requests...");
	protected JMenuItem itemApproveMultipleRequests = new JMenuItem(
			"Approve selected requests...");
	protected JMenuItem itemExecuteMultipleRequests = new JMenuItem(
			"Execute selected requests...");

	protected WarningFrame warningFrame;
	
	protected ArcturusDatabase adb;

	protected Person me;

	public ContigTransferTable(ContigTransferTableModel cttm) throws ArcturusDatabaseException {
		super(cttm);

		adb = cttm.getArcturusDatabase();
		
		me = adb.findMe();

		setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);

		addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				handleMouseEvent(e);
			}

			public void mousePressed(MouseEvent e) {
				handleMouseEvent(e);
			}

			public void mouseReleased(MouseEvent e) {
				handleMouseEvent(e);
			}
		});

		cip = new ContigInfoPanel(this);

		createPopupMenus();
	}

	private void createPopupMenus() {
		singleRequestPopupMenu = new ContigRequestPopupMenu();

		singleRequestPopupMenu.add(itemCancelRequest);

		singleRequestPopupMenu.addSeparator();

		singleRequestPopupMenu.add(itemRefuseRequest);
		singleRequestPopupMenu.add(itemApproveRequest);

		singleRequestPopupMenu.addSeparator();

		singleRequestPopupMenu.add(itemExecuteRequest);

		itemCancelRequest.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				cancelRequest(singleRequestPopupMenu.getRequest());
			}
		});

		itemRefuseRequest.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				refuseRequest(singleRequestPopupMenu.getRequest());
			}
		});

		itemApproveRequest.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				approveRequest(singleRequestPopupMenu.getRequest());
			}
		});

		itemExecuteRequest.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				executeRequest(singleRequestPopupMenu.getRequest());
			}
		});

		multipleRequestPopupMenu = new JPopupMenu();

		multipleRequestPopupMenu.add(itemCancelMultipleRequests);
		multipleRequestPopupMenu.addSeparator();
		multipleRequestPopupMenu.add(itemRefuseMultipleRequests);
		multipleRequestPopupMenu.add(itemApproveMultipleRequests);
		multipleRequestPopupMenu.addSeparator();
		multipleRequestPopupMenu.add(itemExecuteMultipleRequests);

		itemCancelMultipleRequests.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				cancelMultipleRequests();
			}
		});

		itemRefuseMultipleRequests.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				refuseMultipleRequests();
			}
		});

		itemApproveMultipleRequests.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				approveMultipleRequests();
			}
		});

		itemExecuteMultipleRequests.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				executeMultipleRequests();
			}
		});
	}

	protected void cancelRequest(ContigTransferRequest request) {
		Object[] options = { "Yes", "No" };

		int rc = JOptionPane.showOptionDialog(this,
				"Do you really want to cancel this request?",
				"Please confirm the command", JOptionPane.YES_NO_OPTION,
				JOptionPane.WARNING_MESSAGE, null, options, options[1]);

		if (rc == JOptionPane.YES_OPTION) {
			try {
				adb.reviewContigTransferRequest(request, me,
						ContigTransferRequest.CANCELLED);
				ContigTransferRequestNotifier.getInstance().processAllQueues();
				refresh();
			} catch (ContigTransferRequestException e) {
				notifyFailure(e, ContigTransferRequest.CANCELLED);
			} catch (ArcturusDatabaseException e) {
				notifyFailure(e, request, ContigTransferRequest.CANCELLED);
			}
		}
	}

	protected void refuseRequest(ContigTransferRequest request) {
		Object[] options = { "Yes", "No" };

		int rc = JOptionPane.showOptionDialog(this,
				"Do you really want to refuse this request?",
				"Please confirm the command", JOptionPane.YES_NO_OPTION,
				JOptionPane.WARNING_MESSAGE, null, options, options[1]);

		if (rc == JOptionPane.YES_OPTION) {
			try {
				adb.reviewContigTransferRequest(request, me,
						ContigTransferRequest.REFUSED);
				ContigTransferRequestNotifier.getInstance().processAllQueues();
				refresh();
			} catch (ContigTransferRequestException e) {
				notifyFailure(e, ContigTransferRequest.REFUSED);
			} 
			catch (ArcturusDatabaseException e) {
				notifyFailure(e, request, ContigTransferRequest.REFUSED);
			}
		}
	}

	protected void approveRequest(ContigTransferRequest request) {
		Object[] options = { "Yes", "No" };

		int rc = JOptionPane.showOptionDialog(this,
				"Do you really want to approve this request?",
				"Please confirm the command", JOptionPane.YES_NO_OPTION,
				JOptionPane.WARNING_MESSAGE, null, options, options[1]);

		if (rc == JOptionPane.YES_OPTION) {
			try {
				adb.reviewContigTransferRequest(request, me,
						ContigTransferRequest.APPROVED);
				ContigTransferRequestNotifier.getInstance().processAllQueues();
				refresh();
			} catch (ContigTransferRequestException e) {
				notifyFailure(e, ContigTransferRequest.APPROVED);
			}
			catch (ArcturusDatabaseException e) {
					notifyFailure(e, request, ContigTransferRequest.APPROVED);
			}
		}
	}

	protected void executeRequest(ContigTransferRequest request) {
		Object[] options = { "Yes", "No" };

		int rc = JOptionPane.showOptionDialog(this,
				"Do you really want to execute this request?",
				"Please confirm the command", JOptionPane.YES_NO_OPTION,
				JOptionPane.WARNING_MESSAGE, null, options, options[1]);

		if (rc == JOptionPane.YES_OPTION) {
			try {
				adb.executeContigTransferRequest(request, me, true);
				ContigTransferRequestNotifier.getInstance().processAllQueues();
				refresh();
			} catch (ContigTransferRequestException e) {
				notifyFailure(e, ContigTransferRequest.DONE);
			}
			catch (ArcturusDatabaseException e) {
				notifyFailure(e, request, ContigTransferRequest.DONE);
			}
		}
	}

	protected void cancelMultipleRequests() {
		processMultipleRequests(ContigTransferRequest.CANCELLED);
	}

	protected void refuseMultipleRequests() {
		processMultipleRequests(ContigTransferRequest.REFUSED);
	}

	protected void approveMultipleRequests() {
		processMultipleRequests(ContigTransferRequest.APPROVED);
	}

	protected void executeMultipleRequests() {
		processMultipleRequests(ContigTransferRequest.DONE);
	}

	protected void processMultipleRequests(int newStatus) {
		Object[] options = { "Yes", "No" };

		String verb = ContigTransferRequest.getStatusVerb(newStatus);
		
		Component window = SwingUtilities.getRoot(this);

		int rc = JOptionPane.showOptionDialog(window, "Do you really want to "
				+ verb + " these requests?", "Please confirm the command",
				JOptionPane.YES_NO_OPTION, JOptionPane.WARNING_MESSAGE, null,
				options, options[1]);

		if (rc == JOptionPane.YES_OPTION) {
			int[] rows = getSelectedRows();
			
			Arcturus.logInfo("Preparing to " + verb + " " + rows.length + " contig transfer requests");
			
			ContigTransferRequest[] requests = new ContigTransferRequest[rows.length];
			
			ContigTransferTableModel model = (ContigTransferTableModel) getModel();
			
			for (int i = 0; i < rows.length; i++) {
				requests[i] = model.getRequestForRow(rows[i]);
				Arcturus.logInfo("\t" + verb + " : " + requests[i]);
			}
			
			ProgressMonitor monitor = new ProgressMonitor(window,
					"Processing contig transfer requests",
					"Processing " + requests.length + " requests", 0, requests.length);
			
			monitor.setMillisToDecideToPopup(50);
			monitor.setMillisToPopup(100);
			
			ContigTransferWorker worker = null;
			
			try {
				worker = new ContigTransferWorker(this, adb, requests, newStatus, monitor);
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to create a contig transfer worker", e);
			}
			
			worker.execute();
		}
	}

	protected void notifyMultipleFailures(Set<ContigTransferRequestException> failures, int newStatus) {
		if (warningFrame == null)
			warningFrame = new WarningFrame("Contig Transfer Errors");
		
		warningFrame.clearText();
		
		for (ContigTransferRequestException ctre : failures) {
			ContigTransferRequest request = ctre.getRequest();
			
			String reason = ctre.getMessage();
			
			if (reason == null)
				reason = ctre.getTypeAsString();
			
			String message = "Failed to change status of request "
				+ (request == null ? "[UNKNOWN ID]" : request.getRequestID()) + " to "
				+ ContigTransferRequest.convertStatusToString(newStatus) + "\n"
				+ "The reason was " + reason;

			warningFrame.appendText(message);
			warningFrame.appendText("\n\n");
		}
		
		warningFrame.setVisible(true);
	}

	protected void notifyFailure(ArcturusDatabaseException e, ContigTransferRequest request, int newStatus) {
	
	}

	protected void notifyFailure(ContigTransferRequestException e, int newStatus) {
		String reason = e.getMessage();
		ContigTransferRequest request = e.getRequest();
		int requestID = (request == null) ? -1 : request.getRequestID();

		if (reason == null)
			reason = e.getTypeAsString();

		String message = "Failed to change status of request "
				+ requestID + " to "
				+ ContigTransferRequest.convertStatusToString(newStatus) + "\n"
				+ "The reason was " + reason;

		JOptionPane.showMessageDialog(this, message,
				"Failed to update request", JOptionPane.WARNING_MESSAGE, null);

		System.err.println(message);
	}

	protected void displayPopupMenu(MouseEvent e) throws ArcturusDatabaseException {
		Point point = e.getPoint();

		int row = rowAtPoint(point);

		if (isRowSelected(row) && getSelectedRowCount() > 1) {
			int[] rows = getSelectedRows();

			boolean canCancel = true;
			boolean canRefuse = true;
			boolean canApprove = true;
			boolean canExecute = true;

			for (int i = 0; i < rows.length; i++) {
				ContigTransferRequest request = ((ContigTransferTableModel) getModel())
						.getRequestForRow(rows[i]);

				canCancel &= adb.canCancelRequest(request, me);
				canRefuse &= adb.canRefuseRequest(request, me);
				canApprove &= adb.canApproveRequest(request, me);
				canExecute &= adb.canExecuteRequest(request, me);
			}

			itemCancelMultipleRequests.setEnabled(canCancel);
			itemRefuseMultipleRequests.setEnabled(canRefuse);
			itemApproveMultipleRequests.setEnabled(canApprove);
			itemExecuteMultipleRequests.setEnabled(canExecute);

			multipleRequestPopupMenu.show(e.getComponent(), e.getX(), e.getY());
		} else {
			ContigTransferRequest request = ((ContigTransferTableModel) getModel())
					.getRequestForRow(row);

			singleRequestPopupMenu.setRequest(request);

			itemCancelRequest.setEnabled(adb.canCancelRequest(request, me));
			itemRefuseRequest.setEnabled(adb.canRefuseRequest(request, me));
			itemApproveRequest.setEnabled(adb.canApproveRequest(request, me));
			itemExecuteRequest.setEnabled(adb.canExecuteRequest(request, me));

			singleRequestPopupMenu.show(e.getComponent(), e.getX(), e.getY());
		}
	}

	private void handleMouseEvent(MouseEvent event) {
		if (event.isPopupTrigger()) {
			try {
				displayPopupMenu(event);
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to display pupup menu", e);
			}
		} else if (event.getID() == MouseEvent.MOUSE_CLICKED) {
			Point point = event.getPoint();

			int row = rowAtPoint(point);
			int column = columnAtPoint(point);

			int modelColumn = convertColumnIndexToModel(column);

			if (modelColumn != ContigTransferTableModel.COLUMN_CONTIG_ID)
				return;

			Contig contig = ((ContigTransferTableModel) getModel())
					.getContigForRow(row);

			try {
				cip.setClientObject(contig);
				displayPopup(cip, point);
			} catch (InvalidClientObjectException e1) {
				e1.printStackTrace();
			}
		}
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

		if (c instanceof JComponent) {
			String text = null;
			ContigTransferRequest request = ((ContigTransferTableModel) getModel())
					.getRequestForRow(rowIndex);

			switch (vColIndex) {
				case ContigTransferTableModel.COLUMN_CONTIG_ID:
					Contig contig = request.getContig();
					;

					text = contig == null ? "Contig no longer exists"
							: "Contig " + contig.getID() + "\n" + "  Name = "
									+ contig.getName() + "\n" + "  Length = "
									+ contig.getLength() + "bp\n"
									+ "  Created "
									+ formatter.format(contig.getCreated());
					break;

				case ContigTransferTableModel.COLUMN_REQUESTER:
				case ContigTransferTableModel.COLUMN_OPENED_DATE:
					text = request.getRequesterComment();
					break;

				case ContigTransferTableModel.COLUMN_REVIEWER:
				case ContigTransferTableModel.COLUMN_REVIEWED_DATE:
				case ContigTransferTableModel.COLUMN_STATUS:
					text = request.getReviewerComment();
					break;
			}

			((JComponent) c).setToolTipText(text);
		}

		if (isCellSelected(rowIndex, vColIndex)) {
			c.setBackground(getBackground());
		} else {
			if (rowIndex % 2 == 0) {
				c.setBackground(VIOLET1);
			} else {
				c.setBackground(VIOLET2);
			}
		}

		if (isCellSelected(rowIndex, vColIndex))
			c.setForeground(Color.RED);
		else
			c.setForeground(Color.BLACK);

		return c;
	}

	public void hidePopup() {
		if (popup != null) {
			popup.hide();
			popup = null;
		}
	}

	private void displayPopup(InfoPanel ip, Point p) {
		SwingUtilities.convertPointToScreen(p, this);

		PopupFactory factory = PopupFactory.getSharedInstance();
		popup = factory.getPopup(this, ip, p.x - 5, p.y - 5);
		popup.show();
	}

	class ContigRequestPopupMenu extends JPopupMenu {
		protected ContigTransferRequest request = null;

		public void setRequest(ContigTransferRequest request) {
			this.request = request;
		}

		public ContigTransferRequest getRequest() {
			return request;
		}
	}
}
