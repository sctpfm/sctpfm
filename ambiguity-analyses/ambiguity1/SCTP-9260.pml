mtype:msgs = { 
  INIT,
  INIT_ACK,
  ABORT,
  SHUTDOWN,
  SHUTDOWN_ACK,
  COOKIE_ECHO,
  COOKIE_ACK,
  SHUTDOWN_COMPLETE,
  COOKIE_ERROR,
  DATA,
  DATA_ACK
}

mtype:cmds = { SHUTDOWN_CMD, ASSOCIATE_CMD, ABORT_CMD }
mtype:timer = { T1_INIT, T1_COOKIE, T2_SHUTDOWN, NO_ACTIVE_TIMER }
mtype:tag = { NO_TAG, EXP_TAG, UNEX_TAG }

int old_state[2];
int state[2];
int command[2];
mtype:timer timers[2];

inline turn_off_timer(i) {
   timers[i] = NO_ACTIVE_TIMER;
}

#define ClosedState           0
#define CookieWaitState       1
#define CookieEchoedState     2
#define EstablishedState      3
#define ShutdownReceivedState 4
#define ShutdownAckSentState  5
#define ShutdownPendingState  6
#define ShutdownSentState     7

#define IntermediaryCookieWaitState 8

#define EmptyUserCommand     0
#define AbortUserCommand     1
#define AssociateUserCommand 2
#define ShutdownUserCommand  3

proctype user(chan usr) {
  do
  :: usr ! SHUTDOWN_CMD;  command[_pid % 2] = ShutdownUserCommand;
  :: usr ! ASSOCIATE_CMD; command[_pid % 2] = AssociateUserCommand;
  :: usr ! ABORT_CMD;     command[_pid % 2] = AbortUserCommand;
  od
}

bit active_tcb[2];

inline delete_tcb(i) {
   // assert (active_tcb[i] == 1);
   active_tcb[i] = 0;
}

inline create_tcb(i) {
   // assert (active_tcb[i] == 0);
   active_tcb[i] = 1;
}

inline start_init_timer(i) { 
   timers[i] = T1_INIT;
}

inline stop_init_timer(i) { 
   // assert(timers[i] == T1_INIT);
   turn_off_timer(i);
}

inline generate_cookie() { skip; }

inline start_cookie_timer(i) { 
   timers[i] = T1_COOKIE;
}

inline stop_cookie_timer(i) { 
   // assert(timers[i] == T1_COOKIE);
   turn_off_timer(i);
}

inline check_outstanding_data_chunks() { skip; }

inline stop_shutdown_timer(i) { 
   // assert(timers[i] == T2_SHUTDOWN);
   turn_off_timer(i);
}

inline start_shutdown_timer(i) { 
   timers[i] = T2_SHUTDOWN;
}

inline validate_cookie() { skip; }

inline report_could_not_establish() { 
   printf("Failed to establish."); 
}

chan AtoB = [1] of { mtype:msgs, mtype:tag, mtype:tag }; /* chunk, vtag, itag */
chan BtoA = [1] of { mtype:msgs, mtype:tag, mtype:tag }; /* chunk, vtag, itag */
chan UserA = [0] of { mtype:cmds };
chan UserB = [0] of { mtype:cmds };

init {
   active_tcb[0] = 0;
   active_tcb[1] = 0;
   state[0] = 0;
   state[1] = 0;
   old_state[0] = 0;
   old_state[1] = 1;
   // The order of these processes (A, B, A, B) is critical.
   run sctp(BtoA, AtoB, UserA);
   run sctp(AtoB, BtoA, UserB);
   run user(UserA);
   run user(UserB);
}

bool hasCVEpatch9260 = true;
bool everAborted = false;
bool everTimedOut = false;

inline handle_abort_cmd(usr, out, i) {
   everAborted = true;
   out ! ABORT,EXP_TAG,UNEX_TAG; /* Use the valid vtag, itag. */
   delete_tcb(i); 
   command[i] = EmptyUserCommand;
   goto CLOSED;
}

inline handle_abort_msg(in, i) {
   delete_tcb(i);
   goto CLOSED;
}

