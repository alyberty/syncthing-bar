#!/bin/bash

# rehashing our [watchdog setArguments:[NSArray arrayWithObjects:$child,$sleepytime,$parentPID,nil]]; //$1-4 for watchdog. (for clarity)
echo "arg1 is the SubProcess: $1, arg2 is sleepytime: $2, and arg3 is ParentPID, aka $$: $3"
CHILD=$1 && SLEEPYTIME=$2 || SLEEPYTIME=10; PARENTPID=$3 || PARENTPID=$$

GoSubProcess () {							# define funtions, start script at very end.
$1 arguments &  						# "&" puts SubP in background subshell
CHILDPID=$!							# what all the fuss is about.
if kill -0 $CHILDPID; then 			# rock the cradle to make sure it aint dead
echo "Child is alive at $!" 		# glory be to god
else echo "couldnt start child.  dying."; exit 2; fi
babyRISEfromtheGRAVE # keep an eye on child process
}
babyRISEfromtheGRAVE () {
echo "PARENT is $PARENTPID";			# remember where you came from, like j.lo
while kill -0 $PARENTPID; do 			# is that fount of life, nstask parent alive?
echo "Parent is alive, $PARENTPID is it's PID"
sleep $SLEEPTIME					# you lazy boozehound
if kill -0 $CHILDPID; then 			# check on baby.
echo "Child is $CHILDPID and is alive."
sleep $SLEEPTIME				# naptime!
else echo "Baby, pid $CHILDPID died!  Respawn!"
GoSubProcess; fi 				# restart daemon if it dies
done 									# if this while loop ends, the parent PID crashed.
logger "My Parent Process, aka $PARENTPID died!"
logger "I'm killing my baby, $CHILDPID, and myself."
kill -9 $CHILDPID; exit 1				# process table cleaned.  nothing is left.  all three tasks are dead.  long live nstask.
}
GoSubProcess 								# this is where we start the script.
exit 0										# this is where we never get to