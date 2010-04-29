package uk.ac.sanger.arcturus.data;

import java.util.Arrays;

public class CanonicalReadToContigMapping implements ReadToContigMapping, Comparable<CanonicalReadToContigMapping> {
	protected Contig contig;
	protected Sequence sequence;
	protected int contigOffset;
	protected int readOffset;
	protected Direction direction;
	protected CanonicalMapping mapping;
	protected Range contigRange;

	public CanonicalReadToContigMapping(Contig contig, Sequence sequence,
			int contigOffset, int readOffset, Direction direction,
			CanonicalMapping mapping) {
		this.contig = contig;
		this.sequence = sequence;
		this.contigOffset = contigOffset;
		this.readOffset = readOffset;
		this.direction = direction;
		this.mapping = mapping;
		calculateContigRange();
	}
	
	public CanonicalReadToContigMapping(Contig contig, Sequence sequence, AssembledFrom[] afdata) {
		this.contig = contig;
		this.sequence = sequence;

		Arrays.sort(afdata);
		
		direction = AssembledFrom.getDirection(afdata);
		
		readOffset = afdata[0].getReadRange().getStart() - 1;
		
		contigOffset = afdata[0].getContigRange().getStart();
		
		if (direction == Direction.FORWARD)
			contigOffset -= 1;
		else
			contigOffset += 1;
		
		CanonicalSegment[] segments = new CanonicalSegment[afdata.length];
		
		for (int i = 0; i < afdata.length; i++) {
			AssembledFrom af = afdata[i];
			
			int rstart = af.getReadRange().getStart();
			int cstart = af.getContigRange().getStart();
			int length = af.getReadRange().getLength();
			
			rstart -= readOffset;
			cstart -= contigOffset;
			
			if (direction == Direction.REVERSE)
				cstart = -cstart;
			
			segments[i] = new CanonicalSegment(cstart, rstart, length);
		}
		
		mapping = new CanonicalMapping(0, segments);

		calculateContigRange();
	}
	
	public CanonicalReadToContigMapping(Mapping mapping) {
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
		int cstart = isForward() ? contigOffset + 1 : contigOffset - mapping.getContigSpan();
		int cfinish = isForward() ? contigOffset + mapping.getContigSpan() : contigOffset - 1;
		
		this.contigRange = new Range(cstart, cfinish);
	}
	
	public AssembledFrom[] getAssembledFromRecords() {
		CanonicalSegment[] segments = mapping.getSegments();
		
		int nSegments = segments.length;
		
		AssembledFrom[] afdata = new AssembledFrom[nSegments];
		
		boolean forward = isForward();
		
		for (int i = 0; i < nSegments; i++) {
			CanonicalSegment segment = segments[i];
			
			int length = segment.getLength();
			
			int readStart = readOffset + segment.getReadStart();
			int readFinish = readStart + length - 1;
			
			int contigStart = forward ? contigOffset + segment.getContigStart() : contigOffset - segment.getContigStart();
			int contigFinish = forward ? contigStart + length - 1 : contigStart - (length - 1); 
			
			Range readRange = new Range(readStart, readFinish);
			Range contigRange = new Range(contigStart, contigFinish);
			
			afdata[i] = new AssembledFrom(contigRange, readRange);
		}
		
		Arrays.sort(afdata);
		
		return afdata;
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
			base = complement(base);
		
		return new BaseWithQuality(base, qvalue);
	}
	
	private char complement(char base) {
		switch (base) {
		case 'a':
			return 't';
			
		case 'A':
			return 'T';
			
		case 'c':
			return 'g';
			
		case 'C':
			return 'G';
			
		case 'g':
			return 'c';
			
		case 'G':
			return 'C';
			
		case 't':
			return 'a';
			
		case 'T':
			return 'A';
			
		default:
			return base;
		}
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
	
	public int getContigStartPosition() {
		return contigRange.getStart();
	}

	public int getContigEndPosition() {
		return contigRange.getEnd();
	}

	public Sequence getSequence() {
		return sequence;
	}

	public boolean isForward() {
		return direction == Direction.FORWARD;
	}
	
	public Direction getDirection() {
		return direction;
	}

	public Contig getContig() {
		return contig;
	}
	
	public int getReadOffset() {
		return readOffset;
	}
	
	public int getContigOffset() {
		return contigOffset;
	}
	
	public CanonicalMapping getCanonicalMapping() {
		return mapping;
	}

	public int compareTo(CanonicalReadToContigMapping that) {
		return this.getContigStartPosition() - that.getContigStartPosition();
	}

}
