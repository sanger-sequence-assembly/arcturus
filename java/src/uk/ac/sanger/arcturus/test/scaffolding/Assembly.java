package uk.ac.sanger.arcturus.test.scaffolding;

import java.util.Date;
import java.text.SimpleDateFormat;
import java.text.ParseException;

class Assembly extends Core {
	private String instance = null;
	private String organism = null;
	private Date created = null;

	public Assembly(String instance, String organism, String created) {
		this.instance = instance;
		this.organism = organism;
		SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-DD HH:mm:ss");
		try {
			this.created = df.parse(created);
		} catch (ParseException pe) {
			System.err.println("ParseException parsing \"" + created + "\"");
			this.created = null;
		}
	}

	public String getInstance() {
		return instance;
	}

	public String getOrganism() {
		return organism;
	}

	public Date getCreated() {
		return created;
	}

	public String toString() {
		return "Assembly[instance=" + instance + ", organism=" + organism
				+ ", created=" + created + "]";
	}
}
