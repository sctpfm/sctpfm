/* spin -t9 -s -r -p -g SCTP.no-half-open-2.pml-onPath-establish-false_daisy_check.pml */
active proctype attacker() {
	
	if
	:: CtoA ! INIT,NO_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT_ACK,EXP_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: CtoA ! INIT,NO_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: CtoB ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT_ACK,EXP_TAG,EXP_TAG;
	fi unless timeout;
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