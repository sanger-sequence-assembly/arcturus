package uk.ac.sanger.arcturus.test.scaffolding;


class Scaffold extends Core {
    private int id = -1;
    private boolean forward = true;

    public Scaffold(int id, boolean forward) {
	this.id = id;
	this.forward = forward;
    }

    public int getId() { return id; }

    public boolean isForward() { return forward; }

    public String toString() {
	return "Scaffold[id=" + id + ", sense=" +
	    (forward ? "F" : "R") + "]";
    }
}
