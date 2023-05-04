// this model is up-to-date as of April 6th, 2023
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

inline generate_cookie() { skip; /* TODO */ }

inline start_cookie_timer(i) { 
   timers[i] = T1_COOKIE;
}

inline stop_cookie_timer(i) { 
   // assert(timers[i] == T1_COOKIE);
   turn_off_timer(i);
}

inline check_outstanding_data_chunks() { skip; /* TODO */ }

inline stop_shutdown_timer(i) { 
   // assert(timers[i] == T2_SHUTDOWN);
   turn_off_timer(i);
}

inline start_shutdown_timer(i) { 
   timers[i] = T2_SHUTDOWN;
}

inline validate_cookie() { skip; /* TODO */ }

inline report_could_not_establish() { 
   printf("Failed to establish."); 
}

chan AtoB = [1] of { mtype:msgs, bit, bit }; /* chunk, vtag, itag */
chan BtoA = [1] of { mtype:msgs, bit, bit }; /* chunk, vtag, itag */
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

bool hasCVEpatch9260 = false;
bool everAborted = false;
bool everTimedOut = false;

inline handle_abort_cmd(usr, out, i) {
   everAborted = true;
   out ! ABORT,1,1; /* Use the valid vtag, itag. */
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
   :: in ? ABORT,_,0 -> skip;
   /* 3. If it's an INIT with the itag = 0, proceed per Section 5.1. */
   :: in ? INIT,_,0 -> 
      if
      :: hasCVEpatch9260 -> skip;
      :: else -> out ! ABORT,1,1;
      fi
   /* 4. If the packet contains a COOKIE_ECHO in the first chunk, process per
    *    Section 5.1 */
   :: in ? COOKIE_ECHO,_,_ -> skip; // Unspecified in the RFC.
   /* 5. If the packet contains a SHUTDOWN_COMPLETE, silently discard it and
    *    perform no further action. */
   :: in ? SHUTDOWN_COMPLETE,_,_ -> skip;
   /* 6. Same for COOKIE_ERROR. */
   :: in ? COOKIE_ERROR,_,_ -> skip;
   /* 7. Respond with an ABORT having the same vtag as the msg. */
   :: in ? _,0,_ -> out ! ABORT,0,1;
   :: in ? _,1,0 -> out ! ABORT,1,1;
   fi
}

