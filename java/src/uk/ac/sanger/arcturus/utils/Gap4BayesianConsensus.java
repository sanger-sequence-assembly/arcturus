package uk.ac.sanger.arcturus.utils;

import java.io.PrintStream;
import java.text.DecimalFormat;

// This class implements the Gap4 Bayesian consensus algorithm, or something which
// closely approximates it.
//
// See the function process_frags in src/gap4/qual.c in the Staden package for the
// definitive version.

public class Gap4BayesianConsensus implements ConsensusAlgorithm {
	private static int[] DEPENDENT_TABLE = { 0, 0, 7, 14, 21, 28, 35, 41, 45, 58, 49 };
	private static String BASECODES = "ACGT*-";

	private static final int BASE_A = 0;
	private static final int BASE_C = 1;
	private static final int BASE_G = 2;
	private static final int BASE_T = 3;
	private static final int BASE_PAD = 4;
	private static final int BASE_DASH = 5;

	private boolean pad_present = false;
	private boolean best_is_current = true;
	private int qhighest[][] = new int[6][4];
	private int qcount[][] = new int[6][4];
	private int depth = 0;
	private double bayesian[][] = new double[5][30];
	private int bestbase = -1;
	private double probs[] = new double[6];
	private int scores[] = new int[6];
	private int nEvents = 0;
	private DecimalFormat decimal = new DecimalFormat("0.0000000000");
	
	private int forcedBestBase;
	private boolean useForcedBestBase;

	private final static double LOG10 = Math.log(10.0);
	
	private boolean logging = Boolean.getBoolean("debug");

	public boolean reset() {
		if (logging)
			logInfo("Gap4BayesianConsensus::reset");


		bestbase = -1;
		depth = 0;
		
		useForcedBestBase = false;

		pad_present = false;
		best_is_current = true;

		for (int i = 0; i < 6; i++)
			for (int j = 0; j < 4; j++)
				qhighest[i][j] = qcount[i][j] = 0;

		for (int j = 0; j < 6; j++)
			scores[j] = 0;

		nEvents = 0;

		return true;
	}

	public boolean addBase(char base, int quality, int strand, int chemistry) {
		if (logging)
			logInfo("Gap4BayesianConsensus::addBase(" + base + ", "
					+ quality + ", " + strand + ", " + chemistry + ")");

		if (strand == ConsensusAlgorithm.UNKNOWN
				|| chemistry == ConsensusAlgorithm.UNKNOWN)
			return false;

		// iBase is the first index into the arrays "qhighest" and "qcount"
		//
		// 0 -> A
		// 1 -> C
		// 2 -> G
		// 3 -> T
		// 4 -> *
		// 5 -> -

		int iBase = BASE_DASH;

		switch (base) {
			case 'a':
			case 'A':
				iBase = BASE_A;
				break;
				
			case 'c':
			case 'C':
				iBase = BASE_C;
				break;
				
			case 'g':
			case 'G':
				iBase = BASE_G;
				break;
				
			case 't':
			case 'T':
				iBase = BASE_T;
				break;
				
			case '*':
				iBase = BASE_PAD;
				break;
				
			case '-':
				iBase = BASE_DASH;
				break;
				
			default:
				iBase = BASE_DASH;
				break;				
		}

		if (logging)
			logInfo("  iBase = " + iBase);

		// iStrandAndChemistry is the second index into the arrays "qhighest"
		// and "qcount"
		//
		// 0 -> Forward strand, Primer
		// 1 -> Reverse strand, Primer
		// 2 -> Forward strand, Terminator
		// 3 -> Reverse strand, Terminator

		int iStrandAndChemistry = 0;
		iStrandAndChemistry |= (strand == ConsensusAlgorithm.FORWARD ? 0 : 1);
		iStrandAndChemistry |= (chemistry == ConsensusAlgorithm.PRIMER ? 0 : 1) << 1;

		if (logging)
			logInfo("  iStrandAndChemistry = " + iStrandAndChemistry);

		// FROM qual.c:
		//
		// qual == 1 implies less likely to be the called base. We map this to
		// 2, as
		// this is undesirable.

		if (quality == 1)
			quality = 2;

		// FROM qual.c:
		//
		// qual == 0 implies "ignore this base". We do this by changing the type
		// to dash,
		// to force even spread of probability. Otherwise, we'd actually be
		// negatively
		// weighting this base type.

		if (quality == 0)
			iBase = BASE_DASH;
		
		if (quality >= 100) {
			forcedBestBase = iBase;
			useForcedBestBase = true;
		}

		// Check the quality against the current maximum value for this base and
		// strand/chemistry

		if (quality > qhighest[iBase][iStrandAndChemistry])
			qhighest[iBase][iStrandAndChemistry] = quality;

		qcount[iBase][iStrandAndChemistry]++;

		depth++;

		if (logging) {
			logInfo("  qhighest[" + iBase + "][" + iStrandAndChemistry
					+ "] = " + qhighest[iBase][iStrandAndChemistry]);
			logInfo("  qCount[" + iBase + "][" + iStrandAndChemistry
					+ "] = " + qcount[iBase][iStrandAndChemistry]);
		}

		if (iBase == BASE_PAD)
			pad_present = true;

		best_is_current = false;

		return true;
	}

