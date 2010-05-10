package uk.ac.sanger.arcturus.data;

import java.util.Arrays;

import uk.ac.sanger.arcturus.data.Utility;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;


public class CanonicalSequenceToContigMapping extends GenericMapping<Sequence, Contig> implements SequenceToContigMappingI {
	protected Contig contig;
	protected Sequence sequence;
	protected int contigOffset;
	protected int readOffset;
	protected Direction direction;
	protected CanonicalMapping mapping;
	protected Range contigRange;

	public CanonicalSequenceToContigMapping(Mapping mapping) {
		this.contig = mapping.getContig();
		this.sequence = mapping.getSequence();
		this.direction = mapping.getDirection();
		
		Segment[] segments = mapping.getSegments();
		
		if (direction == Direction.FORWARD) {
			Segment segment = segments[0];
			
			contigOffset = segment.getContigStart() - 1;
			readOffset = segment.getReadStart() - 1;
		} else {
			Segment segment = segments[segments.length - 1];
			
			contigOffset = segment.getContigFinish() + 1;
			readOffset = segment.getReadFinish(isForward()) - 1;
		}
		
		CanonicalSegment[] csegments = new CanonicalSegment[segments.length];
		
		for (int i = 0; i < segments.length; i++) {
			Segment segment = segments[i];
			
			int czero = isForward() ? segment.getContigStart() - contigOffset : contigOffset - segment.getContigFinish();
			
			int rzero = (isForward() ? segment.getReadStart() : segment.getReadFinish(false)) - readOffset;
			
			int length = segment.getLength();
			
			csegments[i] = new CanonicalSegment(czero, rzero, length);
		}
		
		this.mapping = new CanonicalMapping(0, csegments);
		
		calculateContigRange();
	}

	private void calculateContigRange() {
	}
	

	public BaseWithQuality getBaseAndQualityByContigPosition(int cpos) {
		if (!contigRange.contains(cpos) || sequence == null || sequence.getDNA() == null || sequence.getQuality() == null)
			return null;
		
		report("CRTCM.getBaseAndQualityByContigPosition(" + cpos + ")");
		
		int deltaC = isForward() ? cpos - contigOffset : contigOffset - cpos;
		
		report("\tdeltaC = " + deltaC);
		
		int deltaR = mapping.getReadPositionFromContigPosition(deltaC);
		
		report("\tdeltaR = " + deltaR);
		
		if (deltaR < 0) {
			float rpos = (float)readOffset + mapping.getPadPositionFromContigPosition(deltaC);
			return getPadAndQualityByReadPosition(rpos);
		} else {
			int rpos = readOffset + deltaR;
			report("\trpos = " + rpos);
			return getBaseAndQualityByReadPosition(rpos);
		}
	}
	
	private void report(String message) {
		//System.err.println(message);
	}

	public BaseWithQuality getBaseAndQualityByReadPosition(int rpos) {
		if (rpos < 1 || rpos > sequence.getLength())
			return null;
		
		byte[] dna = sequence.getDNA();
		byte[] quality = sequence.getQuality();
		
		char base = (char)(dna[rpos - 1]);
		int qvalue = (int)(quality[rpos - 1]);
		
		if (!isForward())
			base = Utility.complement(base);
		
		return new BaseWithQuality(base, qvalue);
	}
		
	private BaseWithQuality getPadAndQualityByReadPosition(float rpos) {
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
