// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
