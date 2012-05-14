#bsub -R'select[mem>362000] rusage[mem=362000]' -M362000000 -q normal -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
#bsub -R'select[mem>36000] rusage[mem=36000]' -M36000000 -q normal -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
bsub -R'select[mem>24000] rusage[mem=24000]' -M24000000 -q normal -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
# try this one next!
#bsub -R'select[mem>36000] rusage[mem=36000]' -M36000000 -q hugemem -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
