#!/bin/bash
START_TIME=$(date +%s)

##### GLOBALS ######
CHANNEL_NAME="$1"
CHANNELS="$2"
CHAINCODES="$3"
ENDORSERS="$4"
CHAINCODE_NAME="$5"

##### SET DEFAULT VALUES #####
: ${CHANNEL_NAME:="mychannel"}
: ${CHANNELS:="1"}
: ${CHAINCODES:="1"}
: ${ENDORSERS:="4"}
: ${CHAINCODE_NAME:="mycc"}
: ${TIMEOUT:="20"}
COUNTER=0
MAX_RETRY=5

# find address of orderer and peers in your network
ORDERER_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("orderer")); print "$a\n";'`
PEER0_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer0")); print "$a\n";'`
PEER1_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer1")); print "$a\n";'`
PEER2_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer2")); print "$a\n";'`
PEER3_IP=`perl -e 'use Socket; $a = inet_ntoa(inet_aton("peer2")); print "$a\n";'`

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
        CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/localMspConfig
        CORE_PEER_LOCALMSPID="OrdererMSP"
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
                for (( ch=0; $ch<$CHAINCODES; ch++))
                do
                        PEER=$i
                        setGlobals $PEER
                        peer chaincode install -o $ORDERER_IP:7050 -n $CHAINCODE_NAME$ch -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincodeAPIDriver >&log.txt
                        res=$?
                        cat log.txt
                        verifyResult $res "Chaincode 'mycc$ch' installation on remote peer PEER$PEER has Failed"
                        echo "===================== Chaincode 'ccapidriver$ch' is installed on remote peer PEER$PEER ===================== "
                        echo
                done
        done
}

instantiateChaincode () {
        PEER=$1
        setGlobals $PEER
        for (( i=0; $i<$CHANNELS; i++))
        do
                for (( ch=0; $ch<$CHAINCODES; ch++))
                do
                        #PEER=` expr $ch \/ 4`
                        #setGlobals $PEER
             peer chaincode instantiate -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -v 1.0 -c '{"Args":[""]}'  -P "OR ('Org0MSP.member' , 'Org1MSP.member')" >&log.txt
  #           peer chaincode instantiate -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -v 1.0 -c '{"Args":[""]}'  -P "OR('Org1MSP.member')" >&log.txt
                        res=$?
                        cat log.txt
                        verifyResult $res "Chaincode 'mycc$ch' instantiation on PEER$PEER on channel '$CHANNEL_NAME$i' failed"
                        echo "===================== Chaincode 'ccapidriver$ch' Instantiation on PEER$PEER on channel '$CHANNEL_NAME$i' is successful ===================== "
                        echo
                sleep 20
                done
        done
}

                                     
initMarble() {
        local channel_num=$1
        local chain_num=$2
        local peer=$3
        local name=$4
        local color=$5
        local size=$6
        local owner=$7
        peer chaincode invoke -o $ORDERER_IP:7050  -C $CHANNEL_NAME$channel_num -n $CHAINCODE_NAME$chain_num -c "{\"Args\":[\"initMarble\", \"$name\",\"$color\",\"$size\",\"$owner\"]}" >&log.txt
        res=$?
        cat log.txt
        verifyResult $res "Invoke execution on PEER$peer failed "
        echo "===================== Invoke transaction on PEER$peer on $CHANNEL_NAME$channel_num/$CHAINCODE_NAME$chain_num is successful ===================== "
        echo
}

