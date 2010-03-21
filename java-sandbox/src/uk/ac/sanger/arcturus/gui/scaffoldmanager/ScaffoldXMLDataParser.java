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

public class ScaffoldXMLDataParser {
	public TreeModel buildTreeModel(ArcturusDatabase adb) throws SQLException, IOException {
		Connection conn = adb.getPooledConnection(this);
		
		String query = "select content from NOTE where type = 'scaffold' order by created desc limit 1";
		
		Statement stmt = conn.createStatement();
		
		ResultSet rs = stmt.executeQuery(query);
		
		InputStream is = rs.next() ? rs.getBinaryStream(1) : null;

		TreeModel model = null;
		
		try {
			model = parseXMLStream(is, adb);
		} catch (ParserConfigurationException e) {
			Arcturus.logWarning(e);
		} catch (SAXException e) {
			Arcturus.logWarning(e);
		}
		finally {	
			is.close();
			rs.close();
			stmt.close();
			conn.close();
		}
		
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