inline handle_ootb_msg(in, out) {
   /* This indicates there is an incoming message but it is unexpected. */
   /* Proceed according to Section 8.4 of the SCTP RFC. */
   if
   /* 1. (In this model we always assume messages come from unicast IPs.) */
   /* 2. If it is an ABORT, we silently discard it. */
   :: in ? ABORT,UNEX_TAG,NO_TAG -> skip;
   /* 3. If it's an INIT with the itag = 0, proceed per Section 5.1. */
   :: in ? INIT,NO_TAG,UNEX_TAG -> 
      if
      :: hasCVEpatch9260 -> skip;
      :: else -> out ! ABORT,EXP_TAG,NO_TAG;
      fi
   /* 4. If the packet contains a COOKIE_ECHO in the first chunk, process per
    *    Section 5.1 */
   :: in ? COOKIE_ECHO,vtag,NO_TAG -> skip; // Unspecified in the RFC.
   /* 5. If the packet contains a SHUTDOWN_COMPLETE, silently discard it and
    *    perform no further action. */
   :: in ? SHUTDOWN_COMPLETE,vtag,NO_TAG -> skip;
   /* 6. Same for COOKIE_ERROR. */
   :: in ? COOKIE_ERROR,vtag,NO_TAG -> skip;
   /* 7. Respond with an ABORT having the same vtag as the msg. */
   :: in ? msg,UNEX_TAG,itag -> out ! ABORT,UNEX_TAG,NO_TAG;
   :: in ? msg,vtag,UNEX_TAG -> out ! ABORT,UNEX_TAG,NO_TAG;
   // 5.2.3 If an INIT_ACK chunk is received when not anticipated (not verbatim),
   // then we need to discard it.
   :: in ? INIT_ACK,EXP_TAG,NO_TAG -> skip;
   // 5.2.4 COOKIE_ECHO chunk when TCB exists. (now handled by handle_cookie_echo_tcb_exists)
   // :: in ? COOKIE_ECHO,EXP_TAG,NO_TAG -> goto ESTABLISHED;
   // 5.2.5 silently discard COOKIE_ACK
   :: in ? COOKIE_ACK,vtag,NO_TAG -> skip;
   fi
}

inline handle_cookie_echo_tcb_exists(vtag,itag,cstate) {
  if 
  /* 5.2.4 case (B) */
  :: vtag == EXP_TAG -> skip; 
  :: else ->
    /* 5.2.4 case (A) */
    if 
    :: cstate == ShutdownAckSentState -> out ! SHUTDOWN_ACK,EXP_TAG,NO_TAG;
    /* 5.2.4 Silently discard the packet */
    :: else -> skip;
    fi
  fi
}

proctype sctp(chan in, out, usr) {
mtype:msgs msg;
mtype:tag vtag;
mtype:tag itag;
CLOSED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ClosedState;
   do 
   :: in ? INIT,NO_TAG,EXP_TAG -> 
      generate_cookie(); 
      out ! INIT_ACK,EXP_TAG,EXP_TAG;
   :: usr ? ASSOCIATE_CMD ->
      create_tcb(_pid % 2);
      out ! INIT,NO_TAG,EXP_TAG;
      start_init_timer(_pid % 2);
      command[_pid % 2] = EmptyUserCommand;
      goto COOKIE_WAIT;
   :: in ? COOKIE_ECHO,EXP_TAG,NO_TAG ->
      create_tcb(_pid % 2);
      out ! COOKIE_ACK,EXP_TAG,NO_TAG;
      goto ESTABLISHED;
   :: full(in)                        && 
      (!(in ? [INIT,NO_TAG,EXP_TAG])) &&
      (!(in ? [COOKIE_ECHO,NO_TAG,EXP_TAG])) -> handle_ootb_msg(in, out);
   od
COOKIE_WAIT:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = CookieWaitState;
   do 
   :: in ? INIT_ACK,EXP_TAG,EXP_TAG ->
      old_state[_pid % 2] = state[_pid % 2];
      state[_pid % 2] = IntermediaryCookieWaitState;
      out ! COOKIE_ECHO,EXP_TAG,NO_TAG;
      stop_init_timer(_pid % 2);
      start_cookie_timer(_pid % 2);
      goto COOKIE_ECHOED;
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: timers[_pid % 2] == T1_INIT -> 
      if
      :: out ! INIT,NO_TAG,EXP_TAG;
      :: printf("ERROR - hit max retransmits of INIT.");
         delete_tcb(_pid % 2);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(in)                             &&
      (!(in ? [INIT_ACK,EXP_TAG,EXP_TAG])) &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG]))     -> handle_ootb_msg(in, out);
   od
COOKIE_ECHOED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = CookieEchoedState;
   do
   // ambiguity as described in 5.2.1; 
   :: in ? INIT,UNEX_TAG,UNEX_TAG ->
      out ! INIT_ACK,EXP_TAG,UNEX_TAG; 
      goto CLOSED;
   :: in ? COOKIE_ACK,EXP_TAG,NO_TAG ->
      stop_cookie_timer(_pid % 2);
      goto ESTABLISHED;
   /* This is not in the diagram. */
   :: in ? COOKIE_ERROR,EXP_TAG,NO_TAG ->
      if
      :: out ! INIT,NO_TAG,EXP_TAG;
      :: report_could_not_establish();
      :: out ! INIT,NO_TAG,EXP_TAG; goto COOKIE_WAIT;
      fi
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: timers[_pid % 2] == T1_COOKIE ->
      if
      :: out ! COOKIE_ECHO,EXP_TAG,NO_TAG;
      :: printf("ERROR - hit max retransmits of COOKIE_ECHO.");
         delete_tcb(_pid % 2);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(in)                                &&
      (!(in ? [COOKIE_ACK,EXP_TAG,NO_TAG]))   &&
      (!(in ? [COOKIE_ERROR,EXP_TAG,NO_TAG])) &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG]))        -> handle_ootb_msg(in, out);
   od
