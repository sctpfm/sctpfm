ltl no_stuck_states {
   (always (eventually 
      (state[0] != old_state[0] ||
       state[1] != old_state[1] ||
       (state[0] == ClosedState && state[1] == ClosedState) ||
       (state[0] == EstablishedState && state[1] == EstablishedState))))
}