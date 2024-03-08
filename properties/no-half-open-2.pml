ltl no_half_open_2 {
   always (
      (old_state[1] == EstablishedState &&
            old_state[0] == ClosedState &&
            everAborted == false &&
            everTimedOut == false &&
            old_state[0] != state[0]) ->
               (state[0] == EstablishedState ||
                state[0] == IntermediaryCookieWaitState))
}
