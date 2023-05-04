active proctype sctpB() {
CLOSED:
   old_state[1] = state[1];
   state[1] = ClosedState;
   do 
   /* Note - abort command and abort msg are not meaningful in CLOSED state,
    * because it is in fact a "fictional" state.  Thus they are considered OOTB.
    */
   :: AtoB ? INIT,_,1 -> generate_cookie(); BtoA ! INIT_ACK,1,1;
   :: UserB ? ASSOCIATE_CMD ->
      create_tcb(1);
      BtoA ! INIT,1,1;
      start_init_timer(1);
      command[1] = EmptyUserCommand;
      goto COOKIE_WAIT;
   :: AtoB ? COOKIE_ECHO,1,1 ->
      create_tcb(1);
      BtoA ! COOKIE_ACK,1,1;
      goto ESTABLISHED;
   :: full(AtoB)                     && 
      (!(AtoB  ? [INIT,_,1]))        &&
      (!(AtoB  ? [COOKIE_ECHO,1,1])) -> handle_ootb_msg(AtoB, BtoA);
   od
COOKIE_WAIT:
   old_state[1] = state[1];
   state[1] = CookieWaitState;
   do 
   :: AtoB ? INIT_ACK,1,1 ->
      old_state[1] = state[1];
      state[1] = IntermediaryCookieWaitState;
      BtoA ! COOKIE_ECHO,1,1;
      stop_init_timer(1);
      start_cookie_timer(1);
      goto COOKIE_ECHOED;
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: timers[1] == T1_INIT -> 
      if
      :: BtoA ! INIT,1,1;
      :: printf("ERROR - hit max retransmits of INIT.");
         delete_tcb(1);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(AtoB)                 &&
      (!(AtoB ? [INIT_ACK,1,1])) &&
      (!(AtoB ? [ABORT,1,1]))    -> handle_ootb_msg(AtoB, BtoA);
   od
COOKIE_ECHOED:
   old_state[1] = state[1];
   state[1] = CookieEchoedState;
   do 
   :: AtoB ? COOKIE_ACK,1,1 ->
      stop_cookie_timer(1);
      goto ESTABLISHED;
   /* This is not in the diagram. */
   :: AtoB ? COOKIE_ERROR,1,1 ->
      if
      :: BtoA ! INIT,1,1;
      :: report_could_not_establish();
      :: BtoA ! INIT,1,1; goto COOKIE_WAIT;
      fi
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: timers[1] == T1_COOKIE ->
      if
      :: BtoA ! COOKIE_ECHO,1,1;
      :: printf("ERROR - hit max retransmits of COOKIE_ECHO.");
         delete_tcb(1);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(AtoB)                     &&
      (!(AtoB ? [COOKIE_ACK,1,1]))   &&
      (!(AtoB ? [COOKIE_ERROR,1,1])) &&
      (!(AtoB ? [ABORT,1,1]))        -> handle_ootb_msg(AtoB, BtoA);
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
   :: AtoB ? SHUTDOWN,1,1 ->
      check_outstanding_data_chunks();
      goto SHUTDOWN_RECEIVED;
   :: AtoB ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: full(AtoB)                 &&
      (!(AtoB ? [ABORT,0,1]))    &&
      (!(AtoB ? [ABORT,1,1]))    &&
      (!(AtoB ? [SHUTDOWN,1,1])) -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_PENDING:
   old_state[1] = state[1];
   state[1] = ShutdownPendingState;
   do 
   :: nfull(BtoA)-> // no more outstanding
      BtoA ! SHUTDOWN,1,1;
      start_shutdown_timer(1);
      goto SHUTDOWN_SENT;
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: AtoB ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: full(AtoB) &&
      (!(AtoB ? [ABORT,1,1])) -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_SENT:
   old_state[1] = state[1];
   state[1] = ShutdownSentState;
   do 
   :: AtoB ? SHUTDOWN,1,1 ->
      BtoA ! SHUTDOWN_ACK,1,1;
      stop_shutdown_timer(1);
      start_shutdown_timer(1);
      goto SHUTDOWN_ACK_SENT;
   :: AtoB ? SHUTDOWN_ACK,1,1 ->
      stop_shutdown_timer(1);
      BtoA ! SHUTDOWN_COMPLETE,1,1;
      delete_tcb(1);
      goto CLOSED;
   /* NOT included in the diagram!  See line 3063 of the RFC. */
   :: AtoB  ? DATA,1,1  -> BtoA ! SHUTDOWN,1,1;
   :: AtoB  ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: timers[1] == T2_SHUTDOWN ->
      if
      :: BtoA ! SHUTDOWN,1,1;
      :: printf("ERROR - hit max retransmits of SHUTDOWN.");
         delete_tcb(1);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(AtoB)                     && 
      (!(AtoB ? [SHUTDOWN,1,1]))     &&
      (!(AtoB ? [SHUTDOWN_ACK,1,1])) &&
      (!(AtoB ? [DATA,1,1]))         &&
      (!(AtoB ? [ABORT,1,1]))        -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_RECEIVED:
   old_state[1] = state[1];
   state[1] = ShutdownReceivedState;
   do 
   :: nfull(BtoA) -> // no more outstanding
      BtoA ! SHUTDOWN_ACK,1,1;
      start_shutdown_timer(1);
      goto SHUTDOWN_ACK_SENT;
   /* NOT included in the diagram!  See line 3069 of the RFC. */
   :: BtoA ! DATA,1,1;
   :: AtoB ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: full(AtoB) &&
      (!(AtoB ? [ABORT,1,1])) -> handle_ootb_msg(AtoB, BtoA);
   od
SHUTDOWN_ACK_SENT:
   old_state[1] = state[1];
   state[1] = ShutdownAckSentState;
   do 
   :: AtoB ? SHUTDOWN_COMPLETE,1,1 ->
      stop_shutdown_timer(1);
      delete_tcb(1);
      goto CLOSED;
   :: AtoB ? SHUTDOWN_ACK,1,1 ->
      stop_shutdown_timer(1);
      BtoA ! SHUTDOWN_COMPLETE,1,1;
      delete_tcb(1);
      goto CLOSED;
   :: AtoB ? ABORT,1,1 -> handle_abort_msg(AtoB, 1);
   :: UserB ? ABORT_CMD -> handle_abort_cmd(UserB, BtoA, 1);
   :: full(AtoB)                          &&
      (!(AtoB ? [SHUTDOWN_COMPLETE,1,1])) &&
      (!(AtoB ? [SHUTDOWN_ACK,1,1]))      &&
      (!(AtoB ? [ABORT,1,1]))             -> handle_ootb_msg(AtoB, BtoA);
   od
end:
}