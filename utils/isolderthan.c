#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

int main(int argc, char **argv) {
  struct stat mystata, mystatb;

  if (argc != 3) {
    fprintf(stderr,"usage: %s filea fileb\n",argv[0]);
    return 2;
  }

  if (stat(argv[1], &mystata) != 0) {
    fprintf(stderr, "%s: stat failed on \"%s\"\n", argv[0], argv[1]);
    return 3;
  }

  if (stat(argv[2], &mystatb) != 0) {
    fprintf(stderr, "%s: stat failed on \"%s\"\n", argv[0], argv[2]);
    return 4;
  }

  return (mystata.st_mtime > mystatb.st_mtime) ? 0 : 1;
} 
