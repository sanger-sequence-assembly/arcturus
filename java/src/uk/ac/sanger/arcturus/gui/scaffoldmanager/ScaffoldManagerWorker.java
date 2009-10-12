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
		
		Connection conn = adb.getPooledConnection(this);
		
		result = parser.buildTreeModel(conn);
		
		conn.close();
		
		return result;
	}
	
	protected void done() {
		parent.setModel(result);
	}
}
