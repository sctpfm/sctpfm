/* spin -t9 -s -r -p -g SCTP.no-half-open-2.pml-onPath-teardown-true_daisy_check.pml */
active proctype attacker() {
	
	if
	:: CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoB ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoB ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoB ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? SHUTDOWN,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoB ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? SHUTDOWN,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT,NO_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: AtoC ? ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT,NO_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: CtoB ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT,NO_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: AtoC ? ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT,NO_TAG,EXP_TAG;
	fi unless timeout;
	if
	:: CtoB ! ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: CtoB ! COOKIE_ECHO,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoC ? COOKIE_ACK,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? ABORT,EXP_TAG,NO_TAG;
	fi unless timeout;
	if
	:: AtoC ? INIT,NO_TAG,EXP_TAG;
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