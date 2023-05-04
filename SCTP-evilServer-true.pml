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
   run user(UserA);
   run user(UserB);
}

bool hasCVEpatch9260 = true;
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
   /* 1. (In this model we always assume messages come from unicast IPs.) */
   if
   /* 2. If it is an ABORT, we silently discard it. */
   :: in ? ABORT,_,0 -> skip;
   :: !(in ? [ABORT,_,0]) -> skip;
   fi
   if
   /* 3. If it's an INIT with the itag = 0, proceed per Section 5.1. */
   :: in ? INIT,_,0 -> 
      if
      :: hasCVEpatch9260 -> skip;
      :: else -> out ! ABORT,1,1;
      fi
   :: !(in ? [ABORT,_,0]) -> skip;
   fi
   if
   /* 4. If the packet contains a COOKIE_ECHO in the first chunk, process per
    *    Section 5.1 */
   :: in ? COOKIE_ECHO,_,_ -> skip; // Unspecified in the RFC.
   :: !(in ? [COOKIE_ECHO,_,_]) -> skip;
   fi
   if
   /* 5. If the packet contains a SHUTDOWN_COMPLETE, silently discard it and
    *    perform no further action. */
   :: in ? SHUTDOWN_COMPLETE,_,_ -> skip;
   :: !(in ? [SHUTDOWN_COMPLETE,_,_]) -> skip;
   fi
   if
   /* 6. Same for COOKIE_ERROR. */
   :: in ? COOKIE_ERROR,_,_ -> skip;
   :: !(in ? [COOKIE_ERROR,_,_]) -> skip;
   fi
   if
   /* 7. Respond with an ABORT having the same vtag as the msg. */
   :: in ? _,0,_ -> out ! ABORT,0,1;
   :: in ? _,1,0 -> out ! ABORT,1,1;
   :: (!(in ? [_,0,_])) &&
      (!(in ? [_,1,0])) -> skip;
   fi
}

