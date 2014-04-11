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

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Template;

import java.util.Map;
import java.util.HashMap;

public class Bridge {
	public final static int LEFT = 0;
	public final static int RIGHT = 1;

	protected Contig contiga;
	protected Contig contigb;
	protected int endcode;

	protected Map links;
	protected GapSize gapsize;

	public Bridge(Contig contiga, Contig contigb, int endcode) {
		this.contiga = contiga;
		this.contigb = contigb;
		this.endcode = endcode;

		this.links = new HashMap();
		this.gapsize = new GapSize();
	}

	public Bridge(Contig contiga, int enda, Contig contigb, int endb) {
		this(contiga, contigb, ((enda == RIGHT) ? 0 : 2)
				+ ((endb == LEFT) ? 0 : 1));
	}

	public Contig getContigA() {
		return contiga;
	}

	public Contig getContigB() {
		return contigb;
	}

	public int getEndCode() {
		return endcode;
	}

	public Map getLinks() {
		return links;
	}

	public Template[] getTemplates() {
		return (Template[]) links.keySet().toArray(new Template[0]);
	}

	public int getLinkCount() {
		return links.size();
	}

	public void addLink(Template template, ReadMapping mappinga,
			ReadMapping mappingb, GapSize gapsize) {
		Link link = (Link) links.get(template);

		if (link == null) {
			link = new Link(template);
			links.put(template, link);
		}

		link.merge(mappinga, mappingb, gapsize);
		this.gapsize.add(gapsize);
	}

	public GapSize getGapSize() {
		return gapsize;
	}

	public int getEndA() {
		return (endcode < 2) ? RIGHT : LEFT;
	}

	public int getEndB() {
		return (endcode % 2 == 0) ? LEFT : RIGHT;
	}

	public String getEndString() {
		switch (endcode) {
			case 0:
				return "RL";
			case 1:
				return "RR";
			case 2:
				return "LL";
			case 3:
				return "LR";
			default:
				return "??";
		}
	}

	public String getEndArrows() {
		switch (endcode) {
			case 0:
				return "---> --->";
			case 1:
				return "---> <---";
			case 2:
				return "<--- --->";
			case 3:
				return "<--- <---";
			default:
				return "???? ????";
		}
	}

	public String toString() {
		return "Bridge[" + contiga.getID() + ", " + contigb.getID() + ", "
				+ endcode + " (" + getEndArrows() + "), " + links.size() + ", "
				+ gapsize + "]";
	}
}
