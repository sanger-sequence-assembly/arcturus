bsub  -R'select[mem>8192] rusage[mem=8192]' -M8192000 -q basement -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/eimeria_test_load1.log -J eimeria_test_load1 /nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/core-system-migration/java/scripts/importbamfile -instance illumina -organism EIMERIA_TENELLA -project BIN -in /lustre/scratch101/sanger/kt6/Eimeria/NODE_21850_length_9460_cov_8.547040.bam -consensus /lustre/scratch101/sanger/kt6/Eimeria/NODE_21850_length_9460_cov_8.547040.faq
