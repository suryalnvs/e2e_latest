#!/bin/bash
START_TIME=$(date +%s)

##### GLOBALS ######
CHANNEL_NAME="$1"
CHANNELS="$2"
CHAINCODES="$3"
ENDORSERS="$4"
CH02INS="$5"

##### SET DEFAULT VALUES #####
: ${CHANNEL_NAME:="mychannel"}
: ${CHANNELS:="1"}
: ${CHAINCODES:="1"}
: ${ENDORSERS:="4"}
: ${TIMEOUT:="150"}
COUNTER=0
MAX_RETRY=5

# find address of orderer and peers in your network
ORDERER_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("orderer")); print "$a\n";'`
PEER0_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer0")); print "$a\n";'`
PEER1_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer1")); print "$a\n";'`
PEER2_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer2")); print "$a\n";'`
PEER3_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer3")); print "$a\n";'`

echo "-----------------------------------------"
echo "Orderer IP $ORDERER_IP"
echo "PEER0 IP $PEER0_IP"
echo "PEER1 IP $PEER1_IP"
echo "PEER2 IP $PEER2_IP"
echo "PEER3 IP $PEER3_IP"


echo "Channel name prefix: $CHANNEL_NAME"
echo "Total channels: $CHANNELS"
echo "Total Chaincodes: $CHAINCODES"
echo "Total Endorsers: $ENDORSERS"
echo "Instantiating CH02 on : $CH02INS"
echo "-----------------------------------------"

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
		echo "Total execution time $(($(date +%s)-START_TIME)) secs"
   		exit 1
	fi
}

setGlobals () {
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peer/peer$1/localMspConfig
	CORE_PEER_ADDRESS=peer$1:7051
	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org0MSP"
	else
		CORE_PEER_LOCALMSPID="Org1MSP"
	fi
}

createChannel() {
	CHANNEL_NUM=$1
	peer channel create -o $ORDERER_IP:7050 -c $CHANNEL_NAME$CHANNEL_NUM -f crypto/orderer/channel$CHANNEL_NUM.tx >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Channel creation with name \"$CHANNEL_NAME$CHANNEL_NUM\" has failed"
	echo "===================== Channel \"$CHANNEL_NAME$CHANNEL_NUM\" is created successfully ===================== "
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	for (( i=0; $i<$CHANNELS; i++))
	do
		peer channel join -b $CHANNEL_NAME$i.block  >&log.txt
		res=$?
		cat log.txt
		if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
			COUNTER=` expr $COUNTER + 1`
			echo "PEER$1 failed to join the channel 'mychannel$i', Retry after 2 seconds"
			sleep 2
			joinWithRetry $1
		else
			COUNTER=0
		fi
        	verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
		echo "===================== PEER$1 joined on the channel \"$CHANNEL_NAME$i\" ===================== "
		sleep 2
	done
}

joinChannel () {
	PEER=$1
	setGlobals $PEER
	joinWithRetry $PEER
	echo "===================== PEER$PEER joined on $CHANNELS channel(s) ===================== "
	sleep 2
	echo
}

installChaincode () {
	for (( i=0; $i<$ENDORSERS; i++))
	do
			PEER=$i
			setGlobals $PEER
			peer chaincode install -n mycc05 -v 1 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example05 >&log.txt
			res=$?
			cat log.txt
		        verifyResult $res "Chaincode 'mycc05' installation on remote peer PEER$PEER has Failed"
			echo "===================== Chaincode 'mycc05' is installed on remote peer PEER$PEER ===================== "
			echo
                 
			peer chaincode install -n mycc02 -v 1 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
			res=$?
			cat log.txt
		        verifyResult $res "Chaincode 'mycc02' installation on remote peer PEER$PEER has Failed"
			echo "===================== Chaincode 'mycc02' is installed on remote peer PEER$PEER ===================== "
			echo
	done
}

