BEGIN {
  lastscaffold = 0;
}

{
  if (lastscaffold != 0 && $1 != lastscaffold) {
    printf "\n";
  }

  printf "%6d %6d %8d %s\n",$1,$2,1+$4-$3,$6;

  lastscaffold = $1;
}
