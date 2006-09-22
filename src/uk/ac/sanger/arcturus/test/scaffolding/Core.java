package uk.ac.sanger.arcturus.test.scaffolding;

import java.util.Vector;
import java.util.Enumeration;
import java.io.PrintStream;

class Core {
    protected Vector children = new Vector();

    public void add(Object object) {
	children.add(object);
    }

    public int getChildCount() {
	return children.size();
    }

    public Enumeration elements() {
	return children.elements();
    }

    public Object[] toArray() {
	return children.toArray();
    }

    public void displayIndented(String prefix, int indentLevel, PrintStream ps) {
	for (int i = 0; i < indentLevel; i++)
	    ps.print(prefix);

	ps.println(this);

	if (children.size() > 0) {
	    ps.println();

	    for (int i = 0; i < indentLevel; i++)
		ps.print(prefix);

	    ps.println(prefix + "CONTAINS");

	    for (Enumeration e = children.elements(); e.hasMoreElements() ;) {
		Object child = e.nextElement();
		if (child instanceof Core) {
		    ps.println();
		    Core coreChild = (Core)child;

		    coreChild.displayIndented(prefix, indentLevel + 1, ps);
		} else {
		    ps.println();
		    for (int i = 0; i < indentLevel + 1; i++)
			ps.print(prefix);
		    ps.println(child);
		}
	    }
	}
    }
}
