ltl no_abort {
    always ((everAborted == false && everTimedOut == false) -> (everRcvdAbort == false))
}
