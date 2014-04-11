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
