# SCTP FM Project

This repository contains the minimal set of code needed to reproduce all the results reported in the SCTP FM paper (currently under submission).

The repository is organized as follows.
* `attacker-models/` contains our attacker models.  There are four: Off-Path, Evil-Server, Replay, and On-Path.  The correct inputs for each are given in the paper.  The [Makefile](korg-changes/Makefile) has a target for each to reproduce the corresponding results in our paper.
* `korg-changes/` contains our changes to [KORG](https://github.com/maxvonhippel/attackersynthesis), detailed in the paper.  To install these changes into a pre-existing KORG copy, follow the directions embedded in the [Dockerfile](Dockerfile).
* `packetdrill-tests/` contains the [PacketDrill](https://github.com/google/packetdrill) tests we ran to confirm that the Linux and FreeBSD implementations of SCTP did not misinterpret the ambiguous text outlined in the paper.
* `properties/` contains our ten LTL correctness properties for SCTP.
* `results/` contains copies of all the outputs we get from running our code (per the [Makefile](korg-changes/Makefile)).  For reproducibility, you can compare these outputs to those you get when you run the code, and they should match.
* `utils/` contains a simple utility script we wrote to run the new Replay Attack Synthesis functionality we added to KORG.
* Our [Dockerfile](Dockerfile) builds an environment with the attacker models and modified version of KORG in which you can easily run all the targets in the [Makefile](korg-changes/Makefile) to automatically reproduce our [results](results/).  You can also view the Dockerfile as providing documentation on how to do this natively on your laptop (i.e. how to update KORG with our changes, install our attacker models, and run the code).
