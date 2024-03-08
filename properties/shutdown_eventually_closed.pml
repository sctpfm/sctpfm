ltl shutdown_eventually_closed {
  always (
      (old_state[0] == EstablishedState && (state[0] == ShutdownSentState || state[0] == ShutdownReceivedState))
    )
    implies (
        eventually (state[0] == ClosedState)
    )
}