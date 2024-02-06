# SCTP FM Project

This repository contains the minimal set of code needed to reproduce all the results reported in the SCTP FM paper (currently under submission).

To run the code, download the latest version of [KORG](https://github.com/maxvonhippel/attackersynthesis), then replace the KORG code files with the ones contained in this project, and put all the IO, property, and model files into a folder called `SCTP` in the `demo` directory.  In particular the properties should be in `demo/SCTP/canonical-properties`.  The correct directory structure is made obvious by the Makefile. 

Then pip install as you would normally.

There are four attacker models: Off-Path, Evil-Server, Replay, and On-Path.  The correct inputs for each are given in the paper.  For all but Replay you're encouraged to use the Makefile to reproduce our results; for Replay you should use tester.sh which runs our new "Replay" mode for KORG.
