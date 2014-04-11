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

package uk.ac.sanger.arcturus.data;

public class SequenceToContigMapping extends GenericMapping<Sequence,Contig> implements SequenceToContigMappingI {

    public SequenceToContigMapping(Sequence readsequence, Contig contig, CanonicalMapping cm, 
    		                       int referenceOffset,int subjectOffset, Direction direction) {
		super(readsequence, contig, cm, referenceOffset, subjectOffset, direction);
	}
 
    public SequenceToContigMapping(Sequence readsequence, Contig contig, Alignment[] alignments) {
		super(readsequence, contig, alignments);
    }
 
    public SequenceToContigMapping(GenericMapping gm) {
		super(gm.getAlignments());
    }
   
    public Contig getContig() {
    	return getReference();
    }
    
    public Sequence getSequence() {
    	return getSubject();
    }
    
    public int getContigStartPosition() {
    	return referenceRange.getStart();
    }

    public int getContigEndPosition() {
    	return referenceRange.getEnd();
    }

    public AssembledFrom[] getAssembledFromRecords() {
    	Alignment[] alignments = getAlignments();
    	return Alignment.getAssembledFrom(alignments);
    }

    public BaseWithQuality getBaseAndQualityByContigPosition(int cpos) {
    	Sequence sequence = getSequence();
		if (sequence == null || sequence.getDNA() == null || sequence.getQuality() == null)
			return null;
		if (!referenceRange.contains(cpos))
			return null;
					
		report("CRTCM.getBaseAndQualityByContigPosition(" + cpos + ")");
		
		int deltaC = isForward() ? cpos - referenceOffset : referenceOffset - cpos;
		
		report("\tdeltaC = " + deltaC);
		
		int deltaR = cm.getSubjectPositionFromReferencePosition(deltaC);                                                               
		
		report("\tdeltaR = " + deltaR);
		
		if (deltaR < 0) {
			float rpos = (float)subjectOffset + cm.getPadPositionFromReferencePosition(deltaC);
			return getPadAndQualityByReadPosition(rpos);
		} else {
			int rpos = subjectOffset + deltaR;
			report("\trpos = " + rpos);
			return getBaseAndQualityByReadPosition(rpos);
		}		
    }
	
    public BaseWithQuality getBaseAndQualityByReadPosition(int rpos) {
    	Sequence sequence = getSequence();
		if (sequence == null || rpos < 1 || rpos > sequence.getLength())
			return null;
		
		byte[] dna = sequence.getDNA();
		byte[] quality = sequence.getQuality();
		
		char base = (char)(dna[rpos - 1]);
		int qvalue = (int)(quality[rpos - 1]);
		
		if (!isForward())
			base = Utility.complement(base);
		
		return new BaseWithQuality(base, qvalue);		
    }
    
	private void report(String message) {
		//System.err.println(message);
	}
	
	private BaseWithQuality getPadAndQualityByReadPosition(float rpos) {
		Sequence sequence = getSequence();
		if (rpos < 1 || rpos > sequence.getLength() - 1)
			return null;
		
		byte[] quality = sequence.getQuality();
		
		int rposLeft = (int)rpos - 1;
		int rposRight = rposLeft + 1;
		
		float dq = quality[rposRight] - quality[rposLeft];
		
		float dx = rpos - (int)rpos;
		
		float q = quality[rposLeft] + dx * dq;
		
		int qvalue = (int)q;
		
		return new BaseWithQuality(BaseWithQuality.STAR, qvalue);
	}
	
	// some place holders for the moment
	public int getQuality(int rpos) {
		return 0;
	}
	public int getReadOffset(int cpos) {
		return 0;
	}
	public int getPadQuality(int cpos) {
        return 0;
	}
}