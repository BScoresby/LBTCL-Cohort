#!/bin/bash

setup(){
    mkdir -p /home/$USER/.bitcoin/tmp;
    touch /home/$USER/.bitcoin/tmp/bitcoin.conf
    echo "regtest=1  
	fallbackfee=0.0001
        server=1
        txindex=1
        daemon=1" >> /home/$USER/.bitcoin/tmp/bitcoin.conf
    BITCOINCLI="/usr/local/bin/bitcoin/bin/bitcoin-cli"
    DATADIR="-datadir=/home/$USER/.bitcoin/tmp"
    if ! command -v jq &> /dev/null
    then
        sudo apt-get install jq
    fi
}

start_bitcoind(){
    /usr/local/bin/bitcoin/bin/bitcoind $DATADIR -daemon
    sleep 3
}

create_wallet(){
    $BITCOINCLI $DATADIR -named createwallet wallet_name="$1" disable_private_keys="$2" blank="$3" 1> /dev/null
}

create_address(){
    $BITCOINCLI $DATADIR -rpcwallet=$1 getnewaddress
}

mine_new_blocks(){
    MINER1=`create_address $1`
    $BITCOINCLI $DATADIR generatetoaddress $2 "$MINER1" > /dev/null
}

send_coins(){
    $BITCOINCLI $DATADIR -rpcwallet=$1 -named sendtoaddress address="$2" amount="$3" fee_rate=25 
}

get_address_pubkey(){
    $BITCOINCLI $DATADIR -named -rpcwallet=$1 getaddressinfo address=$2 | jq -r '.pubkey'
}

get_balance(){
    $BITCOINCLI $DATADIR -named -rpcwallet=$1 getbalance
}

list_unspent(){
    $BITCOINCLI $DATADIR -named -rpcwallet=$1 listunspent
}