proctype sctp(chan in, out, usr) {
CLOSED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ClosedState;
   do 
   /* Note - abort command and abort msg are not meaningful in CLOSED state,
    * because it is in fact a "fictional" state.  Thus they are considered OOTB.
    */
   :: in ? INIT,_,1 -> generate_cookie(); out ! INIT_ACK,1,1;
   :: usr ? ASSOCIATE_CMD ->
      create_tcb(_pid % 2);
      out ! INIT,1,1;
      start_init_timer(_pid % 2);
      command[_pid % 2] = EmptyUserCommand;
      goto COOKIE_WAIT;
   :: in ? COOKIE_ECHO,1,1 ->
      create_tcb(_pid % 2);
      out ! COOKIE_ACK,1,1;
      goto ESTABLISHED;
   :: full(in)                     && 
      (!(in  ? [INIT,_,1]))        &&
      (!(in  ? [COOKIE_ECHO,1,1])) -> handle_ootb_msg(in, out);
   od
COOKIE_WAIT:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = CookieWaitState;
   do 
   :: in ? INIT_ACK,1,1 ->
      old_state[_pid % 2] = state[_pid % 2];
      state[_pid % 2] = IntermediaryCookieWaitState;
      out ! COOKIE_ECHO,1,1;
      stop_init_timer(_pid % 2);
      start_cookie_timer(_pid % 2);
      goto COOKIE_ECHOED;
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: timers[_pid % 2] == T1_INIT -> 
      if
      :: out ! INIT,1,1;
      :: printf("ERROR - hit max retransmits of INIT.");
         delete_tcb(_pid % 2);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(in)                 &&
      (!(in ? [INIT_ACK,1,1])) &&
      (!(in ? [ABORT,1,1]))    -> handle_ootb_msg(in, out);
   od
COOKIE_ECHOED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = CookieEchoedState;
   do 
   :: in ? COOKIE_ACK,1,1 ->
      stop_cookie_timer(_pid % 2);
      goto ESTABLISHED;
   /* This is not in the diagram. */
   :: in ? COOKIE_ERROR,1,1 ->
      if
      :: out ! INIT,1,1;
      :: report_could_not_establish();
      :: out ! INIT,1,1; goto COOKIE_WAIT;
      fi
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: timers[_pid % 2] == T1_COOKIE ->
      if
      :: out ! COOKIE_ECHO,1,1;
      :: printf("ERROR - hit max retransmits of COOKIE_ECHO.");
         delete_tcb(_pid % 2);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(in)                     &&
      (!(in ? [COOKIE_ACK,1,1]))   &&
      (!(in ? [COOKIE_ERROR,1,1])) &&
      (!(in ? [ABORT,1,1]))        -> handle_ootb_msg(in, out);
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
   :: in ? SHUTDOWN,1,1 ->
      check_outstanding_data_chunks();
      goto SHUTDOWN_RECEIVED;
   :: in ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: full(in)                 &&
      (!(in ? [ABORT,0,1]))    &&
      (!(in ? [ABORT,1,1]))    &&
      (!(in ? [SHUTDOWN,1,1])) -> handle_ootb_msg(in, out);
   od
SHUTDOWN_PENDING:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownPendingState;
   do 
   :: nfull(out)-> // no more outstanding
      out ! SHUTDOWN,1,1;
      start_shutdown_timer(_pid % 2);
      goto SHUTDOWN_SENT;
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: in ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: full(in) &&
      (!(in ? [ABORT,1,1])) -> handle_ootb_msg(in, out);
   od
SHUTDOWN_SENT:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownSentState;
   do 
   :: in ? SHUTDOWN,1,1 ->
      out ! SHUTDOWN_ACK,1,1;
      stop_shutdown_timer(_pid % 2);
      start_shutdown_timer(_pid % 2);
      goto SHUTDOWN_ACK_SENT;
   :: in ? SHUTDOWN_ACK,1,1 ->
      stop_shutdown_timer(_pid % 2);
      out ! SHUTDOWN_COMPLETE,1,1;
      delete_tcb(_pid % 2);
      goto CLOSED;
   /* NOT included in the diagram!  See line 3063 of the RFC. */
   :: in  ? DATA,1,1  -> out ! SHUTDOWN,1,1;
   :: in  ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: timers[_pid % 2] == T2_SHUTDOWN ->
      if
      :: out ! SHUTDOWN,1,1;
      :: printf("ERROR - hit max retransmits of SHUTDOWN.");
         delete_tcb(_pid % 2);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(in)                     && 
      (!(in ? [SHUTDOWN,1,1]))     &&
      (!(in ? [SHUTDOWN_ACK,1,1])) &&
      (!(in ? [DATA,1,1]))         &&
      (!(in ? [ABORT,1,1]))        -> handle_ootb_msg(in, out);
   od
SHUTDOWN_RECEIVED:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownReceivedState;
   do 
   :: nfull(out) -> // no more outstanding
      out ! SHUTDOWN_ACK,1,1;
      start_shutdown_timer(_pid % 2);
      goto SHUTDOWN_ACK_SENT;
   /* NOT included in the diagram!  See line 3069 of the RFC. */
   :: out ! DATA,1,1;
   :: in ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: full(in) &&
      (!(in ? [ABORT,1,1])) -> handle_ootb_msg(in, out);
   od
SHUTDOWN_ACK_SENT:
   old_state[_pid % 2] = state[_pid % 2];
   state[_pid % 2] = ShutdownAckSentState;
   do 
   :: in ? SHUTDOWN_COMPLETE,1,1 ->
      stop_shutdown_timer(_pid % 2);
      delete_tcb(_pid % 2);
      goto CLOSED;
   :: in ? SHUTDOWN_ACK,1,1 ->
      stop_shutdown_timer(_pid % 2);
      out ! SHUTDOWN_COMPLETE,1,1;
      delete_tcb(_pid % 2);
      goto CLOSED;
   :: in ? ABORT,1,1 -> handle_abort_msg(in, _pid % 2);
   :: usr ? ABORT_CMD -> handle_abort_cmd(usr, out, _pid % 2);
   :: full(in)                          &&
      (!(in ? [SHUTDOWN_COMPLETE,1,1])) &&
      (!(in ? [SHUTDOWN_ACK,1,1]))      &&
      (!(in ? [ABORT,1,1]))             -> handle_ootb_msg(in, out);
   od
end:
}