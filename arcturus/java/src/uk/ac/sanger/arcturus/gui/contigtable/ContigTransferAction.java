package uk.ac.sanger.arcturus.gui.contigtable;

import java.awt.event.ActionEvent;
import javax.swing.AbstractAction;
import javax.swing.JOptionPane;

import uk.ac.sanger.arcturus.data.*;

public class ContigTransferAction extends AbstractAction {
	protected ContigTable table;
	protected Project targetProject;
	
	public ContigTransferAction(ContigTable table, Project targetProject) {
		super(targetProject == null ? "BIN" : targetProject.getName());
		
		this.table = table;
		this.targetProject = targetProject;
	}
	
	public void actionPerformed(ActionEvent e) {
		String targetName = (targetProject == null) ? "BIN" : targetProject.getName();
		
		JOptionPane.showMessageDialog(null,
				"*** TEST MESSAGE -- NOT YET OPERATIONAL ***\nThe selected contigs will be transferred to " + targetName,
				"Contig transfers requested", JOptionPane.INFORMATION_MESSAGE, null);

	}

}