create_multi(){
    ALICE_INTERNAL_PUBKEY=$($BITCOINCLI $DATADIR -rpcwallet=$1 listdescriptors | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/1/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
    ALICE_EXTERNAL_PUBKEY=$($BITCOINCLI $DATADIR -rpcwallet=$1 listdescriptors | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/0/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
    BOB_INTERNAL_PUBKEY=$($BITCOINCLI $DATADIR -rpcwallet=$2 listdescriptors | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/1/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
    BOB_EXTERNAL_PUBKEY=$($BITCOINCLI $DATADIR -rpcwallet=$2 listdescriptors | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/0/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')

    EXTERNAL_DESCRIPTOR="wsh(sortedmulti(2,"$ALICE_EXTERNAL_PUBKEY","$BOB_EXTERNAL_PUBKEY"))"
    INTERNAL_DESCRIPTOR="wsh(sortedmulti(2,"$ALICE_INTERNAL_PUBKEY","$BOB_INTERNAL_PUBKEY"))"         
 
    EXTERNAL_DESC_SUM=$($BITCOINCLI $DATADIR getdescriptorinfo $EXTERNAL_DESCRIPTOR | jq -r '.descriptor')
    INTERNAL_DESC_SUM=$($BITCOINCLI $DATADIR getdescriptorinfo "$INTERNAL_DESCRIPTOR" | jq -r '.descriptor')

    MULTI_EXT_DESC="{\"desc\": \"$EXTERNAL_DESC_SUM\", \"active\": true, \"interal\": false, \"timestamp\": \"now\"}"
    MULTI_INT_DESC="{\"desc\": \"$INTERNAL_DESC_SUM\", \"active\": true, \"interal\": true, \"timestamp\": \"now\"}"

    MULTI_DESC="[$MULTI_EXT_DESC, $MULTI_INT_DESC]"
}

create_alice_signing_descriptor(){
    ALICE_INTERNAL_PRIVKEY=$($BITCOINCLI $DATADIR -rpcwallet=Alice listdescriptors true | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/1/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
    ALICE_EXTERNAL_PRIVKEY=$($BITCOINCLI $DATADIR -rpcwallet=Alice listdescriptors true | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/0/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
 
    EXTERNAL_PRIVKEY_DESCRIPTOR="wsh(sortedmulti(2,"$ALICE_EXTERNAL_PRIVKEY","$BOB_EXTERNAL_PUBKEY"))"
    INTERNAL_PRIVKEY_DESCRIPTOR="wsh(sortedmulti(2,"$ALICE_INTERNAL_PRIVKEY","$BOB_INTERNAL_PUBKEY"))"         

    EXTERNAL_PRIVKEY_CHECKSUM=$($BITCOINCLI $DATADIR getdescriptorinfo $EXTERNAL_PRIVKEY_DESCRIPTOR | jq -r '.checksum')
    INTERNAL_PRIVKEY_CHECKSUM=$($BITCOINCLI $DATADIR getdescriptorinfo "$INTERNAL_PRIVKEY_DESCRIPTOR" | jq -r '.checksum')
    
    EXTERNAL_PRIVKEY_DESC_SUM=${EXTERNAL_PRIVKEY_DESCRIPTOR}#${EXTERNAL_PRIVKEY_CHECKSUM}
    INTERNAL_PRIVKEY_DESC_SUM=${INTERNAL_PRIVKEY_DESCRIPTOR}#${INTERNAL_PRIVKEY_CHECKSUM}

    ALICE_EXT_DESC="{\"desc\": \"$EXTERNAL_PRIVKEY_DESC_SUM\", \"active\": true, \"interal\": false, \"timestamp\": \"now\"}"
    ALICE_INT_DESC="{\"desc\": \"$INTERNAL_PRIVKEY_DESC_SUM\", \"active\": true, \"interal\": true, \"timestamp\": \"now\"}"

    ALICE_DESC="[$ALICE_EXT_DESC, $ALICE_INT_DESC]"
}

create_bob_signing_descriptor(){
    BOB_INTERNAL_PRIVKEY=$($BITCOINCLI $DATADIR -rpcwallet=Bob listdescriptors true | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/1/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
    BOB_EXTERNAL_PRIVKEY=$($BITCOINCLI $DATADIR -rpcwallet=Bob listdescriptors true | jq -r '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/0/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')
 
    EXTERNAL_PRIVKEY_DESCRIPTOR="wsh(sortedmulti(2,"$ALICE_EXTERNAL_PUBKEY","$BOB_EXTERNAL_PRIVKEY"))"
    INTERNAL_PRIVKEY_DESCRIPTOR="wsh(sortedmulti(2,"$ALICE_INTERNAL_PUBKEY","$BOB_INTERNAL_PRIVKEY"))"         

    EXTERNAL_PRIVKEY_CHECKSUM=$($BITCOINCLI $DATADIR getdescriptorinfo $EXTERNAL_PRIVKEY_DESCRIPTOR | jq -r '.checksum')
    INTERNAL_PRIVKEY_CHECKSUM=$($BITCOINCLI $DATADIR getdescriptorinfo "$INTERNAL_PRIVKEY_DESCRIPTOR" | jq -r '.checksum')
    
    EXTERNAL_PRIVKEY_DESC_SUM=${EXTERNAL_PRIVKEY_DESCRIPTOR}#${EXTERNAL_PRIVKEY_CHECKSUM}
    INTERNAL_PRIVKEY_DESC_SUM=${INTERNAL_PRIVKEY_DESCRIPTOR}#${INTERNAL_PRIVKEY_CHECKSUM}

    BOB_EXT_DESC="{\"desc\": \"$EXTERNAL_PRIVKEY_DESC_SUM\", \"active\": true, \"interal\": false, \"timestamp\": \"now\"}"
    BOB_INT_DESC="{\"desc\": \"$INTERNAL_PRIVKEY_DESC_SUM\", \"active\": true, \"interal\": true, \"timestamp\": \"now\"}"

    BOB_DESC="[$ALICE_EXT_DESC, $ALICE_INT_DESC]"
}

import_descriptors(){
    $BITCOINCLI $DATADIR -rpcwallet=$1 importdescriptors "$2" > /dev/null
}

funding_psbt(){
    TXID1=$($BITCOINCLI $DATADIR -named -rpcwallet=$1 listunspent | jq -r '.[0] | .txid')
    VOUT1=$($BITCOINCLI $DATADIR -named -rpcwallet=$1 listunspent | jq -r '.[0] | .vout')
    TXID2=$($BITCOINCLI $DATADIR -named -rpcwallet=$2 listunspent | jq -r '.[0] | .txid')
    VOUT2=$($BITCOINCLI $DATADIR -named -rpcwallet=$2 listunspent | jq -r '.[0] | .vout')
    ALICE_CHANGE=$($BITCOINCLI $DATADIR -rpcwallet=Alice getrawchangeaddress)
    BOB_CHANGE=$($BITCOINCLI $DATADIR -rpcwallet=Bob getrawchangeaddress)
    MULTI_ADDR=$(create_address Multi)

    PSBT1=$($BITCOINCLI $DATADIR -named createpsbt inputs='''[ { "txid": "'$TXID1'", "vout": '$VOUT1' }, { "txid": "'$TXID2'", "vout": '$VOUT2' } ]''' outputs='''[ { "'$MULTI_ADDR'": 20 }, { "'$ALICE_CHANGE'": 19.9998 }, { "'$BOB_CHANGE'": 19.9998 } ]''' ) 

#updating psbt
    PSBT1A=$($BITCOINCLI $DATADIR -rpcwallet=Alice walletprocesspsbt "$PSBT1" | jq -r '.psbt')

    PSBT1AB=$($BITCOINCLI $DATADIR -rpcwallet=Bob walletprocesspsbt "$PSBT1A" | jq -r '.psbt')

#finalizing psbt    
    HEX=$($BITCOINCLI $DATADIR -rpcwallet=Bob finalizepsbt "$PSBT1AB" | jq -r '.hex')

#broadcasting psbt
    $BITCOINCLI $DATADIR -rpcwallet=Bob -named sendrawtransaction hexstring=$HEX
}

spending_psbt(){
    ALICE_ADDR2=$(create_address Alice)
    BOB_ADDR2=$(create_address Bob)
    MULTI_CHANGE_ADDR2=$(create_address Multi)
    MULTI_TXID_1=$($BITCOINCLI $DATADIR -rpcwallet=$1 listunspent | jq -r '.[0] | .txid')
    MULTI_VOUT_1=$($BITCOINCLI $DATADIR -rpcwallet=$1 listunspent | jq '.[0] | .vout')

    PSBT2=$($BITCOINCLI $DATADIR -named createpsbt inputs='''[ { "txid": "'$MULTI_TXID_1'", "vout": '$MULTI_VOUT_1' } ]''' outputs='''[ { "'$ALICE_ADDR2'": 5 }, { "'$BOB_ADDR2'": 5 }, { "'$MULTI_CHANGE_ADDR2'" : 9.998 } ]''' ) 
}

sign_spending_psbt(){
    PSBT2A=$($BITCOINCLI $DATADIR -rpcwallet=Alice walletprocesspsbt "$PSBT2" | jq -r '.psbt')

    PSBT2AB=$($BITCOINCLI $DATADIR -rpcwallet=Bob walletprocesspsbt "$PSBT2A" | jq -r '.psbt')

    HEX=$($BITCOINCLI $DATADIR -rpcwallet=Alice finalizepsbt "$PSBT2AB" | jq -r '.hex')

#broadcasting psbt
    $BITCOINCLI $DATADIR -rpcwallet=Bob -named sendrawtransaction hexstring=$HEX
}

cleanup(){
    $BITCOINCLI $DATADIR stop
    sleep 2
    rm -rf /home/$USER/.bitcoin/tmp
}


#Setup
setup
start_bitcoind

#SETUP MULTISIG
#1. Create three wallets: Miner, Alice and Bob
create_wallet Miner false false
create_wallet Alice false false
create_wallet Bob false false

#2. Fund the wallets by generating some blocks and sending coins to Alice and Bob
mine_new_blocks Miner 103
ALICE1=$(create_address Alice)
BOB1=$(create_address Bob)
TXIDA=$(send_coins Miner $ALICE1 30)
TXIDB=$(send_coins Miner $BOB1 30)
mine_new_blocks Miner 1
get_balance Alice
get_balance Bob

#3. Create 2 of 2 Multisig for Alice and Bob
create_multi Alice Bob
create_wallet Multi true true
import_descriptors Multi "$MULTI_DESC"

#4. Create PSBT funding multisig with 20BTC
funding_psbt Alice Bob

#5. Confirm balance by mining a few more blocks
mine_new_blocks Miner 3

#6. Print final balances of Alice and Bob
echo "Alice balance: $(get_balance Alice)"
echo "Bob balance: $(get_balance Bob)"

#SETTLE MULTISIG
#1. Create PSBT to spend from multisig
spending_psbt Multi

#2. - 4. Sign the PSBT with Alice and Bob wallets, extract and broadcast transaction.
create_alice_signing_descriptor
import_descriptors Alice "$ALICE_DESC"
create_bob_signing_descriptor
import_descriptors Bob "$BOB_DESC"
sign_spending_psbt

#5. Mine new blocks to confirm transaction and print balances for Alice and Bob
mine_new_blocks Miner 1
echo "Alice balance: $(get_balance Alice)"
echo "Bob balance: $(get_balance Bob)"

#Cleanup
cleanup
