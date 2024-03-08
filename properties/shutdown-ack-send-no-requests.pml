ltl shutdown_ack_send_no_requests {
   always (
      (state[0] != old_state[0] &&
       old_state[0] == ShutdownAckSentState) ->
            (state[0] == ClosedState))
}