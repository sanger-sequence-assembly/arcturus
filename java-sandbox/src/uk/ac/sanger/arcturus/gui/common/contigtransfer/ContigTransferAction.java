package uk.ac.sanger.arcturus.gui.common.contigtransfer;

import java.awt.Component;
import java.awt.event.ActionEvent;
import java.util.List;

import javax.swing.AbstractAction;
import javax.swing.JOptionPane;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestNotifier;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ContigTransferAction extends AbstractAction {
	protected ContigTransferSource source;
	protected Project targetProject;
	
	public ContigTransferAction(ContigTransferSource source, Project targetProject) {
		super(targetProject.getName());
		
		this.source = source;
		this.targetProject = targetProject;
	}
	
	public void actionPerformed(ActionEvent event) {
		ArcturusDatabase adb = targetProject.getArcturusDatabase();
		
		List<Contig> contigs = source.getSelectedContigs();
		
		if (contigs == null)
			return;
	
		for (Contig contig : contigs) {
			try {
				if (!targetProject.equals(contig.getProject()))
					adb.createContigTransferRequest(contig, targetProject);
			} catch (ContigTransferRequestException e) {
				String message = "Failed to create a request to transfer contig " + contig.getID()
					+ " to project " + targetProject.getName() + ".\n"
					+ "Reason: " + e.getTypeAsString();
				
				Component parent = (source instanceof Component) ? (Component)source : null;
				
				JOptionPane.showMessageDialog(parent,
						message,
						"Failed to create request", JOptionPane.WARNING_MESSAGE, null);

			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Database exception whilst creating a contig transfer request", e);
			}
		}

		ContigTransferRequestNotifier.getInstance().processAllQueues();
	}

}
