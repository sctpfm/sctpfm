/* spin -t9 -s -r -p -g SCTP.no-half-open.pml-offPath-establish-false_daisy_check.pml */
active proctype attacker() {
	
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ECHO,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ACK,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! COOKIE_ECHO,UNEX_TAG,NO_TAG;
	fi unless timeout;
	if
	:: BtoA ! INIT,NO_TAG,UNEX_TAG;
	fi unless timeout;
// recovery to N
// N begins here ... 

	skip; // Does nothing, because we are talking
	// about an off-path attacker.

}