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

package uk.ac.sanger.arcturus.consistencychecker;

import java.util.List;
import java.util.Vector;

import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.helpers.DefaultHandler;

class MyHandler extends DefaultHandler {
	public static final int DESCRIPTION = 1;
	public static final int QUERY = 2;
	public static final int FORMAT = 3;
	public static final int TEST = 4;
	
	private List<Test> tests;
	private String description;
	private String query;
	private String format;
	private boolean critical;
	private StringBuilder content;
	
	public List<Test> getTests() {
		return tests;
	}
	
	public void startDocument() throws SAXException {
		//System.out.println("startDocument");
		tests = new Vector<Test>();
	}	

	public void endDocument() throws SAXException {
		//System.out.println("endDocument");
	}

	private int getTypeCode(String lName, String qName) {
		if (lName != null && lName.length() > 0)
			return getTypeCode(lName);
		else if (qName != null && qName.length() > 0)
			return getTypeCode(qName);
		else
			return -1;
	}

	private int getTypeCode(String name) {
		if (name.equals("description"))
			return DESCRIPTION;

		if (name.equals("query"))
			return QUERY;

		if (name.equals("format"))
			return FORMAT;
		
		if (name.equals("test"))
			return TEST;

		return -1;
	}
	
	public void startElement(String namespaceURI, String lName, String qName,
			Attributes attrs) throws SAXException {
		//String name = (lName != null && lName.length() > 0) ? lName : qName;		
		//System.out.println("startElement(" + name + ")");
		
		int type = getTypeCode(lName, qName);
		
		switch (type) {
			case TEST:
				description = null;
				query = null;
				format = null;				
				String criticality = attrs.getValue("critical");
				critical = criticality != null && criticality.equalsIgnoreCase("YES");
				break;
				
			case DESCRIPTION:
			case QUERY:
			case FORMAT:
				content = new StringBuilder();
				break;
				
			default:
				content = null;
				break;
		}
	}
	
	public void endElement(String namespaceURI, String lName,String qName) throws SAXException {
		//String name = (lName != null && lName.length() > 0) ? lName : qName;			
		//System.out.println("endElement(" + name + ")");
	
		int type = getTypeCode(lName, qName);
		
		switch (type) {
			case TEST:
				Test test = new Test(description, query, format, critical);
				tests.add(test);
				break;
				
			case DESCRIPTION:
				description = removeWhiteSpace(content);
				break;
				
			case QUERY:
				query = removeWhiteSpace(content);
				break;
				
			case FORMAT:
				format = removeWhiteSpace(content);
				break;				
		}
	
	}
	
	public void ignorableWhitespace(char[] ch,
            int start,
            int length)
            throws SAXException	{
		//System.out.println("ignorableWhitespace(length=" + length + ")");
	}
	
	public void characters(char[] ch, int start, int length)
            throws SAXException {
		//String string = new String(ch, start, length);
		//System.out.println("characters(" + string + ")");
		
		if (content != null)
			content.append(ch, start, length);
	}
	
	public void error(SAXParseException e) throws SAXParseException {
		throw e;
	}

	public void warning(SAXParseException err) throws SAXParseException {
		System.out.println("** Warning" + ", line " + err.getLineNumber()
				+ ", uri " + err.getSystemId());
		System.out.println("   " + err.getMessage());
	}

	private String removeWhiteSpace(StringBuilder sb) {
		String str = sb.toString();
		String[] lines = str.split("[\\n\\r]");
		
		sb = new StringBuilder();
		for (int i = 0; i < lines.length; i++) {
			if (i > 0)
				sb.append(' ');
			
			sb.append(lines[i].trim());
		}
		
		return sb.toString().trim();
	}
}