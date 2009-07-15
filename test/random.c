#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  int maxnum, count;
  int j, k;

  if (argc < 3) {
    fprintf(stderr, "usage: %s <maximum number> <how many numbers>\n",
	    argv[0]);
    return 1;
  }

  maxnum = atoi(argv[1]);

  if (maxnum < 1) {
    fprintf(stderr, "the first argument was not a positive integer\n");
    return 2;
  }

  count = atoi(argv[2]);

  if (count < 1) {
    fprintf(stderr, "the second argument was not a positive integer\n");
    return 3;
  }

  for (j = 0; j < count; j++) {
    k = 1 + random() % maxnum;
    printf("%d\n", k);
  }

  return 0;
}
