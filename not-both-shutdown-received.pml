ltl neverBothShutdownReceived {
  always (
      state[0] != ShutdownReceivedState || 
      state[1] != ShutdownReceivedState)
}