ESTABLISHED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = EstablishedState;
   do 
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: usr ? SHUTDOWN_CMD ->
      check_outstanding_data_chunks();
      command[_pid % 2] = EmptyUserCommand;
      goto SHUTDOWN_PENDING;
   :: in ? SHUTDOWN,EXP_TAG,NO_TAG ->
      check_outstanding_data_chunks();
      goto SHUTDOWN_RECEIVED;
   :: in ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: in ? COOKIE_ECHO,vtag,itag -> handle_cookie_echo_tcb_exists(vtag,itag,EstablishedState);
   :: full(in)                               &&
      // (!(in ? [COOKIE_ECHO,EXP_TAG,NO_TAG])) &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG]))       &&
      (!(in ? [SHUTDOWN,EXP_TAG,NO_TAG]))    -> handle_ootb_msg(in, out);
   od
SHUTDOWN_PENDING:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownPendingState;
   do 
   :: nfull(out)-> // no more outstanding
      out ! SHUTDOWN,EXP_TAG,NO_TAG;
      start_shutdown_timer(_pid % 2);
      goto SHUTDOWN_SENT;
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: in ? COOKIE_ECHO,vtag,itag -> handle_cookie_echo_tcb_exists(vtag,itag,ShutdownPendingState);
   :: full(in) &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG])) -> handle_ootb_msg(in, out);
   od
SHUTDOWN_SENT:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownSentState;
   do 
   :: in ? SHUTDOWN,EXP_TAG,NO_TAG ->
      out ! SHUTDOWN_ACK,EXP_TAG,NO_TAG;
      stop_shutdown_timer(_pid % 2);
      start_shutdown_timer(_pid % 2);
      goto SHUTDOWN_ACK_SENT;
   :: in ? SHUTDOWN_ACK,EXP_TAG,NO_TAG ->
      stop_shutdown_timer(_pid % 2);
      out ! SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG;
      delete_tcb(_pid % 2);
      goto CLOSED;
   /* NOT included in the diagram!  See line 3063 of the RFC. */
   :: in  ? DATA,EXP_TAG,NO_TAG  -> out ! SHUTDOWN,EXP_TAG,NO_TAG;
   :: in  ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? COOKIE_ECHO,vtag,itag -> handle_cookie_echo_tcb_exists(vtag,itag,ShutdownSentState);
   :: timers[_pid % 2] == T2_SHUTDOWN ->
      if
      :: out ! SHUTDOWN,EXP_TAG,NO_TAG;
      :: printf("ERROR - hit max retransmits of SHUTDOWN.");
         delete_tcb(_pid % 2);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(in)                                && 
      (!(in ? [SHUTDOWN,EXP_TAG,NO_TAG]))     &&
      (!(in ? [SHUTDOWN_ACK,EXP_TAG,NO_TAG])) &&
      (!(in ? [DATA,EXP_TAG,NO_TAG]))         &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG]))        -> handle_ootb_msg(in, out);
   od
SHUTDOWN_RECEIVED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownReceivedState;
   do 
   :: nfull(out) -> // no more outstanding
      out ! SHUTDOWN_ACK,EXP_TAG,NO_TAG;
      start_shutdown_timer(_pid % 2);
      goto SHUTDOWN_ACK_SENT;
   /* NOT included in the diagram!  See line 3069 of the RFC. */
   :: out ! DATA,EXP_TAG,NO_TAG;
   :: in ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: in ? COOKIE_ECHO,vtag,itag -> handle_cookie_echo_tcb_exists(vtag,itag,ShutdownReceivedState);
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: full(in) &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG])) -> handle_ootb_msg(in, out);
   od
SHUTDOWN_ACK_SENT:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownAckSentState;
   do 
   :: in ? SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG ->
      stop_shutdown_timer(_pid % 2);
      delete_tcb(_pid % 2);
      goto CLOSED;
   :: in ? SHUTDOWN_ACK,EXP_TAG,NO_TAG ->
      stop_shutdown_timer(_pid % 2);
      out ! SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG;
      delete_tcb(_pid % 2);
      goto CLOSED;
   :: in ? ABORT,EXP_TAG,NO_TAG -> handle_abort_msg(in, _pid % 2);
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   // :: in ? COOKIE_ECHO,EXP_TAG,NO_TAG -> out ! SHUTDOWN_ACK,EXP_TAG,NO_TAG; // 5.2.4(A)
   :: in ? COOKIE_ECHO,vtag,itag -> handle_cookie_echo_tcb_exists(vtag,itag,ShutdownAckSentState);
   :: full(in)                                     &&
      (!(in ? [COOKIE_ECHO,EXP_TAG,NO_TAG]))       &&
      (!(in ? [SHUTDOWN_COMPLETE,EXP_TAG,NO_TAG])) &&
      (!(in ? [SHUTDOWN_ACK,EXP_TAG,NO_TAG]))      &&
      (!(in ? [ABORT,EXP_TAG,NO_TAG]))             -> handle_ootb_msg(in, out);
   od
end:
}

#define __instances_dijkstra 1
#define __instances_monitor 1
#define __instances_user 3