active proctype sctpA() {
CLOSED:
   old_state[0] = state[0];
   state[0] = ClosedState;
   do 
   /* Note - abort command and abort msg are not meaningful in CLOSED state,
    * because it is in fact a "fictional" state.  Thus they are considered OOTB.
    */
   :: BtoA ? INIT,_,1 -> generate_cookie(); AtoB ! INIT_ACK,1,1;
   :: UserA ? ASSOCIATE_CMD ->
      create_tcb(0);
      AtoB ! INIT,1,1;
      start_init_timer(0);
      command[0] = EmptyUserCommand;
      goto COOKIE_WAIT;
   :: BtoA ? COOKIE_ECHO,1,1 ->
      create_tcb(0);
      AtoB ! COOKIE_ACK,1,1;
      goto ESTABLISHED;
   :: full(BtoA)                     && 
      (!(BtoA  ? [INIT,_,1]))        &&
      (!(BtoA  ? [COOKIE_ECHO,1,1])) -> handle_ootb_msg(BtoA, AtoB);
   od
COOKIE_WAIT:
   old_state[0] = state[0];
   state[0] = CookieWaitState;
   do 
   :: BtoA ? INIT_ACK,1,1 ->
      old_state[0] = state[0];
      state[0] = IntermediaryCookieWaitState;
      AtoB ! COOKIE_ECHO,1,1;
      stop_init_timer(0);
      start_cookie_timer(0);
      goto COOKIE_ECHOED;
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: BtoA ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: timers[0] == T1_INIT -> 
      if
      :: AtoB ! INIT,1,1;
      :: printf("ERROR - hit max retransmits of INIT.");
         delete_tcb(0);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(BtoA)                 &&
      (!(BtoA ? [INIT_ACK,1,1])) &&
      (!(BtoA ? [ABORT,1,1]))    -> handle_ootb_msg(BtoA, AtoB);
   od
COOKIE_ECHOED:
   old_state[0] = state[0];
   state[0] = CookieEchoedState;
   do 
   :: BtoA ? COOKIE_ACK,1,1 ->
      stop_cookie_timer(0);
      goto ESTABLISHED;
   /* This is not in the diagram. */
   :: BtoA ? COOKIE_ERROR,1,1 ->
      if
      :: AtoB ! INIT,1,1;
      :: report_could_not_establish();
      :: AtoB ! INIT,1,1; goto COOKIE_WAIT;
      fi
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: BtoA ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: timers[0] == T1_COOKIE ->
      if
      :: AtoB ! COOKIE_ECHO,1,1;
      :: printf("ERROR - hit max retransmits of COOKIE_ECHO.");
         delete_tcb(0);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(BtoA)                     &&
      (!(BtoA ? [COOKIE_ACK,1,1]))   &&
      (!(BtoA ? [COOKIE_ERROR,1,1])) &&
      (!(BtoA ? [ABORT,1,1]))        -> handle_ootb_msg(BtoA, AtoB);
   od
ESTABLISHED:
   old_state[0] = state[0];
   state[0] = EstablishedState;
   do 
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: UserA ? SHUTDOWN_CMD ->
      check_outstanding_data_chunks();
      command[0] = EmptyUserCommand;
      goto SHUTDOWN_PENDING;
   :: BtoA ? SHUTDOWN,1,1 ->
      check_outstanding_data_chunks();
      goto SHUTDOWN_RECEIVED;
   :: BtoA ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: full(BtoA)                 &&
      (!(BtoA ? [ABORT,0,1]))    &&
      (!(BtoA ? [ABORT,1,1]))    &&
      (!(BtoA ? [SHUTDOWN,1,1])) -> handle_ootb_msg(BtoA, AtoB);
   od
SHUTDOWN_PENDING:
   old_state[0] = state[0];
   state[0] = ShutdownPendingState;
   do 
   :: nfull(AtoB)-> // no more outstanding
      AtoB ! SHUTDOWN,1,1;
      start_shutdown_timer(0);
      goto SHUTDOWN_SENT;
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: BtoA ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: full(BtoA) &&
      (!(BtoA ? [ABORT,1,1])) -> handle_ootb_msg(BtoA, AtoB);
   od
SHUTDOWN_SENT:
   old_state[0] = state[0];
   state[0] = ShutdownSentState;
   do 
   :: BtoA ? SHUTDOWN,1,1 ->
      AtoB ! SHUTDOWN_ACK,1,1;
      stop_shutdown_timer(0);
      start_shutdown_timer(0);
      goto SHUTDOWN_ACK_SENT;
   :: BtoA ? SHUTDOWN_ACK,1,1 ->
      stop_shutdown_timer(0);
      AtoB ! SHUTDOWN_COMPLETE,1,1;
      delete_tcb(0);
      goto CLOSED;
   /* NOT included in the diagram!  See line 3063 of the RFC. */
   :: BtoA  ? DATA,1,1  -> AtoB ! SHUTDOWN,1,1;
   :: BtoA  ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: timers[0] == T2_SHUTDOWN ->
      if
      :: AtoB ! SHUTDOWN,1,1;
      :: printf("ERROR - hit max retransmits of SHUTDOWN.");
         delete_tcb(0);
         everTimedOut = true;
         goto CLOSED;
      fi
   :: full(BtoA)                     && 
      (!(BtoA ? [SHUTDOWN,1,1]))     &&
      (!(BtoA ? [SHUTDOWN_ACK,1,1])) &&
      (!(BtoA ? [DATA,1,1]))         &&
      (!(BtoA ? [ABORT,1,1]))        -> handle_ootb_msg(BtoA, AtoB);
   od
SHUTDOWN_RECEIVED:
   old_state[0] = state[0];
   state[0] = ShutdownReceivedState;
   do 
   :: nfull(AtoB) -> // no more outstanding
      AtoB ! SHUTDOWN_ACK,1,1;
      start_shutdown_timer(0);
      goto SHUTDOWN_ACK_SENT;
   /* NOT included in the diagram!  See line 3069 of the RFC. */
   :: AtoB ! DATA,1,1;
   :: BtoA ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: full(BtoA) &&
      (!(BtoA ? [ABORT,1,1])) -> handle_ootb_msg(BtoA, AtoB);
   od
SHUTDOWN_ACK_SENT:
   old_state[0] = state[0];
   state[0] = ShutdownAckSentState;
   do 
   :: BtoA ? SHUTDOWN_COMPLETE,1,1 ->
      stop_shutdown_timer(0);
      delete_tcb(0);
      goto CLOSED;
   :: BtoA ? SHUTDOWN_ACK,1,1 ->
      stop_shutdown_timer(0);
      AtoB ! SHUTDOWN_COMPLETE,1,1;
      delete_tcb(0);
      goto CLOSED;
   :: BtoA ? ABORT,1,1 -> handle_abort_msg(BtoA, 0);
   :: UserA ? ABORT_CMD -> handle_abort_cmd(UserA, AtoB, 0);
   :: full(BtoA)                          &&
      (!(BtoA ? [SHUTDOWN_COMPLETE,1,1])) &&
      (!(BtoA ? [SHUTDOWN_ACK,1,1]))      &&
      (!(BtoA ? [ABORT,1,1]))             -> handle_ootb_msg(BtoA, AtoB);
   od
end:
}