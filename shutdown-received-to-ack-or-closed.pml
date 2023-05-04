ltl shutdown_rcvd_to_ack_or_closed {
   always ((
      state[0] != old_state[0] &&
      old_state[0] == ShutdownReceivedState) ->
         (state[0] == ShutdownAckSentState ||
          state[0] == ClosedState))
}