package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import java.io.*;
import java.sql.*;

import org.xml.sax.*;

import javax.swing.tree.DefaultTreeModel;
import javax.swing.tree.TreeModel;
import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ScaffoldXMLDataParser {
	private static final String SCAFFOLD_TREE_TYPE = "scaffold";
	private static final String SCAFFOLD_TREE_FORMAT = "text/xml";
	
	public TreeModel buildTreeModel(ArcturusDatabase adb) throws ArcturusDatabaseException {
		TreeModel model = null;
		Connection conn = null;
		
		try {
			conn = adb.getPooledConnection(this);
			
			int id = findIDForLatestScaffold(conn);
			
			model = createTreeModel(conn, id, adb);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "A database error occurred when building the scaffold tree model", conn, this);
		} catch (ParserConfigurationException e) {
			Arcturus.logWarning("A parser configuration exception occurred when building the scaffold tree model", e);
		} catch (SAXException e) {
			Arcturus.logWarning("A SAX parser exception occurred when building the scaffold tree model", e);
		} catch (IOException e) {
			Arcturus.logWarning("An I/O exception occurred when building the scaffold tree model", e);
		} finally {
			try {
				conn.close();
			} catch (SQLException e) {
				adb.handleSQLException(e, "Failed to close the database connection building the scaffold tree model",
						conn, this);
			}
		}
		
		return model;
	}
	
	private int findIDForLatestScaffold(Connection conn) throws SQLException {
		String query = "select id from NOTE where type = ? and format = ? order by created desc limit 1";
		
		PreparedStatement pstmt = conn.prepareStatement(query);
		
		pstmt.setString(1, SCAFFOLD_TREE_TYPE);
		pstmt.setString(2, SCAFFOLD_TREE_FORMAT);

		ResultSet rs = pstmt.executeQuery();

		int id = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		pstmt.close();

		return id;
	}
	
	private TreeModel createTreeModel(Connection conn, int id, ArcturusDatabase adb)
		throws SQLException, ParserConfigurationException, SAXException, IOException {
		String query = "select content from NOTE where id = ?";

		PreparedStatement pstmt = conn.prepareStatement(query);
		
		pstmt.setInt(1, id);

		ResultSet rs = pstmt.executeQuery();

		InputStream is = rs.next() ? rs.getBinaryStream(1) : null;

		TreeModel model = parseXMLStream(is, adb);

		is.close();
		rs.close();
		pstmt.close();
	
		return model;
	}
	
	private TreeModel parseXMLStream(InputStream is, ArcturusDatabase adb)
		throws ParserConfigurationException, SAXException, IOException {
		DefaultTreeModel model = new DefaultTreeModel(null);
		
		ScaffoldHandler handler = new ScaffoldHandler(model, adb);
		
		SAXParserFactory factory = SAXParserFactory.newInstance();
		
		factory.setValidating(true);

		SAXParser saxParser = factory.newSAXParser();
		saxParser.parse(is, handler);

		return model;
	}

}
