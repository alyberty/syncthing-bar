#!/bin/bash

while getopts p:c:s option do
    case "${option}" in
    p) PARENTPID=${OPTARG};;
    c) CHILDPID=${OPTARG};;
    s) SLEEPYTIME=${OPTARG};;
esac
done

babyRISEfromtheGRAVE () {
    while kill -0 $PARENTPID
    do
        if kill -0 $CHILDPID; then
            sleep $SLEEPTIME
        else
            exit 1
        fi
    done
    logger "SyncthingBar [ PID=$PARENTPID ] is no longer active, died!"
    logger "Killing Syncthing [ PID = $CHILDPID ], and exiting."
    kill -9 $CHILDPID
    exit 1
};

babyRISEfromtheGRAVE;
exit 0;