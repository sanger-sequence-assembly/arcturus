package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.data.Template;

import java.util.*;

public class Link {
	protected Template template;
	protected Set mappingsA = new HashSet();
	protected Set mappingsB = new HashSet();
	protected GapSize gapsize = new GapSize();

	public Link(Template template) {
		this.template = template;
	}

	public Template getTemplate() {
		return template;
	}

	public Set getMappingsA() {
		return mappingsA;
	}

	public Set getMappingsB() {
		return mappingsB;
	}

	public GapSize getGapSize() {
		return gapsize;
	}

	public boolean addMappingA(ReadMapping mapping) {
		return addMappingToSet(mappingsA, mapping);
	}

	public boolean addMappingB(ReadMapping mapping) {
		return addMappingToSet(mappingsB, mapping);
	}

	private boolean addMappingToSet(Set set, ReadMapping mapping) {
		for (Iterator iterator = set.iterator(); iterator.hasNext();) {
			ReadMapping rm = (ReadMapping) iterator.next();
			if (rm.equals(mapping))
				return false;
		}

		set.add(mapping);

		return true;
	}

	public void merge(ReadMapping mappinga, ReadMapping mappingb,
			GapSize newgapsize) {
		addMappingA(mappinga);
		addMappingB(mappingb);
		gapsize.add(newgapsize);
	}

	public String toString() {
		return "Link[template=" + template.getName() + ", " + mappingsA.size()
				+ " A mappings, " + mappingsB.size() + " B mappings, gapsize="
				+ gapsize + "]";
	}
}
