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

import java.util.Date;

public class ProjectSummary {
	protected int numberOfContigs = 0;
	protected int numberOfReads = 0;
	protected int totalConsensusLength = 0;
	protected int meanConsensusLength = 0;
	protected int sigmaConsensusLength = 0;
	protected int maximumConsensusLength = 0;
	protected Date newestContigCreated = null;
	protected Date mostRecentContigUpdated = null;
	protected Date mostRecentContigTransferOut = null;

	public void reset() {
		numberOfContigs = 0;
		numberOfReads = 0;
		totalConsensusLength = 0;
		meanConsensusLength = 0;
		sigmaConsensusLength = 0;
		maximumConsensusLength = 0;
		newestContigCreated = null;
		mostRecentContigUpdated = null;
		mostRecentContigTransferOut = null;
	}

	public void setNumberOfContigs(int numberOfContigs) {
		this.numberOfContigs = numberOfContigs;
	}

	public int getNumberOfContigs() {
		return numberOfContigs;
	}

	public void setNumberOfReads(int numberOfReads) {
		this.numberOfReads = numberOfReads;
	}

	public int getNumberOfReads() {
		return numberOfReads;
	}

	public void setTotalConsensusLength(int totalConsensusLength) {
		this.totalConsensusLength = totalConsensusLength;
	}

	public int getTotalConsensusLength() {
		return totalConsensusLength;
	}

	public void setMeanConsensusLength(int meanConsensusLength) {
		this.meanConsensusLength = meanConsensusLength;
	}

	public int getMeanConsensusLength() {
		return meanConsensusLength;
	}

	public void setSigmaConsensusLength(int sigmaConsensusLength) {
		this.sigmaConsensusLength = sigmaConsensusLength;
	}

	public int getSigmaConsensusLength() {
		return sigmaConsensusLength;
	}

	public void setMaximumConsensusLength(int maximumConsensusLength) {
		this.maximumConsensusLength = maximumConsensusLength;
	}

	public int getMaximumConsensusLength() {
		return maximumConsensusLength;
	}

	public void setNewestContigCreated(Date created) {
		this.newestContigCreated = created;
	}

	public Date getNewestContigCreated() {
		return newestContigCreated;
	}

	public void setMostRecentContigUpdated(Date updated) {
		this.mostRecentContigUpdated = updated;
	}

	public Date getMostRecentContigUpdated() {
		return mostRecentContigUpdated;
	}
	
	public void setMostRecentContigTransferOut(Date transferred) {
		this.mostRecentContigTransferOut = transferred;
	}
	
	public Date getMostRecentContigTransferOut() {
		return mostRecentContigTransferOut;
	}
}
