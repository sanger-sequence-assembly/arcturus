// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.common.contigtransfer;

import java.awt.Component;
import java.awt.event.ActionEvent;
import java.sql.SQLException;
import java.util.List;

import javax.swing.AbstractAction;
import javax.swing.JOptionPane;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestNotifier;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

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

			} catch (SQLException e) {
				Arcturus.logWarning("SQL exception whilst creating a contig transfer request", e);
			}
		}

		ContigTransferRequestNotifier.getInstance().processAllQueues();
	}

}
