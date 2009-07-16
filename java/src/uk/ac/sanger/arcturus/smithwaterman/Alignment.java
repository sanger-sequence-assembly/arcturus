package uk.ac.sanger.arcturus.smithwaterman;

public class Alignment {
	private int row;
	private int column;
	private EditEntry[] edits;
	
	public Alignment(int row, int column, EditEntry[] edits) {
		this.row = row;
		this.column = column;
		this.edits = edits;
	}
	
	public int getRow() {
		return row;
	}
	
	public int getColumn() {
		return column;
	}
	
	public EditEntry[] getEdits() {
		return edits;
	}
}
