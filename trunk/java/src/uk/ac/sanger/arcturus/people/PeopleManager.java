package uk.ac.sanger.arcturus.people;

import java.util.*;

import javax.naming.*;
import javax.naming.directory.*;
import javax.swing.ImageIcon;
import java.awt.GraphicsEnvironment;

import uk.ac.sanger.arcturus.Arcturus;

public class PeopleManager {
	protected static DirContext ctx = null;

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
	}

	public static Person createPerson(String uid) {
		if (uid == null)
			return null;

		Person person = new Person(uid);

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

	public static String getEffectiveUID() {
		String alias = System.getProperty("user.alias");
		String username = System.getProperty("user.name");

		if (alias != null && canMasquerade(username))
			username = alias;

		return username;
	}
	
	public static String getRealUID() {
		return System.getProperty("user.name");
	}

	public static boolean canMasquerade(String username) {
		return username.equalsIgnoreCase("adh")
				|| username.equalsIgnoreCase("ejz");
	}
	
	public static boolean canMasquerade() {
		return canMasquerade(System.getProperty("user.name"));
	}
	
	public static boolean isMasquerading() {
		String alias = System.getProperty("user.alias");
		String username = System.getProperty("user.name");

		return alias != null && canMasquerade(username) && !alias.equalsIgnoreCase(username);
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
