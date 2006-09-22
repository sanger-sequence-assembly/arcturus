package uk.ac.sanger.arcturus.test.scaffolding;

class SuperScaffold extends Core {
    private int id = -1;
    private int size = 0;

    public SuperScaffold(int id, int size) {
	this.id = id;
	this.size = size;
    }

    public int getId() { return id; }

    public int getSize() { return size; }

    public String toString() {
	return "SuperScaffold[id=" + id + ", size=" + size + "]";
    }
}
