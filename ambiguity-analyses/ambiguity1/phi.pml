ltl no_half_open {
   always (
      (old_state[0] == EstablishedState &&
            old_state[1] == ClosedState &&
            everAborted == false &&
            everTimedOut == false &&
            old_state[1] != state[1]) ->
               (state[1] == EstablishedState ||
                state[1] == IntermediaryCookieWaitState))
}