chaincodeQueryMarble() {
  local channel_num=$1
  local chaincode_num=$2
  local peer=$3
  local name=$4
  local res=$5
  echo "===================== Querying on PEER$peer on $CHANNEL_NAME$channel_num on $CHAINCODE_NAME$chainicode_num... ===================== "
  local rc=1
  local starttime=$(date +%s)

  echo "channel_num :$channel_num"
  echo "chaincode_num :$chaincode_num"
  echo "res :$res"

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$peer ...$(($(date +%s)-starttime)) secs"
     peer chaincode query  -o $ORDERER_IP:7050 -C $CHANNEL_NAME$channel_num -n $CHAINCODE_NAME$chaincode_num -c "{\"Args\":[\"readMarble\",\"$name\"]}" >&log.txt
     test $? -eq 0 
     #VALUE=$( cat log.txt | awk  '/Query Result/ { print $3 $4  }')
     VALUE=$( cat log.txt | awk  '/Query Result/ { print $NF  }')
     VALUE=$( cat log.txt | awk  '/Query Result/ { print $3  }')
     echo "Value: $VALUE"
     test "$VALUE" = "$res" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
        echo
        echo "=====================  Query transaction on PEER$peer on $CHANNEL_NAME$channel_num on chaincode $CHAINCODE_NAME$chaincode_num is successful ===================== "
  else
        echo "!!!!!!!!!!!!!!! Query result on PEER$peer is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
        echo
        echo "Total execution time $(($(date +%s)-START_TIME)) secs"
        echo
        exit 1
  fi
}

getHistoryMarble(){
  local channel_num=$1
  local chaincode_num=$2
  local peer=$3
  local name=$4
  local res=$5
  echo "===================== Invoking getHistoryForMarble on PEER$peer on $CHANNEL_NAME$channel_num on $CHAINCODE_NAME$chainicode_num... ===================== "
  local rc=1
  local starttime=$(date +%s)

  echo "channel_num :$channel_num"
  echo "chaincode_num :$chaincode_num"
  echo "res :$res"

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$peer ...$(($(date +%s)-starttime)) secs"
     peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$channel_num -n $CHAINCODE_NAME$chaincode_num -c "{\"Args\":[\"getHistoryForMarble\",\"name\"]}" >&log.txt
     test $? -eq 0 
     VALUE=$( cat log.txt | awk -F":" '/Invoke result/ { print $7 $8  }')
     echo "Value: $VALUE"
     test "$VALUE" = "$res" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
        echo
        echo "===================== Invoke getHistoryForMarble transaction on PEER$peer on $CHANNEL_NAME$ichannel_num on chaincode $CHAINCODE_NAME$chaincode_num is successful ===================== "
  else
        echo "!!!!!!!!!!!!!!! Query result on PEER$peer is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
        echo
        echo "Total execution time $(($(date +%s)-START_TIME)) secs"
        echo
        exit 1
  fi
}

txfrBlueMarbles() {
  local channel_num=$1
  local chaincode_num=$2
  local peer=$3
  local res=$4
  echo "===================== Invoking  txfrBlueMarblesToJerry on PEER$peer on $CHANNEL_NAME$channel_num on $CHAINCODE_NAME$chainicode_num... ===================== "
  local rc=1
  local starttime=$(date +%s)
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$peer ...$(($(date +%s)-starttime)) secs"
     peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["transferMarblesBasedOnColor","blue","jerry"]}' >&log.txt
     test $? -eq 0 
     #VALUE=$( cat log.txt | awk -F":" '/Invoke result/ { print $7 $8  }')
     str="Transferred 2 blue marbles to jerry"
     grep "$str" log.txt
     #echo "Value: $VALUE"
     #test "$VALUE" = "$res" && let rc=0
     if test $? -eq 0 ; then
     	#cat log.txt
     	#verifyResult $res "Invoke execution on PEER$peer failed "
     	echo "===================== Invoke transferMarbleBasedOnColor transaction on PEER$peer on $CHANNEL_NAME$i on chaincode $CHAINCODE_NAME$ch is successful ===================== "
     	echo
     else 
    	echo "!!!!!!!!!!!!!!! INVOKE tx failed on PEER$peer !!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
        echo
        echo "Total execution time $(($(date +%s)-START_TIME)) secs"
        echo
        exit 1
     fi

     sleep $TIMEOUT
 done

}


