package uk.ac.sanger.arcturus.people;

import javax.swing.ImageIcon;

public class Person implements Comparable {
	protected String uid;
	protected String name;
	protected String surname;
	protected String givenname;
	protected String mail;
	protected String phone;
	protected String homedir;
	protected String room;
	protected String dept;
	protected ImageIcon photo;

	public Person(String uid) {
		this.uid = uid;
	}

	public String getUID() {
		return uid;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getName() {
		return name;
	}

	public void setSurname(String surname) {
		this.surname = surname;
	}

	public String getSurname() {
		return surname;
	}

	public void setGivenName(String givenname) {
		this.givenname = givenname;
	}

	public String getGivenName() {
		return givenname;
	}

	public void setMail(String mail) {
		this.mail = mail;
	}

	public String getMail() {
		return mail;
	}

	public void setTelephone(String phone) {
		this.phone = phone;
	}

	public String getTelephone() {
		return phone;
	}

	public void setHomeDirectory(String homedir) {
		this.homedir = homedir;
	}

	public String getHomeDirectory() {
		return homedir;
	}

	public void setRoom(String room) {
		this.room = room;
	}

	public String getRoom() {
		return room;
	}

	public void setDepartment(String dept) {
		this.dept = dept;
	}

	public String getDepartment() {
		return dept;
	}

	public void setPhotograph(ImageIcon photo) {
		this.photo = photo;
	}

	public ImageIcon getPhotograph() {
		return photo;
	}

	public String toString() {
		String string = "Person[uid=" + uid;

		if (name != null)
			string += ", name=" + name;

		if (mail != null)
			string += ", mail=" + mail;

		if (phone != null)
			string += ", telephone=" + phone;

		if (homedir != null)
			string += ", homedirectory=" + homedir;

		if (room != null)
			string += ", room=" + room;

		if (dept != null)
			string += ", department=" + dept;

		if (photo != null)
			string += ", photo=ImageIcon[" + photo.getIconWidth() + "x"
					+ photo.getIconHeight() + "]";

		string += "]";

		return string;
	}

	public int compareTo(Object o) {
		Person that = (Person) o;

		if (surname != null && that.surname != null) {
			int diff = surname.compareToIgnoreCase(that.surname);

			if (diff != 0)
				return diff;

			if (givenname != null && that.givenname != null)
				return givenname.compareToIgnoreCase(that.givenname);
			else
				return 0;
		}

		return uid.compareToIgnoreCase(that.uid);
	}
	
	public boolean equals(Object that) {
		if (that instanceof Person && that != null)
			return ((Person)that).uid.equalsIgnoreCase(uid);
		else
			return false;
	}
}