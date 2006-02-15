package uk.ac.sanger.arcturus.people;

import java.util.*;
 
import javax.naming.*;
import javax.naming.directory.*;
import javax.swing.ImageIcon;


public class PeopleManager {
    protected static PeopleManager instance = null;

    public static PeopleManager getInstance() throws NamingException {
	if (instance == null)
	    instance = new PeopleManager();

	return instance;
    }

    protected DirContext ctx = null;

    protected Map uidToPerson = new HashMap();

    protected final String[] attrs = {"cn",
				      "mail",
				      "telephonenumber",
				      "homedirectory",
				      "roomnumber",
				      "departmentnumber",
				      "jpegphoto"};

    private PeopleManager() throws NamingException {
	Properties sysprops = System.getProperties();

	Properties env = new Properties();

	env.put(Context.INITIAL_CONTEXT_FACTORY,
		sysprops.get(Context.INITIAL_CONTEXT_FACTORY));

	env.put(Context.PROVIDER_URL,
		sysprops.get("arcturus.naming.people.url"));

	ctx = new InitialDirContext(env);
    }

    public Person findPerson(String uid) throws NamingException {
	Person person = (Person)uidToPerson.get(uid);

	if (person != null)
	    return person;

	String searchterm = "uid=" + uid;

        Attributes result = null;

	try {
	    result = ctx.getAttributes(searchterm, attrs);
	}
	catch (NameNotFoundException nnfe) {
	    return null;
	}

	person = new Person(uid);

	String commonname = getAttribute(result, "cn");

	if (commonname != null)
	    person.setName(commonname);

	String mail = getAttribute(result, "mail");

	if (mail != null)
	    person.setMail(mail);

	String phone = getAttribute(result, "telephonenumber");

	if (phone != null)
	    person.setTelephone(phone);

	String homedir = getAttribute(result, "homedirectory");

	if (homedir != null)
	    person.setHomeDirectory(homedir);

	String room = getAttribute(result, "roomnumber");

	if (room != null)
	    person.setRoom(room);

	String dept = getAttribute(result, "departmentnumber");

	if (dept != null)
	    person.setDepartment(dept);

	ImageIcon icon = getIconAttribute(result, "jpegphoto");

	if (icon != null)
	    person.setPhotograph(icon);

	uidToPerson.put(uid, person);

	return person;
    }

    private String getAttribute(Attributes attrs, String key) throws NamingException {
	Attribute attr = attrs.get(key);

	return (attr == null) ? null : (String)attr.get();
    }

    private ImageIcon getIconAttribute(Attributes attrs, String key) throws NamingException {
	Attribute attr = attrs.get(key);

	NamingEnumeration vals = attr.getAll();

	while (vals.hasMoreElements()) {
	    Object object = vals.nextElement();

	    if (object instanceof byte[]) {
		byte[] bytes = (byte[])object;
		ImageIcon icon = new ImageIcon(bytes);
		return icon;
	    }
	}

	return null;
    }
}