instantiateChaincodeEx05() {
	PEER=$1
        ch_name=$2
        cc_name=$3
        ch_num=$4
	setGlobals $PEER

	#setGlobals $PEER
	peer chaincode instantiate -o $ORDERER_IP:7050 -C $ch_name$ch_num -n $cc_name -v 1 -c '{"Args":["init", "sum", "0"]}' -P "OR('Org0MSP.member','Org1MSP.member')" >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Chaincode 'mycc$ch' instantiation on PEER$PEER on channel '$ch_name$ch_num' failed"
	echo "===================== Chaincode '$cc_name' Instantiation on PEER$PEER on channel '$ch_name$ch_num' is successful ===================== "
	echo
}


instantiateChaincodeEx02() {
	PEER=$1
        ch_name=$2
        cc_name=$3
        ch_num=$4
	setGlobals $PEER

	#setGlobals $PEER
peer chaincode instantiate -o $ORDERER_IP:7050 -C $ch_name$ch_num -n $cc_name -v 1 -c '{"Args":["init", "a", "100", "b", "200"]}' -P "OR('Org0MSP.member','Org1MSP.member')" >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Chaincode 'mycc$ch' instantiation on PEER$PEER on channel '$ch_name$ch_num' failed"
	echo "===================== Chaincode '$cc_name' Instantiation on PEER$PEER on channel '$ch_name$ch_num' is successful ===================== "
	echo
}


chaincodeInvokeEx02() {
        local channel_num=$1
        local peer=$2
	peer chaincode invoke -o $ORDERER_IP:7050  -C $CHANNEL_NAME$channel_num -n mycc02 -c '{"Args":["invoke","a", "b", "10"]}' >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$peer failed "
	echo "===================== Invoke transaction on PEER$peer on $CHANNEL_NAME$channel_num/mycc02 is successful ===================== "
	echo
}


chaincodeInvokeEx05() {
        local channel_num=$1
        local peer=$2
	peer chaincode invoke -o $ORDERER_IP:7050  -C $CHANNEL_NAME$channel_num -n mycc05 -c '{"Args":["invoke","mycc02/myc1", "sum"]}' >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$peer failed "
	echo "===================== Invoke transaction on PEER$peer on $CHANNEL_NAME$channel_num/mycc05 is successful ===================== "
	echo
}

chaincodeQuery () {
  local channel_num=$1
  local peer=$2
  local res=$3
  echo "===================== Querying on PEER$peer on $CHANNEL_NAME$channel_num/mycc===================== "
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$peer ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME$channel_num -n mycc05 -c '{"Args":["query","mycc02/myc1", "sum"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     echo "Value: $VALUE"
     test "$VALUE" = "$res" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$peer on $CHANNEL_NAME$channel_num/mycc is successful ===================== "
	echo
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$peer is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	echo "Total execution time $(($(date +%s)-START_TIME)) secs"
	echo
	exit 1
  fi
}

CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/localMspConfig
CORE_PEER_LOCALMSPID="OrdererMSP"
## Create channel
for (( ch=0; $ch<$CHANNELS; ch++))
do
	createChannel $ch
done

## Join all the peers to all the channels
for (( peer=0; $peer<$ENDORSERS; peer++))
do
	echo "====================== Joing PEER$peer on all channels ==============="
	joinChannel $peer
done

## Install chaincode on Peer0/Org0 and Peer2/Org1
echo "Installing chaincode on all Peers ..."
installChaincode

#Instantiate chaincode on Peer2/Org1
echo "Instantiating chaincode on PEER0 ..."
#instantiate cc_ex05 on channel0
instantiateChaincodeEx05 0 myc mycc05 0
instantiateChaincodeEx02 0 myc mycc02 $5

sleep 20
#Invoke/Query on all chaincodes on all channels
echo "send Invokes/Queries on all channels ..."
ch=0
PEER=1
setGlobals "$PEER"
echo "calling mycc020 on initial sum"
chaincodeQuery $ch $PEER 300 


ch=$5
PEER=1
setGlobals "$PEER"
chaincodeInvokeEx02 $ch $PEER
sleep 20

ch=0
PEER=1
setGlobals "$PEER"
chaincodeQuery $ch $PEER 300

echo
echo "===================== All GOOD, End-2-End execution completed ===================== "
echo
echo "Total execution time $(($(date +%s)-START_TIME)) secs"
exit 0