invokeCCAPIDriver() {

        for (( i=0; $i<$CHANNELS; i++))
        do
                for (( ch=0; $ch<$CHAINCODES; ch++))
                do
                 PEER=2
                 setGlobals $PEER
                
                 initMarble 0 0 2 "marble1" "blue" 25 "tom"
                 sleep 20
                 marble_res="{\"docType\":\"marble\",\"name\":\"marble1\",\"color\":\"blue\",\"size\":25,\"owner\":\"tom\"}"
                 chaincodeQueryMarble 0 0 2 "marble1" $marble_res
                 sleep 10
                 #marble_histres="response:<status:200message:\"OK\""
                 #getHistoryMarble1 1 1 2 $marble_histres 
             
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["transferMarble","marble1", "jerry"]}' 
                 #res=$?
                 #cat log.txt
                 #verifyResult $res "Invoke execution on PEER$peer failed "
                 #echo "===================== Invoke transaction on PEER$peer on $CHANNEL_NAME$i on chaincode $CHAINCODE_NAME$ch is successful ===================== "
                 #echo
                 #sleep $TIMEOUT

                 #initMarble 0 0 2 "marble2" "blue" 35 "tom"
                 #marble_res="{\"docType\":\"marble\",\"name\":\"marble2\",\"color\":\"blue\",\"size\":35,\"owner\":\"tom\"}"
                 #chaincodeQueryMarble 0 0 2 "marble2" $marble_res 

                 #echo "Calling ************** Transfer Blue Marbles to Jerry ***********************"
                 #txfrBlueMarbles
    		 #verify two marbles are transferred to jerry"
                 #marble_res="{\"docType\":\"marble\",\"name\":\"marble2\",\"color\":\"blue\",\"size\":35,\"owner\":\"jerry\"}"
                 #chaincodeQueryMarble 0 0 2 "marble2" $marble_res 
                 #sleep 10
                 #marble_res="{\"docType\":\"marble\",\"name\":\"marble1\",\"color\":\"blue\",\"size\":25,\"owner\":\"jerry\"}"
                 #chaincodeQueryMarble 0 0 2 "marble1" $marble_res 
                 #sleep 10
                 #echo "Calling ************** Transfer Blue Marbles To Jerry Completed ***********************"

                 #initMarble 0 0 2 "marble3" "blue" 45 "tom"
                 #sleep 15
                 #marble_res="{\"docType\":\"marble\",\"name\":\"marble3\",\"color\":\"blue\",\"size\":45,\"owner\":\"tom\"}"
                 #chaincodeQueryMarble 0 0 2 "marble3" $marble_res 
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["delete","marble3"]}' 

                 #peer chaincode query -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["queryMarblesByOwner","tom"]}' 
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["rangeQuery","a","z"]}'
     #            sleep 10

     #            echo "Calling ************** GET HISTORY FOR MARBLE1 ***********************"
#
#                 peer chaincode query -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getHistoryForMarble","marble1"]}' 
#
#                 sleep 10
#                 echo "DONE ************** GET HISTORY FOR MARBLE1 ***********************"


                 #echo "Calling ************** GET HISTORY FOR MARBLE3 ***********************"

                 #peer chaincode query -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getHistoryForMarble","marble3"]}' 

                 #sleep 10
                 #echo "DONE ************** GET HISTORY FOR MARBLE3 ***********************"
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getRangeQuery", "a", "z"]}'
#                 peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getArgsSlice"]}'
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getCreator"]}'
#                 peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getTxTimeStamp"]}'
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getBinding"]}'
                 #peer chaincode invoke -o $ORDERER_IP:7050 -C $CHANNEL_NAME$i -n $CHAINCODE_NAME$ch -c '{"Args":["getTransient"]}'

                 #peer chaincode query -o $ORDERER_IP:7050 -C "" -n qscc -c '{"Args":["GetChainInfo","myc0"]}'
		 #peer chaincode query -o $ORDERER_IP:7050 -C "" -n qscc -c '{"Args":["GetBlockByNumber","myc0","1"]}'
		 #peer chaincode query -o $ORDERER_IP:7050 -C "" -n qscc -c '{"Args":["GetTransactionByID","myc1","19badf25511cad45665c5291b8f1bff5d10a0fe0db6cb4dba7f7f3abbb5b0b89"]}' 
             done
      done
}

CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/localMspConfig
CORE_PEER_LOCALMSPID="OrdererMSP"
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

installChaincode
instantiateChaincode 0
invokeCCAPIDriver
