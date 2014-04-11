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

package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import javax.swing.SwingWorker;
import javax.swing.tree.TreeModel;
import java.sql.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ScaffoldManagerWorker extends SwingWorker<TreeModel,Void> {
	private ArcturusDatabase adb = null;
	private ScaffoldXMLDataParser parser = new ScaffoldXMLDataParser();
	private TreeModel result;
	private ScaffoldManagerPanel parent;
	
    public ScaffoldManagerWorker(ScaffoldManagerPanel parent, ArcturusDatabase adb) {
    	this.parent = parent;
    	this.adb = adb;
    }
    
	protected TreeModel doInBackground() throws Exception {
		result = null;
		
		result = parser.buildTreeModel(adb);
		
		return result;
	}
	
	protected void done() {
		parent.setModel(result);
		parent.updateActions();
	}
}
