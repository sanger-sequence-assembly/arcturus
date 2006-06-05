#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct tagSWData {
  int score;
  int pointer;
} SWData;

typedef struct tagSegment {
  int startA;
  int endA;
  int startB;
  int endB;
} Segment;

#define SW_UNDEFINED 0
#define SW_DIAGONAL  1
#define SW_LEFT      2
#define SW_UP        3

char *direction[4] = {
  "undefined",
  "diagonal",
  "left",
  "up"
};

#ifndef SMATCH
#define SMATCH 1
#endif

#ifndef SMISMATCH
#define SMISMATCH -1
#endif

#ifndef SGAPINIT
#define SGAPINIT (SMISMATCH-2)
#endif

#ifndef SGAPEXT
#define SGAPEXT (SMISMATCH-1)
#endif

#define MAXSEQLEN 1024*1024
#define MAXEDITLEN (MAXSEQLEN*2)
#define MAXSEGMENTS 4096

int readSequence(FILE *fp, char *seqbuf, int seqbufsize) {
  char buffer[MAXSEQLEN];
  char *cp = seqbuf;
  int bases = 0;
  int len;

  while (fgets(buffer, sizeof(buffer), fp)) {
    if (buffer[0] == '.')
      break;

    len = strlen(buffer);
    buffer[len] = '\0';

    len--;

    if (bases + len >= seqbufsize)
      return -1;

    strcpy(cp, buffer);

    cp += len;
    bases += len;
  }

  return bases;
}

static void resizeSmithWatermanMatrix(SWData **swbase, int *swsize,
				      SWData ***swmatbase, int *swmatbasesize,
				      int xlen, int ylen) {
  int newswsize = (xlen + 1) * (ylen + 1);
  int newswmatbasesize = ylen + 1;
  int iy;
  SWData **swmat, *swp;

  if (!(*swbase) || (newswsize > *swsize)) {
    if (*swbase)
      free(*swbase);

    *swbase = (SWData *)calloc((size_t)newswsize, (size_t)(sizeof(SWData)));
 
    if (*swbase)
      *swsize = newswsize;
    else
      *swsize = 0;
  }

  if (!(*swmatbase) || (newswmatbasesize > *swmatbasesize)) {
    if (*swmatbase)
      free(*swmatbase);

    *swmatbase = (SWData **)calloc((size_t)newswmatbasesize, (size_t)sizeof(SWData *));

    if (*swmatbase)
      *swmatbasesize = newswmatbasesize;
    else
      *swmatbasesize = 0;
  }

  swmat = *swmatbase;
  swp = *swbase;

  for (iy = 0; iy <= ylen; iy++) {
    swmat[iy] = swp;
    swp += xlen + 1;
  }
}

