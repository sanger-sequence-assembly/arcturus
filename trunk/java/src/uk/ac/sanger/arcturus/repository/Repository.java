package uk.ac.sanger.arcturus.repository;

import java.util.Date;

public class Repository {
	private String name;
	
	private String path = null;
	private Date date = null;
	private boolean online = false;
	private boolean writable = false;
	private long expires = 0L;
	
	public Repository(String name) {
		this.name = name;
	}
	
	public String getName() {
		return name;
	}
	
	public void setPath(String path) {
		this.path = path;
	}
	
	public String getPath() {
		return path;
	}
	
	public void setDate(Date date) {
		this.date = date;
	}
	
	public Date getDate() {
		return date;
	}
	
	public void setOnline(boolean online) {
		this.online = online;
	}
	
	public boolean isOnline() {
		return online;
	}
	
	public void setWritable(boolean writable) {
		this.writable = writable;
	}
	
	public boolean isWritable() {
		return writable;
	}
	
	public void setExpires(long expires) {
		this.expires = expires;
	}
	
	public boolean isExpired() {
		return System.currentTimeMillis() > expires;
	}
	
	public String toString() {
		return "Repository[name=\"" + name + "\", path=\"" + path +
			"\", date=\"" + date + "\", " + (online ? "ONLINE" : "OFFLINE") +
			", " + (writable ? "R/W" : "R/O") + "]";
	}
}
