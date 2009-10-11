package uk.ac.sanger.arcturus.gui.organismtree;

import uk.ac.sanger.arcturus.data.Organism;

public class OrganismNode extends OrganismTreeNode {
	private Organism organism;

	public OrganismNode(Organism organism) {
		super(organism, false, organism.getName());
		this.organism = organism;
	}

	public Organism getOrganism() {
		return organism;
	}

	public String getDescription() {
		return organism.getDescription();
	}
	
	public String toString() {
		return organism.getName() + " (" + organism.getDescription() + ")";
	}
}
