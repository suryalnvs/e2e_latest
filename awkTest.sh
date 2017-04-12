#!/usr/bin/awk
#-v RS='TxId' -v rc=0 '
BEGIN {RS="TxId"; i=0;j=0;rc=0}
/jerry/ {jerry[NR]}
/tom/ {tom[NR]}
END {
   for (e in tom) i++
   if (!(i==1)) {
      rc+=1
      print "Number of Expected Records for Tom did not match"
      rc+=1
   }
   for (e in jerry) j++
   if (!(j==3))  {
      rc+=1
      print "Number of Expected Records for Jerry did not match"
      rc+=1
   }
   exit rc
}
