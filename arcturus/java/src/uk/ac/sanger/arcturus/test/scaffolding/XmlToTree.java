package scaffolding;

import org.xml.sax.*;
import org.xml.sax.helpers.DefaultHandler;

import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

class XmlToTree extends DefaultHandler {
    protected SAXParserFactory factory = null;
    protected SAXParser saxParser = null;

    public static final int ASSEMBLY = 1;
    public static final int SUPERSCAFFOLD = 2;
    public static final int SCAFFOLD = 3;
    public static final int CONTIG = 4;
    public static final int GAP = 5;
    public static final int BRIDGE = 6;
    public static final int SUPERBRIDGE = 7;
    public static final int LINK = 8;

    protected Assembly lastAssembly = null;
    protected SuperScaffold lastSuperScaffold = null;
    protected Scaffold lastScaffold = null;
    protected Gap lastGap = null;
    protected Bridge lastBridge = null;
    protected SuperBridge lastSuperBridge = null;

    public void startDocument() throws SAXException {
	lastAssembly = null;
	lastSuperScaffold = null;
	lastScaffold = null;
	lastGap = null;
	lastBridge = null;
	lastSuperBridge = null;
    }

    public void endDocument() throws SAXException {
    }

    public Assembly getAssembly() {
	return lastAssembly;
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
	    lastAssembly = makeAssembly(attrs);
	    break;

	case SUPERSCAFFOLD:
	    lastSuperScaffold = makeSuperScaffold(attrs);
	    lastAssembly.add(lastSuperScaffold);
	    break;

	case SCAFFOLD:
	    lastScaffold = makeScaffold(attrs);
	    lastSuperScaffold.add(lastScaffold);
	    break;

	case CONTIG:
	    Contig contig = makeContig(attrs);
	    lastScaffold.add(contig);
	    break;

	case GAP:
	    lastGap = makeGap(attrs);
	    lastScaffold.add(lastGap);
	    break;

	case BRIDGE:
	    lastBridge = makeBridge(attrs);
	    lastGap.add(lastBridge);
	    break;

	case SUPERBRIDGE:
	    lastSuperBridge = makeSuperBridge(attrs);
	    lastSuperScaffold.add(lastSuperBridge);
	    break;

	case LINK:
	    Link link = makeLink(attrs);
	    if (lastBridge != null)
		lastBridge.addLink(link);
	    else if (lastSuperBridge != null)
		lastSuperBridge.addLink(link);
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
	    lastSuperScaffold = null;
	    break;

	case SCAFFOLD:
	    lastScaffold = null;
	    break;

	case CONTIG:
	    break;

	case GAP:
	    lastGap = null;
	    break;

	case BRIDGE:
	    lastBridge = null;
	    break;

	case SUPERBRIDGE:
	    lastSuperBridge = null;
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

    private Assembly makeAssembly(Attributes attrs) {
	String instance = attrs.getValue("instance");
	String organism = attrs.getValue("organism");
	String created = attrs.getValue("date");

	return new Assembly(instance, organism, created);
    }

    private SuperScaffold makeSuperScaffold(Attributes attrs) {
	int id = getIntegerAttribute(attrs, "id");
	int size = getIntegerAttribute(attrs, "size");

	return new SuperScaffold(id, size);
    }

    private Scaffold makeScaffold(Attributes attrs) {
	int id = getIntegerAttribute(attrs, "id");
	boolean forward = getBooleanAttribute(attrs, "sense", "F");

	return new Scaffold(id, forward);
    }

    private Contig makeContig(Attributes attrs) {
	int id = getIntegerAttribute(attrs, "id");
	int size = getIntegerAttribute(attrs, "size");
	int project_id = getIntegerAttribute(attrs, "project");
	boolean forward = getBooleanAttribute(attrs, "sense", "F");

	return new Contig(id, size, project_id, forward);
    }

    private Gap makeGap(Attributes attrs) {
	int size = getIntegerAttribute(attrs, "size");

	return new Gap(size);
    }

    private SuperBridge makeSuperBridge(Attributes attrs) {
	int template_id = getIntegerAttribute(attrs, "template");
	int silow = getIntegerAttribute(attrs, "silow");
	int sihigh = getIntegerAttribute(attrs, "sihigh");

	return new SuperBridge(template_id, silow, sihigh);
     }

    private Bridge makeBridge(Attributes attrs) {
	int template_id = getIntegerAttribute(attrs, "template");
	int silow = getIntegerAttribute(attrs, "silow");
	int sihigh = getIntegerAttribute(attrs, "sihigh");
	int gapsize = getIntegerAttribute(attrs, "gapsize");

	return new Bridge(template_id, silow, sihigh, gapsize);
    }

    private Link makeLink(Attributes attrs) {
	int contig_id = getIntegerAttribute(attrs, "contig");
	int read_id = getIntegerAttribute(attrs, "read");
	int cstart = getIntegerAttribute(attrs, "cstart");
	int cfinish = getIntegerAttribute(attrs, "cfinish");
	boolean forward = getBooleanAttribute(attrs, "sense", "F");

	return new Link(contig_id, read_id, cstart, cfinish, forward);
    }
}
