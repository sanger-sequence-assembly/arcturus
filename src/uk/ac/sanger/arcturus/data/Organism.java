package uk.ac.sanger.arcturus.data;

import javax.sql.DataSource;

public class Organism {
	protected String name;
	protected String description;
	protected DataSource datasource;

	public Organism(String name, String description, DataSource datasource) {
		this.name = name;
		this.description = description;
		this.datasource = datasource;
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

	public String toString() {
		return "Organism[name=" + name + ", description=" + description
				+ ", datasource=" + datasource + "]";
	}
}
