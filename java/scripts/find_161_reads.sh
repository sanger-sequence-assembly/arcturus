bsub -q small -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/find_161_reads.bam -J find_161_reads /software/solexa/bin/aligners/samtools/current/samtools view -f 161 /lustre/scratch101/sanger/kt6/Eimeria/all_cappair.bam > /lustre/scratch101/sanger/kt6/Eimeria/find_161_reads.log
