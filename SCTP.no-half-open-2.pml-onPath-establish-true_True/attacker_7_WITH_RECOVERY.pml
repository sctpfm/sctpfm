/* spin -t7 -s -r -p -g SCTP.no-half-open-2.pml-onPath-establish-true_daisy_check.pml */
active proctype attacker() {
	
	CtoA ! INIT,NO_TAG,EXP_TAG;
	AtoC ? INIT_ACK,EXP_TAG,EXP_TAG;
	CtoA ! INIT,NO_TAG,EXP_TAG;
	CtoB ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	BtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	AtoC ? INIT_ACK,EXP_TAG,EXP_TAG;
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