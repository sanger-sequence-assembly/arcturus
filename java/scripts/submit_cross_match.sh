#bsub -R'select[mem>362000] rusage[mem=362000]' -M362000000 -q normal -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

#bsub -R'select[mem>36000] rusage[mem=36000]' -M36000000 -q normal -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
bsub -R'select[mem>24000] rusage[mem=24000]' -M24000000 -q normal -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
# try this one next!
#bsub -R'select[mem>36000] rusage[mem=36000]' -M36000000 -q hugemem -P helminth-ga -o /lustre/scratch101/sanger/kt6/Eimeria/cross_match2.log -J cross_match2 /lustre/scratch101/sanger/kt6/Eimeria/cross_match.sh 
