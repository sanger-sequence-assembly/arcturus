#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(int argc, char **argv) {
  int count;
  int j, k;
  char *bases = "ACGT";
  int seed;

  if (argc < 2) {
    fprintf(stderr, "usage: %s <how many bases>\n",
	    argv[0]);
    return 1;
  }

  count = atoi(argv[1]);

  if (count < 1) {
    fprintf(stderr, "the argument was not a positive integer\n");
    return 3;
  }

  seed = (int)time(NULL);
  srandom(seed);

  for (j = 0; j < count; j++) {
    k = random() % 4;
    putchar(bases[k]);
    if (((j+1)%50) == 0)
      putchar('\n');
  }

  if ((count % 50) != 0)
    putchar('\n');

  return 0;
}
