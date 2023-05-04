ltl closed_to_other {
  always ((state[0] == ClosedState)
    implies (
        next (
         eventually (state[0] == ClosedState      ||
                     state[0] == EstablishedState ||
                     state[0] == CookieWaitState)) 
    ))
}