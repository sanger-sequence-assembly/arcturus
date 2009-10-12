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

import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.*;

public class ScaffoldHandler extends DefaultHandler {
	public static final int UNKNOWN = -1; 
	public static final int ASSEMBLY = 1;
	public static final int SUPERSCAFFOLD = 2;
	public static final int SCAFFOLD = 3;
	public static final int CONTIG = 4;
	public static final int GAP = 5;
	public static final int BRIDGE = 6;
	public static final int SUPERBRIDGE = 7;
	public static final int LINK = 8;
	
	private DefaultTreeModel model = null;
	
	private AssemblyNode assemblyNode;
	private SuperscaffoldNode superscaffoldNode;
	private ScaffoldNode scaffoldNode;
	
	private List<SuperscaffoldNode> ssnList = new Vector<SuperscaffoldNode>();
	
	public ScaffoldHandler(DefaultTreeModel model) {
		this.model = model;
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
	}
	
	private class SuperscaffoldNodeComparator implements Comparator<SuperscaffoldNode> {
		public int compare(SuperscaffoldNode o1, SuperscaffoldNode o2) {
			return o2.length() - o1.length();
		}		
	}

	private int getTypeCode(String lName, String qName) {
		if (lName != null && lName.length() > 0)
			return getTypeCode(lName);
		else if (qName != null && qName.length() > 0)
			return getTypeCode(qName);
		else
			return UNKNOWN;
	}

	private int getTypeCode(String name) {
		if (name.equals("contig"))
			return CONTIG;

		if (name.equals("gap"))
			return GAP;

		if (name.equals("bridge"))
			return BRIDGE;

		if (name.equals("link"))
			return LINK;

		if (name.equals("scaffold"))
			return SCAFFOLD;

		if (name.equals("superscaffold"))
			return SUPERSCAFFOLD;

		if (name.equals("superbridge"))
			return SUPERBRIDGE;

		if (name.equals("assembly"))
			return ASSEMBLY;

		return UNKNOWN;
	}
	
	private GapNode gNode = null;

	public void startElement(String namespaceURI, String lName,
			String qName, Attributes attrs) throws SAXException {
		int type = getTypeCode(lName, qName);

		switch (type) {
			case ASSEMBLY:
				String created = attrs.getValue("date");
				assemblyNode = new AssemblyNode(created);
				model.setRoot(assemblyNode);
				break;

			case SUPERSCAFFOLD:
				superscaffoldNode = new SuperscaffoldNode();
				break;

			case SCAFFOLD:
				String sSense = attrs.getValue("sense");
				boolean sForward = sSense.equalsIgnoreCase("F");
				scaffoldNode = new ScaffoldNode(sForward);
				break;

			case CONTIG:
				int ID = getIntegerAttribute(attrs, "id", -1);
				int cSize = getIntegerAttribute(attrs, "size", 0);
				int project = getIntegerAttribute(attrs, "project", -1);
				String cSense = attrs.getValue("sense");
				boolean cForward = cSense.equalsIgnoreCase("F");
				ContigNode cNode = new ContigNode(ID, project, cSize, cForward);
				scaffoldNode.add(cNode);
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
		int type = getTypeCode(lName, qName);

		switch (type) {
			case ASSEMBLY:
				break;
				
			case SUPERSCAFFOLD:
				ssnList.add(superscaffoldNode);
				break;
				
			case SCAFFOLD:
				superscaffoldNode.add(scaffoldNode);
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
