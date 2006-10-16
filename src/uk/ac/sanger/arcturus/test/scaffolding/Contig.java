package uk.ac.sanger.arcturus.test.scaffolding;

class Contig {
	private int id = -1;
	private int size = 0;
	private int project = -1;
	private boolean forward = true;

	public Contig(int id, int size, int project, boolean forward) {
		this.id = id;
		this.size = size;
		this.project = project;
		this.forward = forward;
	}

	public int getId() {
		return id;
	}

	public int getSize() {
		return size;
	}

	public int getProject() {
		return project;
	}

	public boolean isForward() {
		return forward;
	}

	public String toString() {
		return "Contig[id=" + id + ", size=" + size + ", project=" + project
				+ ", sense=" + (forward ? "F" : "R") + "]";
	}
}