	private void findBestBase() {
		if (best_is_current)
			return;

		if (logging)
			logInfo("Gap4BayesianConsensus::findBestBase()");
		
		if (useForcedBestBase) {
			bestbase = forcedBestBase;
			best_is_current = true;
			return;
		}

		int nbase_types = pad_present ? 5 : 4;
		
		if (logging)
			logInfo("  nbase_types = " + nbase_types);

		for (int k = 0; k < 4; k++) {
			if (qhighest[5][k] > 0) {
				double tmp = (double) (qhighest[5][k] +
						DEPENDENT_TABLE[Math.min(qcount[5][k], 10)]);
				
				double prob = 1.0 - Math.exp(-LOG10 * tmp / 10.0);

				double sharedprob = prob / (double) nbase_types;

				for (int i = 0; i < nbase_types; i++)
					bayesian[i][nEvents] = sharedprob;

				if (logging) {
					logInfo("  qhighest[5][" + k + "] = "
							+ qhighest[5][k]);
					logInfo("  qcount[5][" + k + "] = " + qcount[5][k]);
					logInfo("  score = " + tmp);
					logInfo("  Sharing probability "
							+ decimal.format(sharedprob) + " amongst "
							+ nbase_types + " base types");
				}

				nEvents++;
			}
		}

		for (int j = 0; j < nbase_types; j++) {
			for (int k = 0; k < 4; k++) {
				if (qhighest[j][k] > 0) {
					double tmp = (double) (qhighest[j][k] +
							DEPENDENT_TABLE[Math.min(qcount[j][k], 10)]);
					
					double prob = Math.exp(-LOG10 * tmp / 10.0);

					double sharedprob = prob / (double) (nbase_types - 1);

					prob = 1.0 - prob;

					for (int i = 0; i < 5; i++)
						bayesian[i][nEvents] = sharedprob;

					bayesian[j][nEvents] = prob;

					if (logging) {
						logInfo("  qhighest[" + j + "][" + k + "] = "
								+ qhighest[j][k]);
						logInfo("  qcount[" + j + "][" + k + "] = "
								+ qcount[j][k]);
						logInfo("  score = " + tmp);
						logInfo("  Assigning probability "
								+ decimal.format(prob) + " to base " + j);
						logInfo("  Sharing probability "
								+ decimal.format(sharedprob)
								+ " amongst other bases");
					}

					nEvents++;
				}
			}
		}

		double qnorm = 0.0;
		double highest_product = 0.0;
		bestbase = 5;

		if (logging) {
			switch (nEvents) {
				case 0:
					logInfo("There are NO independent events for the Bayesian calculation");
					break;
				case 1:
					logInfo("There is one independent event for the Bayesian calculation");
					break;
				default:
					logInfo("There are " + nEvents
							+ " independent events for the Bayesian calculation");
					break;
			}
		}

		if (nEvents > 0) {
			for (int j = 0; j < nbase_types; j++) {
				double product = 1.0;

				for (int k = 0; k < nEvents; k++)
					product *= bayesian[j][k];

				qnorm += product;

				probs[j] = product;

				if (product > highest_product) {
					highest_product = product;
					bestbase = j;
				}
			}

			for (int j = 0; j < nbase_types; j++) {
				probs[j] /= qnorm;
				if (probs[j] < 1.0) {
					double log10probs = Math.log(1.0 - probs[j]) / LOG10;
					scores[j] = (int) Math.round(-10.0 * log10probs);
					if (scores[j] > 99)
						scores[j] = 99;
				} else
					scores[j] = 99;

				if (logging) {
					logInfo("  Normalised probability and score for base "
									+ j
									+ " = "
									+ decimal.format(probs[j])
									+ ", " + scores[j]);
				}
			}
		}
		
		if (bestbase < 4 && scores[bestbase] < 2) {		
			bestbase = 5;
			scores[bestbase] = 2;
		}

		best_is_current = true;
	}

	public char getBestBase() {
		findBestBase();
		
		return (bestbase < 0) ? '*' : BASECODES.charAt(bestbase);
	}

	public int getBestScore() {
		findBestBase();

		if (bestbase < 0)
			return 0;
		else {
			if (useForcedBestBase)
				return forcedBestBase == BASE_DASH ? 0 : 100;
			else
				return scores[bestbase];
		}
	}

	public int getScoreForBase(char base) {
		findBestBase();
		
		if (useForcedBestBase)
			return forcedBestBase == BASE_DASH ? 0 : 100;

		switch (base) {
			case 'a':
			case 'A':
				return scores[BASE_A];
			case 'c':
			case 'C':
				return scores[BASE_C];
			case 'g':
			case 'G':
				return scores[BASE_G];
			case 't':
			case 'T':
				return scores[BASE_T];
			case '*':
				return scores[BASE_PAD];
			case '-':
				return scores[BASE_DASH];
			default:
				return -1;
		}
	}
	
	public int getReadCount() {
		return depth;
	}
	
	private void logInfo(String message) {
		System.err.println(message);
	}
}
