#!/usr/bin/awk
#-v RS='TxId' -v rc=0 '
BEGIN {RS="TxId"; }
/TxId/ { print $7 $8  }
END{
print "DONE"
}
