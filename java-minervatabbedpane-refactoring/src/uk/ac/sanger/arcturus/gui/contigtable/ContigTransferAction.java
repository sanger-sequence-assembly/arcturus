package uk.ac.sanger.arcturus.gui.contigtable;

import java.awt.event.ActionEvent;
import java.sql.SQLException;

import javax.swing.AbstractAction;
import javax.swing.JOptionPane;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestNotifier;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigTransferAction extends AbstractAction {
	protected ContigTable table;
	protected Project targetProject;
	
	public ContigTransferAction(ContigTable table, Project targetProject) {
		super(targetProject.getName());
		
		this.table = table;
		this.targetProject = targetProject;
	}
	
	public void actionPerformed(ActionEvent event) {
		ArcturusDatabase adb = targetProject.getArcturusDatabase();
		
		int[] indices = table.getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) table.getModel();
	
		for (int i = 0; i < indices.length; i++) {
			Contig contig = (Contig)ctm.elementAt(indices[i]);
			
			try {
				adb.createContigTransferRequest(contig, targetProject);
			} catch (ContigTransferRequestException e) {
				String message = "Failed to create a request to transfer contig " + contig.getID()
					+ " to project " + targetProject.getName() + ".\n"
					+ "Reason: " + e.getTypeAsString();
				
				JOptionPane.showMessageDialog(table,
						message,
						"Failed to create request", JOptionPane.WARNING_MESSAGE, null);

			} catch (SQLException e) {
				Arcturus.logWarning("SQL exception whilst creating a contig transfer request", e);
			}
		}

		ContigTransferRequestNotifier.getInstance().processAllQueues();
	}

}
