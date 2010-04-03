package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import java.util.Enumeration;
import java.util.concurrent.ExecutionException;
import java.util.Vector;

import javax.swing.JOptionPane;
import javax.swing.JTree;
import javax.swing.SwingWorker;
import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.TreeModel;
import javax.swing.tree.TreeNode;
import javax.swing.tree.TreePath;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.ContigNode;

public class ScaffoldContigFinderWorker extends SwingWorker<TreePath, Void> {
	private ArcturusDatabase adb = null;
	private ScaffoldManagerPanel parent;
	private String text;
	private TreePath result = null;
	
	public ScaffoldContigFinderWorker(ArcturusDatabase adb, ScaffoldManagerPanel parent, String text) {
		this.adb = adb;
		this.parent = parent;
		this.text = text;
	}
	
	protected TreePath doInBackground() throws Exception {
		int[] contig_ids = getContigIds(text);
		
		if (contig_ids == null)
			return null;
		
		TreeModel model = parent.getTree().getModel();
		
		DefaultMutableTreeNode root = (DefaultMutableTreeNode) model.getRoot();
		
		Enumeration e = root.depthFirstEnumeration();
		
		ContigNode cnode = null;
		
		while (e.hasMoreElements()) {
			DefaultMutableTreeNode node = (DefaultMutableTreeNode) e.nextElement();
			
			if (node instanceof ContigNode) {
				Contig contig = ((ContigNode)node).getContig();
				
				for (int contig_id : contig_ids) {
					if (contig.getID() == contig_id) {
						cnode = (ContigNode)node;
						break;
					}
				}
				
				if (cnode != null)
					break;
			}
		}
		
		if (cnode == null)
			return null;
		
		TreeNode[] nodepath = cnode.getPath();
		
		result = new TreePath(nodepath);
		
		return result;
	}

	private int[] getContigIds(String str) {
		try {
			int contig_id = Integer.parseInt(str);
			
			int[] contig_ids = new int[1];
			
			contig_ids[0] = contig_id;
			
			return contig_ids;
		}
		catch (NumberFormatException nfe) {}
		
		Connection conn = null;
		PreparedStatement pstmt = null;
		ResultSet rs = null;
		
		try {
			conn = adb.getPooledConnection(this);
			
			String query = "select m.contig_id from READINFO r,SEQ2READ sr,MAPPING m" +
				" where r.readname = ? and r.read_id=sr.read_id and sr.seq_id=m.seq_id" + 
				" order by m.contig_id desc";
			
			pstmt = conn.prepareStatement(query);
			
			pstmt.setString(1, str);
			
			rs = pstmt.executeQuery();
			
			Vector<Integer> ids = new Vector<Integer>();
			
			while(rs.next()) {
				int contig_id = rs.getInt(1);
				ids.add(contig_id);
			}
			
			rs.close();
			pstmt.close();
			conn.close();
			
			if (ids.isEmpty())
				return null;
			
			int[] contig_ids = new int[ids.size()];
			
			for (int i = 0; i < contig_ids.length; i++)
				contig_ids[i] = ids.get(i);
			
			return contig_ids;
		}
		catch (SQLException sqle) {
			Arcturus.logWarning("An error occurred whilst trying to enumerate contigs", sqle);
		}
		finally {
			try {
				if (conn != null && !conn.isClosed())
					conn.close();
			} catch (SQLException e) {
				Arcturus.logWarning("An error occurred whilst trying to close connection in finally block", e);
			}
		}
		
		return null;
	}

	protected void done() {
		if (result != null) {
			JTree tree = parent.getTree();
			
			tree.scrollPathToVisible(result);
			tree.setSelectionPath(result);
		} else
			JOptionPane.showMessageDialog(parent, "Could not find a contig with identifier " + text, "Unable to find a contig", JOptionPane.WARNING_MESSAGE);
	}
}
