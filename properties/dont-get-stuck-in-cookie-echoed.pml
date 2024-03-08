ltl not_stuck_in_cookie_echoed {
	always (eventually (state[0] != CookieEchoedState ||
		                timers[0] == T1_COOKIE))
}