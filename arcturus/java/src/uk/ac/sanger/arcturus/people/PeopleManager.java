package uk.ac.sanger.arcturus.people;

import java.util.*;

import javax.naming.*;
import javax.naming.directory.*;
import javax.swing.ImageIcon;
import java.awt.GraphicsEnvironment;

import uk.ac.sanger.arcturus.Arcturus;

public class PeopleManager {
	protected static DirContext ctx = null;

	protected static Map uidToPerson = new HashMap();
	protected static final String myUid ;
	protected static final Person me;
	protected static final String myRealUid;
	protected static final Person realMe;

	protected static final String[] attrs = { "cn", "sn", "givenname", "mail",
			"telephonenumber", "homedirectory", "roomnumber",
			"departmentnumber", "jpegphoto" };

	static {
		Properties props = new Properties();

		props.put(Context.INITIAL_CONTEXT_FACTORY, 
				Arcturus.getProperty(Context.INITIAL_CONTEXT_FACTORY));

		props.put(Context.PROVIDER_URL, 
				Arcturus.getProperty("arcturus.naming.people.url"));

		try {
			ctx = new InitialDirContext(props);
		} catch (NamingException ne) {
			ne.printStackTrace();
			ctx = null;
		}
		
		myRealUid = System.getProperty("user.name");
		realMe = findPerson(myRealUid);
	
		if (System.getProperty("user.alias") == null || !isAllowedToMasquerade()) {
			myUid = myRealUid;
			me = realMe;
		} else {
			myUid = System.getProperty("user.alias");
			me = findPerson(myUid);
		}
	}
	
	private static boolean isAllowedToMasquerade() {
		return myRealUid.equalsIgnoreCase("adh") || myRealUid.equalsIgnoreCase("ejz");
	}

	public static Person findPerson(String uid) {
		if (uid == null)
			return null;
		
		Person person = (Person) uidToPerson.get(uid);

		if (person != null)
			return person;

		person = new Person(uid);

		uidToPerson.put(uid, person);

		if (ctx == null)
			return person;

		String searchterm = "uid=" + uid;

		Attributes result = null;

		try {
			result = ctx.getAttributes(searchterm, attrs);
		} catch (NameNotFoundException nnfe) {
			result = null;
		} catch (NamingException ne) {
			ne.printStackTrace();
			result = null;
		}

		if (result != null) {
			String commonname = getAttribute(result, "cn");

			if (commonname != null)
				person.setName(commonname);

			String surname = getAttribute(result, "sn");

			if (surname != null)
				person.setSurname(surname);

			String givenname = getAttribute(result, "givenname");

			if (givenname != null)
				person.setGivenName(givenname);

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
		}

		return person;
	}

	public static Person findMe() {
		return me;
	}
	
	public static boolean isMe(Person person) {
		return me.equals(person);
	}
	
	public static Person findRealMe() {
		return realMe;
	}

	public static boolean isRealMe(Person person) {
		return realMe.equals(person);
	}

	public static boolean isMasquerading() {
		return ! me.equals(realMe);
	}
	
	private static String getAttribute(Attributes attrs, String key) {
		try {
			Attribute attr = attrs.get(key);

			return (attr == null) ? null : (String) attr.get();
		} catch (NamingException ne) {
			return null;
		}
	}

	private static ImageIcon getIconAttribute(Attributes attrs, String key) {
		try {
			if (GraphicsEnvironment.isHeadless())
				return null;

			Attribute attr = attrs.get(key);

			if (attr == null)
				return null;

			NamingEnumeration vals = attr.getAll();

			while (vals.hasMoreElements()) {
				Object object = vals.nextElement();

				if (object instanceof byte[]) {
					byte[] bytes = (byte[]) object;
					ImageIcon icon = new ImageIcon(bytes);
					return icon;
				}
			}

			return null;
		} catch (NamingException ne) {
			ne.printStackTrace();
			return null;
		}
	}
}
