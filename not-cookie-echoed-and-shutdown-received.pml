ltl noCookieEchoedAndShutdownReceived {
   always (
      state[0] != CookieEchoedState || 
      state[1] != ShutdownReceivedState)
}