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

    public void reset() {
	numberOfContigs = 0;
	numberOfReads = 0;
	totalConsensusLength = 0;
	meanConsensusLength = 0;
	sigmaConsensusLength = 0;
	maximumConsensusLength = 0;
	newestContigCreated = null;
	mostRecentContigUpdated = null;
    }

    public void setNumberOfContigs(int numberOfContigs) {
	this.numberOfContigs = numberOfContigs;
    }

    public int getNumberOfContigs() { return numberOfContigs; }

    public void setNumberOfReads(int numberOfReads) {
	this.numberOfReads = numberOfReads;
    }

    public int getNumberOfReads() { return numberOfReads; }

    public void setTotalConsensusLength(int totalConsensusLength) {
	this.totalConsensusLength = totalConsensusLength;
    }

    public int getTotalConsensusLength() { return totalConsensusLength; }

    public void setMeanConsensusLength(int meanConsensusLength) {
	this.meanConsensusLength = meanConsensusLength;
    }

    public int getMeanConsensusLength() { return meanConsensusLength; }

    public void setSigmaConsensusLength(int sigmaConsensusLength) {
	this.sigmaConsensusLength = sigmaConsensusLength;
    }

    public int getSigmaConsensusLength() { return sigmaConsensusLength; }


    public void setMaximumConsensusLength(int maximumConsensusLength) {
	this.maximumConsensusLength = maximumConsensusLength;
    }

    public int getMaximumConsensusLength() { return maximumConsensusLength; }

    public void setNewestContigCreated(Date created) {
	this.newestContigCreated = created;
    }

    public Date getNewestContigCreated() { return newestContigCreated; }

    public void setMostRecentContigUpdated(Date updated) {
	this.mostRecentContigUpdated = updated;
    }

    public Date getMostRecentContigUpdated() { return mostRecentContigUpdated; }
}
