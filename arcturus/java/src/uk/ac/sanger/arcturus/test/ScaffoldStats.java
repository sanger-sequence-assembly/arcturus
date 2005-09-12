import java.io.*;
import java.util.*;

import org.xml.sax.*;
import org.xml.sax.helpers.DefaultHandler;

import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

public class ScaffoldStats {
    public static void main(String[] args) {
	ScaffoldStats stats = new ScaffoldStats();

	stats.run(args);
    }

    public void run(String[] args) {
	String xmlfile = null;
	
	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-in"))
		xmlfile = args[++i];
	}

	if (xmlfile == null) {
	    System.err.println("You must supply an XML file name with the -in prameter");
	    System.exit(1);
	}

        MyHandler handler = new MyHandler();
        SAXParserFactory factory = SAXParserFactory.newInstance();
        factory.setValidating(true);

	try {
            SAXParser saxParser = factory.newSAXParser();
            saxParser.parse(new File(xmlfile), handler);
        } catch (SAXParseException spe) {
           // Error generated by the parser
           System.err.println("\n** Parsing error"
              + ", line " + spe.getLineNumber()
              + ", uri " + spe.getSystemId());
           System.err.println("   " + spe.getMessage() );

           // Use the contained exception, if any
           Exception  x = spe;
           if (spe.getException() != null)
               x = spe.getException();
           x.printStackTrace();

        } catch (SAXException sxe) {
           // Error generated by this application
           // (or a parser-initialization error)
           Exception  x = sxe;
           if (sxe.getException() != null)
               x = sxe.getException();
           x.printStackTrace();

        } catch (ParserConfigurationException pce) {
            // Parser with specified options can't be built
            pce.printStackTrace();

        } catch (IOException ioe) {
           // I/O error
           ioe.printStackTrace();
        }
    }

    class MyHandler extends DefaultHandler {
	private static final int MAXPROJECTS = 100;

	public static final int ASSEMBLY = 1;
	public static final int SUPERSCAFFOLD = 2;
	public static final int SCAFFOLD = 3;
	public static final int CONTIG = 4;
	public static final int GAP = 5;
	public static final int BRIDGE = 6;
	public static final int SUPERBRIDGE = 7;
	public static final int LINK = 8;

	protected int contigCount;
	protected int totalContigLength;
	protected int superContigCount;
	protected int superContigLength;
	protected int scaffoldCount;
	protected int totalScaffoldLength;
	protected int[] projectCount = new int[MAXPROJECTS];
	protected int[] projectLength = new int[MAXPROJECTS];
	protected int superscaffoldID;
	protected int[] scaffoldProjectCount = new int[MAXPROJECTS];
	protected int[] scaffoldProjectLength = new int[MAXPROJECTS];
	protected int scaffoldID;

	public void startDocument() throws SAXException {
	}

	public void endDocument() throws SAXException {
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
	    
	    return -1;
	}
	
	public void startElement(String namespaceURI,
				 String lName, // local name
				 String qName, // qualified name
				 Attributes attrs)
	    throws SAXException {
	    int type = getTypeCode(lName, qName);
	    
	    switch (type) {
	    case ASSEMBLY:
		break;
		
	    case SUPERSCAFFOLD:
		superscaffoldID = getIntegerAttribute(attrs, "id", -1);
		superContigCount = 0;
		superContigLength = 0;
		scaffoldCount = 0;
		for (int i = 0; i < projectCount.length; i++)
		    projectCount[i] = 0;
		for (int i = 0; i < projectLength.length; i++)
		    projectLength[i] = 0;
		break;
		
	    case SCAFFOLD:
		scaffoldID = getIntegerAttribute(attrs, "id", -1);
		contigCount = 0;
		totalContigLength = 0;
		scaffoldCount++;
		for (int i = 0; i < projectCount.length; i++)
		    scaffoldProjectCount[i] = 0;
		for (int i = 0; i < projectLength.length; i++)
		    scaffoldProjectLength[i] = 0;
		break;
		
	    case CONTIG:
		int size = getIntegerAttribute(attrs, "size", 0);
		contigCount++;
		superContigCount++;
		totalContigLength += size;
		superContigLength += size;

		int project = getIntegerAttribute(attrs, "project", -1);
		if (project > 0) {
		    projectCount[project]++;
		    projectLength[project] += size;
		    scaffoldProjectCount[project]++;
		    scaffoldProjectLength[project] += size;
		}
		break;
		
	    case GAP:
		break;
		
	    case BRIDGE:
		break;
		
	    case SUPERBRIDGE:
		break;
	    
	    case LINK:
		break;
	    }
	}
	
	public void endElement(String namespaceURI,
			       String lName, // local name
			       String qName  // qualified name
			       )
	    throws SAXException {
	    int type = getTypeCode(lName, qName);
	    
	    switch (type) {
	    case ASSEMBLY:
		break;
		
	    case SUPERSCAFFOLD:
		System.out.print("SUPER " + superscaffoldID + " " + scaffoldCount + " " +
				   superContigCount + " " + superContigLength);

		for (int i = 0; i < projectCount.length; i++)
		    if (projectCount[i] > 0)
			System.out.print(" " + i + "," + projectCount[i] + "," + projectLength[i]);

		System.out.println();
		break;
		
	    case SCAFFOLD:
		System.out.print("SCAFF " + scaffoldID + " " + contigCount + " " + totalContigLength);

		for (int i = 0; i < scaffoldProjectCount.length; i++)
		    if (scaffoldProjectCount[i] > 0)
			System.out.print(" " + i + "," + scaffoldProjectCount[i] + "," + scaffoldProjectLength[i]);

		System.out.println();
		break;
		
	    case CONTIG:
		break;
		
	    case GAP:
		break;
		
	    case BRIDGE:
		break;
		
	    case SUPERBRIDGE:
		break;
		
	    case LINK:
		break;
	    }
	}
	
	public void error(SAXParseException e)
	    throws SAXParseException {
	    throw e;
	}
	
	public void warning(SAXParseException err)
	    throws SAXParseException {
	    System.out.println("** Warning"
			       + ", line " + err.getLineNumber()
			       + ", uri " + err.getSystemId());
	    System.out.println("   " + err.getMessage());
	}
	
	private int getIntegerAttribute(Attributes attrs, String key, int defaultvalue) {
	    String s = attrs.getValue(key);
	    
	    if (s == null)
		return defaultvalue;
	    else
		return Integer.parseInt(s);
	}
	
	private int getIntegerAttribute(Attributes attrs, String key) {
	    return getIntegerAttribute(attrs, key, -1);
	}
	
	private boolean getBooleanAttribute(Attributes attrs, String key, String truevalue) {
	    String s = attrs.getValue(key);
	    
	    if (s == null)
		return false;
	    else
		return s.equals(truevalue);
	}
	
	private boolean getBooleanAttribute(Attributes attrs, String key) {
	    return getBooleanAttribute(attrs, key, "true");
	}
	
    }
}
