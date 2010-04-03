package uk.ac.sanger.arcturus.people;

import javax.swing.ImageIcon;

import uk.ac.sanger.arcturus.people.role.Role;

public class Person implements Comparable, Role {
	public static final String NOBODY = "nobody";
	
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
	
	protected Role role;

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
	
	public boolean isNobody() {
		return uid.equalsIgnoreCase(NOBODY);
	}
	
	public void setRole(Role role) {
		this.role = role;
	}
	
	public Role getRole() {
		return role;
	}

	public String toString() {
		return name == null ? uid : name;
	}

	public int compareTo(Object o) {
		Person that = (Person) o;
		
		if (isNobody())
			return 1;
		
		if (that.isNobody())
			return -1;

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
		if (that instanceof Person && that != null  && ((Person)that).uid != null)
			return ((Person)that).uid.equalsIgnoreCase(uid);
		else
			return false;
	}

	public boolean canAssignProject() {
		return role == null ? false : role.canAssignProject();
	}

	public boolean canCreateProject() {
		return role == null ? false : role.canCreateProject();
	}

	public boolean canLockProject() {
		return role == null ? false : role.canLockProject();
	}

	public boolean canMoveAnyContig() {
		return role == null ? false : role.canMoveAnyContig();
	}
}
