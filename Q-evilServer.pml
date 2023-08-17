active proctype sctpB() {
CLOSED:
   old_state[1] = state[1];
   state[1] = ClosedState;
   do 
   :: AtoB ? INIT,NO_TAG,EXP_TAG -> 
      generate_cookie(); 
      BtoA ! INIT_ACK,EXP_TAG,EXP_TAG;
   :: UserB ? ASSOCIATE_CMD ->
      create_tcb(1);
      BtoA ! INIT,NO_TAG,EXP_TAG;
      start_init_timer(1);
      command[1] = EmptyUserCommand;
      goto COOKIE_WAIT;
   :: AtoB ? COOKIE_ECHO,EXP_TAG,NO_TAG ->
      create_tcb(1);
      BtoA ! COOKIE_ACK,EXP_TAG,NO_TAG;
      goto ESTABLISHED;
   :: full(AtoB)                        && 
      (!(AtoB ? [INIT,NO_TAG,EXP_TAG])) &&
      (!(AtoB ? [COOKIE_ECHO,NO_TAG,EXP_TAG])) -> handle_ootb_msg(AtoB, BtoA);
   od
COOKIE_WAIT:
   old_state[1] = state[1];
   state[1] = CookieWaitState;
   do 
   :: AtoB ? INIT_ACK,EXP_TAG,EXP_TAG ->
      old_state[1] = state[1];
      state[1] = IntermediaryCookieWaitState;
      BtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
      stop_init_timer(1);
      start_cookie_timer(1);
      goto COOKIE_ECHOED;
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(BtoA, 1);
   :: timers[1] == T1_INIT -> 
      if
      :: BtoA ! INIT,NO_TAG,EXP_TAG;
      :: printf("ERROR - hit max retransmits of INIT.");
         delete_tcb(1);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: AtoB ? INIT,NO_TAG,EXP_TAG -> BtoA ! INIT_ACK,EXP_TAG,EXP_TAG;
   :: AtoB ? INIT,NO_TAG,UNEX_TAG -> BtoA ! INIT_ACK,UNEX_TAG,EXP_TAG;
   :: full(AtoB)                             &&
      (!(AtoB ? [INIT,NO_TAG,_]))            &&
      (!(AtoB ? [INIT_ACK,EXP_TAG,EXP_TAG])) &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG]))     -> handle_ootb_msg(AtoB, BtoA);
   od
COOKIE_ECHOED:
   old_state[1] = state[1];
   state[1] = CookieEchoedState;
   do 
   :: AtoB ? COOKIE_ACK,EXP_TAG,NO_TAG ->
      stop_cookie_timer(1);
      goto ESTABLISHED;
   :: AtoB ? COOKIE_ERROR,EXP_TAG,NO_TAG ->
      if
      :: BtoA ! INIT,NO_TAG,EXP_TAG;
      :: report_could_not_establish();
      :: BtoA ! INIT,NO_TAG,EXP_TAG; goto COOKIE_WAIT;
      fi
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(AtoB, 1);
   :: timers[1] == T1_COOKIE ->
      if
      :: BtoA ! COOKIE_ECHO,EXP_TAG,NO_TAG;
      :: printf("ERROR - hit max retransmits of COOKIE_ECHO.");
         delete_tcb(1);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(AtoB)                                &&
      (!(AtoB ? [COOKIE_ACK,EXP_TAG,NO_TAG]))   &&
      (!(AtoB ? [COOKIE_ERROR,EXP_TAG,NO_TAG])) &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG]))        -> handle_ootb_msg(AtoB, BtoA);
   od
ESTABLISHED:
   old_state[1] = state[1];
   state[1] = EstablishedState;
   do 
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: UserB ? SHUTDOWN_CMD ->
      check_outstanding_data_chunks();
      command[1] = EmptyUserCommand;
      goto SHUTDOWN_PENDING;
   :: AtoB ? SHUTDOWN,EXP_TAG,NO_TAG ->
      check_outstanding_data_chunks();
      goto SHUTDOWN_RECEIVED;
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(AtoB, 1);
   :: full(AtoB)                               &&
      (!(AtoB ? [COOKIE_ECHO,EXP_TAG,NO_TAG])) &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG]))       &&
      (!(AtoB ? [SHUTDOWN,EXP_TAG,NO_TAG]))    -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_PENDING:
   old_state[1] = state[1];
   state[1] = ShutdownPendingState;
   do 
   :: nfull(BtoA) ->
      BtoA ! SHUTDOWN,EXP_TAG,NO_TAG;
      start_shutdown_timer(1);
      goto SHUTDOWN_SENT;
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(AtoB, 1);
   :: full(AtoB) &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG])) -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_SENT:
   old_state[1] = state[1];
   state[1] = ShutdownSentState;
   do 
   :: AtoB ? SHUTDOWN,EXP_TAG,NO_TAG ->
      BtoA ! SHUTDOWN_ACK,EXP_TAG,NO_TAG;
      stop_shutdown_timer(1);
      start_shutdown_timer(1);
      goto SHUTDOWN_ACK_SENT;
   :: AtoB ? SHUTDOWN_ACK,EXP_TAG,NO_TAG ->
      stop_shutdown_timer(1);
      BtoA ! SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG;
      delete_tcb(1);
      goto CLOSED;
   :: AtoB ? DATA,EXP_TAG,NO_TAG  -> BtoA ! SHUTDOWN,EXP_TAG,NO_TAG;
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(AtoB, 1);
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: timers[1] == T2_SHUTDOWN ->
      if
      :: BtoA ! SHUTDOWN,EXP_TAG,NO_TAG;
      :: printf("ERROR - hit max retransmits of SHUTDOWN.");
         delete_tcb(1);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(AtoB)                                && 
      (!(AtoB ? [SHUTDOWN,EXP_TAG,NO_TAG]))     &&
      (!(AtoB ? [SHUTDOWN_ACK,EXP_TAG,NO_TAG])) &&
      (!(AtoB ? [DATA,EXP_TAG,NO_TAG]))         &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG]))        -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_RECEIVED:
   old_state[1] = state[1];
   state[1] = ShutdownReceivedState;
   do 
   :: nfull(BtoA) ->
      BtoA ! SHUTDOWN_ACK,EXP_TAG,NO_TAG;
      start_shutdown_timer(1);
      goto SHUTDOWN_ACK_SENT;
   :: BtoA ! DATA,EXP_TAG,NO_TAG;
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(AtoB, 1);
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: full(AtoB) &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG])) -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_ACK_SENT:
   old_state[1] = state[1];
   state[1] = ShutdownAckSentState;
   do 
   :: AtoB ? SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG ->
      stop_shutdown_timer(1);
      delete_tcb(1);
      goto CLOSED;
   :: AtoB ? SHUTDOWN_ACK,EXP_TAG,NO_TAG ->
      stop_shutdown_timer(1);
      BtoA ! SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG;
      delete_tcb(1);
      goto CLOSED;
   :: AtoB ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(AtoB, 1);
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? COOKIE_ECHO,EXP_TAG,NO_TAG -> BtoA ! SHUTDOWN_ACK,EXP_TAG,NO_TAG; // 5.2.4(A)
   :: full(AtoB)                                     &&
      (!(AtoB ? [COOKIE_ECHO,EXP_TAG,NO_TAG]))       &&
      (!(AtoB ? [SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG])) &&
      (!(AtoB ? [SHUTDOWN_ACK,EXP_TAG,NO_TAG]))      &&
      (!(AtoB ? [ABORT,EXP_TAG,NO_TAG]))             -> handle_ootb_msg(AtoB, BtoA);
   od
end:
}