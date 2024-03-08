sctpOffPath:
	for PATCH in "true" "false"; do \
		for IO in "establish" "teardown"; do \
			for PHI in $$(ls demo/SCTP/canonical-properties/); \
				do echo "Attacking SCTP w.r.t. "$$PHI", patch="$$PATCH", IO="$$IO; \
				   time python3 korg/Korg.py                   \
					--model=demo/SCTP/SCTP-$$PATCH.pml         \
					--phi=demo/SCTP/canonical-properties/$$PHI \
					--Q=demo/SCTP/Q.pml                        \
					--IO=demo/SCTP/IO-$$IO.txt                 \
					--max_attacks=10                           \
					--with_recovery=True                       \
					--name=SCTP.$$PHI-offPath-$$IO-$$PATCH     \
					--characterize=False;                      \
				done; done; done;

sctpEvilServer:
	for PATCH in "true" "false"; do \
		for PHI in $$(ls demo/SCTP/canonical-properties/); \
			do echo "Attacking SCTP w.r.t. "$$PHI" (evil server TM), patch="$$PATCH; \
			   time python3 korg/Korg.py                   \
				--model=demo/SCTP/SCTP-evilServer-$$PATCH.pml \
				--phi=demo/SCTP/canonical-properties/$$PHI \
				--Q=demo/SCTP/Q-evilServer.pml             \
				--IO=demo/SCTP/IO-evilServer.txt           \
				--max_attacks=10                           \
				--with_recovery=True                       \
				--name=SCTP.$$PHI-evilServer-$$PATCH       \
				--characterize=False;                      \
			done; done;

sctpOnPath:
	for PATCH in "true" "false"; do \
		for IO in "establish" "teardown"; do \
			for PHI in $$(ls demo/SCTP/canonical-properties/); \
				do echo "Attacking SCTP w.r.t. "$$PHI" (on path TM), patch="$$PATCH", IO="$$IO; \
				   time python3 korg/Korg.py                   \
					--model=demo/SCTP/SCTP-onPath-$$PATCH.pml  \
					--phi=demo/SCTP/canonical-properties/$$PHI \
					--Q=demo/SCTP/Q-chan.pml                   \
					--IO=demo/SCTP/IO-onPath-$$IO.txt          \
					--max_attacks=10                           \
					--with_recovery=True                       \
					--name=SCTP.$$PHI-onPath-$$IO-$$PATCH      \
					--characterize=False;                      \
				done; done; done;

sctpReplay:
	python korg/gen_replay_attacker.py \
		--model=demo/SCTP/tsn_sctp_model.pml \
		--attacker=replay_mem \
		--inchan=AtoB \
		--outchan=AtoB \
		--output=replayExperiment/output.pml \
		--mem=2
	cd replayExperiment && \
		bash tester.sh output.pml ../demo/SCTP/canonical-properties out

clean:
	- rm -rf __pycache__
	- rm -rf tests/__pycache__
	- rm -rf out/*
	- rm *.trail
	- rm *.pml
	- rm ./*.pml
	- rm *pan*
	- rm *.tcl
	- rm .*.swp
	- rm *.pyc
	- rm test_exp*
	- rm ._n_i_p_s_
	- rm **.tmp
	- rm *.txt
	echo "All clean!"
