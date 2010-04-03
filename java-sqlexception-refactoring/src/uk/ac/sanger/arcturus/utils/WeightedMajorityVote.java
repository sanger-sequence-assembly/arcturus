package uk.ac.sanger.arcturus.utils;

public class WeightedMajorityVote implements ConsensusAlgorithm {
	private int totalA, totalC, totalG, totalT, totalX;
	private char bestbase;
	private int bestscore;
	private int readCount;

	public boolean reset() {
		totalA = totalC = totalG = totalT = totalX = 0;
		bestbase = '?';
		bestscore = -1;
		readCount = 0;

		return true;
	}

	public boolean addBase(char base, int quality, int strand, int chemistry) {
		switch (base) {
			case 'a':
			case 'A':
				totalA += quality;
				break;
			case 'c':
			case 'C':
				totalC += quality;
				break;
			case 'g':
			case 'G':
				totalG += quality;
				break;
			case 't':
			case 'T':
				totalT += quality;
				break;
			case '*':
				totalX += quality;
				break;
		}
		
		readCount++;

		return true;
	}

	private void findBestBase() {
		if (bestscore < 0) {
			bestbase = 'A';
			bestscore = totalA;

			if (totalC > bestscore) {
				bestbase = 'C';
				bestscore = totalC;
			}

			if (totalG > bestscore) {
				bestbase = 'G';
				bestscore = totalG;
			}

			if (totalT > bestscore) {
				bestbase = 'T';
				bestscore = totalT;
			}

			if (totalX > bestscore) {
				bestbase = '*';
				bestscore = totalX;
			}
		}
	}

	public char getBestBase() {
		findBestBase();
		return bestbase;
	}

	public int getBestScore() {
		findBestBase();
		return bestscore;
	}

	public int getScoreForBase(char base) {
		int value = 0;

		switch (base) {
			case 'a':
			case 'A':
				value = totalA;
			case 'c':
			case 'C':
				value = totalC;
			case 'g':
			case 'G':
				value = totalG;
			case 't':
			case 'T':
				value = totalT;
			case '*':
				value = totalX;
			default:
				value = 0;
		}

		if (value > 99)
			return 99;
		else
			return value;
	}
	
	public int getReadCount() {
		return readCount;
	}
}
