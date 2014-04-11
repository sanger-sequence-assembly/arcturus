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

import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Vector;

import javax.swing.tree.DefaultTreeModel;

import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.helpers.DefaultHandler;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.*;

public class ScaffoldHandler extends DefaultHandler {
	protected enum Type {
		UNKNOWN, ASSEMBLY, SUPERSCAFFOLD, 
		SCAFFOLD, CONTIG, GAP, BRIDGE, SUPERBRIDGE,
		LINK, UNSCAFFOLDED_CONTIGS };
		
	private DefaultTreeModel model = null;
	private ArcturusDatabase adb;
	
	private AssemblyNode assemblyNode;
	private SuperscaffoldNode superscaffoldNode;
	private ScaffoldNode scaffoldNode;
	private UnscaffoldedContigsNode unscaffoldedContigsNode;
	
	private List<SuperscaffoldNode> ssnList = new Vector<SuperscaffoldNode>();
	
	public ScaffoldHandler(DefaultTreeModel model, ArcturusDatabase adb) {
		this.model = model;
		this.adb = adb;
	}

	public void startDocument() throws SAXException {
		model.setRoot(null);
	}

	public void endDocument() throws SAXException {
		SuperscaffoldNode[] ssnArray = ssnList.toArray(new SuperscaffoldNode[0]);
		
		Comparator<SuperscaffoldNode> comparator = new SuperscaffoldNodeComparator();
		
		Arrays.sort(ssnArray, comparator);
		
		for (int i = 0; i < ssnArray.length; i++)
			assemblyNode.add(ssnArray[i]);
		
		if (unscaffoldedContigsNode != null)
			assemblyNode.add(unscaffoldedContigsNode);
	}
	
	private class SuperscaffoldNodeComparator implements Comparator<SuperscaffoldNode> {
		public int compare(SuperscaffoldNode o1, SuperscaffoldNode o2) {
			return o2.length() - o1.length();
		}		
	}

	private Type getTypeCode(String lName, String qName) {
		if (lName != null && lName.length() > 0)
			return getTypeCode(lName);
		else if (qName != null && qName.length() > 0)
			return getTypeCode(qName);
		else
			return Type.UNKNOWN;
	}

	private Type getTypeCode(String name) {
		if (name.equals("contig"))
			return Type.CONTIG;

		if (name.equals("gap"))
			return Type.GAP;

		if (name.equals("bridge"))
			return Type.BRIDGE;

		if (name.equals("link"))
			return Type.LINK;

		if (name.equals("scaffold"))
			return Type.SCAFFOLD;

		if (name.equals("superscaffold"))
			return Type.SUPERSCAFFOLD;

		if (name.equals("superbridge"))
			return Type.SUPERBRIDGE;

		if (name.equals("assembly"))
			return Type.ASSEMBLY;
		
		if (name.equals("unallocated-contigs"))
			return Type.UNSCAFFOLDED_CONTIGS;

		return Type.UNKNOWN;
	}
	
	private GapNode gNode = null;

	public void startElement(String namespaceURI, String lName,
			String qName, Attributes attrs) throws SAXException {
		Type type = getTypeCode(lName, qName);

		switch (type) {
			case ASSEMBLY:
				String created = attrs.getValue("date");
				assemblyNode = new AssemblyNode(created);
				model.setRoot(assemblyNode);
				break;

			case SUPERSCAFFOLD:
				if (unscaffoldedContigsNode != null)
					break;
				
				superscaffoldNode = new SuperscaffoldNode();
				break;
				
			case UNSCAFFOLDED_CONTIGS:
				unscaffoldedContigsNode = new UnscaffoldedContigsNode();
				break;

			case SCAFFOLD:
				if (unscaffoldedContigsNode != null)
					break;
				
				int scaffoldID = getIntegerAttribute(attrs, "id", -1);
				String sSense = attrs.getValue("sense");
				boolean sForward = sSense.equalsIgnoreCase("F");
				scaffoldNode = new ScaffoldNode(scaffoldID, sForward);
				break;

			case CONTIG:
				int contigID = getIntegerAttribute(attrs, "id", -1);
				Contig contig = null;
				boolean current = false;
				try {
					contig = adb.getContigByID(contigID);
					current = adb.isCurrentContig(contigID);
				} catch (ArcturusDatabaseException e) {
					Arcturus.logWarning("Failed to get contig information for contig ID=" + contigID + " whilst building scaffold tree", e);
				}
				
				String cSense = attrs.getValue("sense");
				boolean cForward = cSense.equalsIgnoreCase("F");
				ContigNode cNode = new ContigNode(contig, cForward, current);
				
				if (scaffoldNode != null)
					scaffoldNode.add(cNode);
				else if (unscaffoldedContigsNode != null)
					unscaffoldedContigsNode.add(cNode);
				
				break;

			case GAP:
				int gSize = getIntegerAttribute(attrs, "size", 0);
				gNode = new GapNode(gSize);
				break;

			case BRIDGE:
				if (gNode != null)
					gNode.incrementBridgeCount();
				break;
				
			case SUPERBRIDGE:
			case LINK:
				break;
		}
	}

	public void endElement(String namespaceURI, String lName,
			String qName) throws SAXException {
		Type type = getTypeCode(lName, qName);

		switch (type) {
			case ASSEMBLY:
				break;
				
			case SUPERSCAFFOLD:
				if (unscaffoldedContigsNode != null)
					break;
				
				ssnList.add(superscaffoldNode);
				break;
				
			case SCAFFOLD:
				if (unscaffoldedContigsNode != null)
					break;
				
				superscaffoldNode.add(scaffoldNode);
				scaffoldNode = null;
				break;
				
			case CONTIG:
				break;
				
			case GAP:
				scaffoldNode.add(gNode);
				gNode = null;
				break;

			case BRIDGE:
			case SUPERBRIDGE:
			case LINK:
				break;
		}
	}

	public void error(SAXParseException e) throws SAXParseException {
		throw e;
	}

	public void warning(SAXParseException err) throws SAXParseException {
		System.out.println("** Warning" + ", line " + err.getLineNumber()
				+ ", uri " + err.getSystemId());
		System.out.println("   " + err.getMessage());
	}

	private int getIntegerAttribute(Attributes attrs, String key,
			int defaultvalue) {
		String s = attrs.getValue(key);

		if (s == null)
			return defaultvalue;
		else
			return Integer.parseInt(s);
	}
}
