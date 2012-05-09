package uk.ac.sanger.arcturus.consistencychecker;

class Test {
	
	
	private final String description;
	private final String query;
	private final String format;
	private final boolean critical;
	
	public Test(String description, String query, String format, boolean critical) {
		this.description = description;
		this.query = query;
		this.format = format;
		this.critical = critical;
	}
	
	public String getDescription() {
		return description;
	}
	
	public String getQuery() {
		return query;
	}
	
	public String getFormat() {
		return format;
	}
	
	public boolean isCritical() {
		return critical;
	}
	
	public String toString() {
		return "Test[description=\"" + description +
			"\", query=\"" + query +
			"\", format=\"" + format + "\"" +
			", critical=" + (critical ? "YES" : "NO") +
			"]";
	}

}