int main(int argc, char **argv) {
  char xseq[MAXSEQLEN],yseq[MAXSEQLEN], xc, yc, *c, *cc, *cp, edit[MAXEDITLEN];
  char xname[80], yname[80];
  SWData *swbase = NULL, *swp, **swmatbase = NULL, **swmat;
  int swbasesize = 0;
  int xlen, ylen, score, swsize = 0;
  int x0, y0, j0;
  int diagonal, up, left;
  int sMatch = SMATCH,
      sMismatch = SMISMATCH,
      sGapInit = SGAPINIT,
      sGapExt = SGAPEXT;
  int maxgapscore, maxscore = 0, xmax, ymax;
  char **aptr = argv;
  Segment *segments;
  int maxsegs = MAXSEGMENTS;
  int nSegments;
  int startA, endA, startB, endB;
  int inSegment, isMatch;
  int ix, iy, iSeg;

  segments = (Segment *)calloc((size_t)maxsegs, sizeof(Segment));

  while (*(++aptr)) {
    if (strcmp(*aptr, "-match") == 0 && aptr[1])
      sMatch = atoi(*(++aptr));

    if (strcmp(*aptr, "-mismatch") == 0 && aptr[1])
      sMismatch = atoi(*(++aptr));

    if (strcmp(*aptr, "-gapinit") == 0 && aptr[1])
      sGapInit = atoi(*(++aptr));

    if (strcmp(*aptr, "-gapext") == 0 && aptr[1])
      sGapExt = atoi(*(++aptr));
  }

#ifdef DEBUG
  fprintf(stderr, "match=%d, mismatch=%d, gap_init=%d, gap_ext=%d\n\n",
	  sMatch,sMismatch,sGapInit,sGapExt);
#endif

  while (1) {
    xlen = readSequence(stdin, xseq, sizeof(xseq));

    if (xlen <= 0)
      break;

    ylen = readSequence(stdin, yseq, sizeof(yseq));

    if (ylen <= 0)
      break;

    for (ix = 0; ix < xlen; ix++) xseq[ix] = toupper(xseq[ix]);
    for (iy = 0; iy < ylen; iy++) yseq[iy] = toupper(yseq[iy]);

    resizeSmithWatermanMatrix(&swbase, &swsize, &swmatbase, &swbasesize, xlen, ylen);

    swmat = swmatbase;

    for (ix = 0; ix <= xlen; ix++)
      swmat[0][ix].score = swmat[0][ix].pointer = 0;

    for (iy = 0; iy <= ylen; iy++)
      swmat[iy][0].score = swmat[iy][0].pointer = 0;

    maxscore = 0;

    for (iy = 1; iy <= ylen; iy++) {
      swp = swmat[iy];

      yc = yseq[iy - 1];

      for (ix = 1; ix <= xlen; ix++) {
	xc = xseq[ix - 1];
	
	if (xc == 'N' || yc == 'N')
	  score = 0;
	else
	  score = (xc == yc) ? sMatch : sMismatch;

	diagonal = swmat[iy-1][ix-1].score + score;
	up       = swmat[iy-1][ix].score + sGapInit;
	left     = swmat[iy][ix-1].score + sGapInit;

	maxgapscore = (up > left) ? up : left;
	
	if (diagonal > 0 || maxgapscore > 0) {
	  if (diagonal >= maxgapscore) {
	    swmat[iy][ix].score = diagonal;
	    swmat[iy][ix].pointer = SW_DIAGONAL;
	  } else {
	    if (up > left) {
	      swmat[iy][ix].score = up;
	      swmat[iy][ix].pointer = SW_UP;
	    } else {
	      swmat[iy][ix].score = left;
	      swmat[iy][ix].pointer = SW_LEFT;
	    }
	  }
	} else {
	  swmat[iy][ix].score = 0;
	  swmat[iy][ix].pointer = SW_UNDEFINED;
	}
	
	if (swmat[iy][ix].score >= maxscore) {
	  xmax = ix;
	  ymax = iy;
	  maxscore = swmat[iy][ix].score;
	}
      }
    }

#ifdef DEBUG    
    fprintf(stdout, "At end of SW, maximum score is %d at %d,%d\n", maxscore, xmax, ymax);
#endif

    nSegments = 0;
    inSegment = 0;

    for (ix = xmax, iy = ymax, score = swmat[ymax][xmax].score;
	 score > 0;
	 score = swmat[iy][ix].score) {
      xc = xseq[ix - 1];
      yc = yseq[iy - 1];

#ifdef DEBUG
      fprintf(stdout, "%6d  %c  %6d  %c  %6d  %s", ix, xc, iy, yc,
	      swmat[iy][ix].score, direction[swmat[iy][ix].pointer]);
      
      if ((xc != yc) && (swmat[iy][ix].pointer == SW_DIAGONAL))
	fprintf(stdout, " *");
      
      fputc('\n', stdout);
#endif

      if (xc == yc) {
	startA = iy;
	startB = ix;

	if (!inSegment) {
	  endA = iy;
	  endB = ix;
	  inSegment = 1;
	}
      } else {
	if (inSegment) {
	  segments[nSegments].startA = startA;
	  segments[nSegments].endA = endA;
	  segments[nSegments].startB = startB;
	  segments[nSegments].endB = endB;
	  nSegments++;
	  inSegment = 0;
	}
      }

      switch (swmat[iy][ix].pointer) {
      case SW_DIAGONAL:
        ix--;
        iy--;
        break;
	
      case SW_UP:
        iy--;
        break;
	
      case SW_LEFT:
        ix--;
        break;
	
      default:
        fprintf(stderr, "Error: pointer is %d, cannot continue\n", swmat[iy][ix].pointer);
        return 1;
      }
    }

    if (inSegment) {
      segments[nSegments].startA = startA;
      segments[nSegments].endA = endA;
      segments[nSegments].startB = startB;
      segments[nSegments].endB = endB;
      nSegments++;
    }

    if (nSegments > 0)
      fprintf(stdout, "%d,%d:%d,%d:%d,%d",
	      maxscore,
	      segments[nSegments-1].startA, segments[0].endA,
	      segments[nSegments-1].startB, segments[0].endB,
	      nSegments);
    else
      fprintf(stdout, "0:0,0:0,0");

    for (iSeg = nSegments - 1; iSeg >= 0; iSeg--) {
      fprintf(stdout, ";%d:%d,%d:%d", segments[iSeg].startA, segments[iSeg].endA,
	      segments[iSeg].startB,segments[iSeg].endB);
    }

    fprintf(stdout, "\n");

    fprintf(stdout, ".\n");

    fflush(stdout);
  }

  return 0;
}
