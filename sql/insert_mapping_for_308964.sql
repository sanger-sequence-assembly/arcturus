-- Copyright (c) 2001-2014 Genome Research Ltd.
--
-- Authors: David Harper
--          Ed Zuiderwijk
--          Kate Taylor
--
-- This file is part of Arcturus.
--
-- Arcturus is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program. If not, see <http://www.gnu.org/licenses/>.

# example used for testing Do all contigs have the correct number of mappings?
insert into MAPPING (contig_id, seq_id, mapping_id, cstart, cfinish, direction) values 
(308964,5250899,  19538634,     1,    785,"Forward"),
(308964,5250879,  19538635,    32,    947 ,"Forward"), 
(308964,5250902,  19538636,    73,    839 ,"Reverse"), 
(308964,5250897,  19538637,   117,    999 ,"Forward"), 
(308964,5250868,  19538638,   141,   1056 ,"Forward"), 
(308964,5250851,  19538639,   184,   1003 ,"Reverse"), 
(308964,5250892,  19538640,   259,   1171 ,"Reverse"), 
(308964,5250877,  19538641,   335,   1142 ,"Forward"), 
(308964,5250880,  19538642,   360,   1184 ,"Forward"), 
(308964,5250844,  19538643,   449,   1357 ,"Forward"), 
(308964,5250856,  19538644,   473,   1150 ,"Forward"), 
(308964,5250859,  19538645,   563,   1308 ,"Reverse"), 
(308964,5250857,  19538646,   710,   1463 ,"Forward"), 
(308964,5250884,  19538647,  1132,   2007 ,"Reverse"), 
(308964,5250883,  19538648,  1176,   1736 ,"Reverse"), 
(308964,5250866,  19538649,  1208,   2160 ,"Reverse"), 
(308964,5250904,  19538650,  1217,   1824 ,"Reverse"), 
(308964,5250882,  19538651,  1377,   2313 ,"Forward"), 
(308964,5250853,  19538652,  1636,   2479 ,"Reverse"), 
(308964,5250900,  19538653,  1679,   2332 ,"Reverse"), 
(308964,5250874,  19538654,  1902,   2858 ,"Forward"), 
(308964,5250875,  19538655,  1973,   2932 ,"Reverse"), 
(308964,5250888,  19538656,  2081,   3002 ,"Reverse"), 
(308964,5250871,  19538657,  2122,   3086 ,"Reverse"), 
(308964,5250842,  19538658,  2158,   3000 ,"Forward"), 
(308964,5250860,  19538659,  2196,   2525 ,"Forward"), 
(308964,5250906,  19538660,  2196,   2978 ,"Reverse"), 
(308964,5250889,  19538661,  2251,   3027 ,"Reverse"), 
(308964,5250873,  19538662,  2309,   3292 ,"Forward"), 
(308964,5250898,  19538663,  2442,   3156 ,"Reverse"), 
(308964,5250840,  19538664,  2716,   3559 ,"Reverse"), 
(308964,5250843,  19538665,  2776,   3441 ,"Forward"), 
(308964,5250845,  19538666,  2806,   3575 ,"Forward"), 
(308964,5250850,  19538667,  2885,   3733 ,"Reverse"), 
(308964,5250905,  19538668,  2969,   3639 ,"Reverse"), 
(308964,5250881,  19538669,  3165,   4095 ,"Reverse"), 
(308964,5250863,  19538670,  3166,   3959 ,"Reverse"), 
(308964,5250893,  19538671,  3341,   4159 ,"Forward"), 
(308964,5250870,  19538672,  3360,   4410 ,"Reverse"), 
(308964, 883707,  19538673,  3636,   4427 ,"Reverse"), 
(308964,5250841,  19538674,  3692,   4575 ,"Reverse"), 
(308964,5250878,  19538675,  3707,   4425 ,"Reverse"), 
(308964,5250891,  19538676,  3727,   4387 ,"Reverse"), 
(308964,5250903, 19538677,  3841,   4540, "Reverse");
