package uk.ac.sanger.arcturus.data;

import java.util.Vector;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ReadGroup extends Core {

	public ReadGroup( int read_group_id, int read_group_line_id, int import_id, String tag_name, String tag_value) {
		this.read_group_id = read_group_id;
		this.read_group_line_id = read_group_line_id;
		this.import_id = import_id;
		this.tag_name = tag_name;
		this.tag_value = tag_value;
	}

	protected int read_group_id = 0;
	protected int read_group_line_id  = 0;
	protected int import_id = 0;
	
	protected String tag_name = null;
	protected String tag_value = null;
	
	public int getRead_group_id() {
		return read_group_id;
	}

	public void setRead_group_id(int read_group_id) {
		this.read_group_id = read_group_id;
	}

	public int getImport_id() {
		return import_id;
	}

	public void setImport_id(int import_id) {
		this.import_id = import_id;
	}

	public int getRead_group_line_id() {
		return read_group_line_id;
	}

	public void setRead_group_line_id(int read_group_line_id) {
		this.read_group_line_id = read_group_line_id;
	}

	public String getTag_name() {
		return tag_name;
	}

	public void setTag_name(String tag_name) {
		this.tag_name = tag_name;
	}

	public String getTag_value() {
		return tag_value;
	}

	public void setTag_value(String tag_value) {
		this.tag_value = tag_value;
	}

}
