package uk.ac.sanger.arcturus.data;

import javax.sql.DataSource;

import uk.ac.sanger.arcturus.ArcturusInstance;

public class Organism {
	protected String name;
	protected String description;
	protected DataSource datasource;
	protected ArcturusInstance instance;

	public Organism(String name, String description, DataSource datasource, ArcturusInstance instance) {
		this.name = name;
		this.description = description;
		this.datasource = datasource;
		this.instance = instance;
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
	
	public ArcturusInstance getInstance() {
		return instance;
	}

	public String toString() {
		return "Organism[name=" + name + ", description=" + description
				+ ", datasource=" + datasource + "]";
	}
}
