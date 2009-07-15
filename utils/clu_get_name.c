#include <stdio.h>
#include <sys/types.h>
#include <sys/clu.h>

/**
 ** This is a simple program to determine the name of the TruCluster
 ** on which it is running and print it to stdout. It's amazing that
 ** Compaq don't provide this as a utility!
 **
 ** Build with
 **
 **   cc -o clu_get_name clu_get_name.c -lclu
 **
 ** Author: David Harper <adh@sanger.ac.uk>
 **/

int main(int argc, char **argv) {
  char name[80];
  size_t namelen;
  int rc;

  namelen = sizeof(name);

  rc = clu_info(CLU_INFO_CLU_NAME, name, namelen);

  if (rc != 0)
    return rc;

  printf("%s\n", name);

  return 0;
}
