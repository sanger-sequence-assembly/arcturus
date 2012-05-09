package uk.ac.sanger.arcturus.sequencingproject;

import javax.sql.DataSource;

public class SequencingProject implements Comparable<SequencingProject> {
	protected String instance;
	protected String path;
	protected String name;
	protected String description;
	protected DataSource datasource;
	
	public SequencingProject(String instance, String path, String name, String description, DataSource datasource) {
		this.instance = instance;
		this.path = path;
		this.name = name;
		this.description = description;
		this.datasource = datasource;
	}
	
	public String getInstance() {
		return instance;
	}
	
	public String getPath() {
		return path;
	}
	
	public String getName() {
		return name;
	}
	
	public String getDescription() {
		return description;
	}
	
	public DataSource getDataSource() {
		return datasource;
	}

	public int compareTo(SequencingProject that) {
		int diff = compareString(this.instance, that.instance);
		
		if (diff != 0)
			return diff;
		
		diff = compareString(this.path, that.path);
		
		if (diff != 0)
			return diff;
		
		return compareString(this.name, that.name);
	}
	
	private int compareString(String str1, String str2) {
		if (str1 == null && str2 == null)
			return 0;
		
		if (str1 == null && str2 != null)
			return -1;
		
		if (str1 != null && str2 == null)
			return 1;
		
		return str1.compareTo(str2);
	}

	public String toString() {
		return "SequencingProject[instance=" + instance + ", path=" + path + ", name=" + name +
			", description=" + description + ", datasource=" + datasource + "]";
	}
}
