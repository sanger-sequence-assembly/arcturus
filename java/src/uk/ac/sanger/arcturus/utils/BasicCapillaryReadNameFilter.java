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

package uk.ac.sanger.arcturus.utils;

/**
 * 
 * @author adh
 *
 * BasicCapillaryReadNameFilter is a very basic read name filter which identifies
 * reads which are likely to be capillary reads.  It uses the Sanger read-naming
 * convention, in which shotgun capillary read names always end with .p1k or .q1k.
 */

public class BasicCapillaryReadNameFilter implements ReadNameFilter {
	public boolean accept(String filename) {
		return filename != null && (filename.endsWith(".p1k") || filename.endsWith(".q1k"));
	}

}
