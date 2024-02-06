/* spin -t7 -s -r -p -g SCTP.no-half-open.pml-onPath-teardown-true_daisy_check.pml */
active proctype attacker() {
	
	CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	CtoA ! ABORT,EXP_TAG,NO_TAG;
	CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
// recovery to N
// N begins here ... 

	mtype:msgs M;
	mtype:tag t0;
	mtype:tag t1;
	do
	:: atomic { AtoC ? M,t0,t1; CtoB ! M,t0,t1; }
	:: atomic { BtoC ? M,t0,t1; CtoA ! M,t0,t1; }
	od

}