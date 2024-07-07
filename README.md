# ☎️ SCTP FM

This repository contains the code artifacts for *A Formal Analysis of SCTP: Attack Synthesis and Patch Verification* by  [Jacob Ginesin][1], [Max von Hippel][2], [Evan Defloor][3], [Cristina Nita-Rotaru][4], & [Michael Tüxen][5], to appear in [USENIX 2024][6].  A preprint of the paper can be found [here][7], and the associated SCTP RFC erratum can be found [here][8].

## Organization

The repository is organized as follows.
* `attacker-models/` contains our attacker models.  There are four: Off-Path, Evil-Server, Replay, and On-Path.  The correct inputs for each are given in the paper.  The [Makefile](korg-changes/Makefile) has a target for each to reproduce the corresponding results in our paper.
* `korg-changes/` contains our changes to [KORG](https://github.com/maxvonhippel/attackersynthesis), detailed in the paper.  To install these changes into a pre-existing KORG copy, follow the directions embedded in the [Dockerfile](Dockerfile).
* `packetdrill-tests/` contains the [PacketDrill](https://github.com/google/packetdrill) tests we ran to confirm that the Linux and FreeBSD implementations of SCTP did not misinterpret the ambiguous text outlined in the paper.
* `properties/` contains our ten LTL correctness properties for SCTP.
* `results/` contains copies of all the outputs we get from running our code (per the [Makefile](korg-changes/Makefile)).  For reproducibility, you can compare these outputs to those you get when you run the code, and they should match.
* `utils/` contains a simple utility script we wrote to run the new Replay Attack Synthesis functionality we added to KORG.
* Our [Dockerfile](Dockerfile) builds an environment with the attacker models and modified version of KORG in which you can easily run all the targets in the [Makefile](korg-changes/Makefile) to automatically reproduce our [results](results/).  You can also view the Dockerfile as providing documentation on how to do this natively on your laptop (i.e. how to update KORG with our changes, install our attacker models, and run the code).

## Requirements

This code has been tested on Linux Mint and Arch Linux using Intel hardware, and Mac OS using Apple Silicon.  The code requires at least 16Gb of RAM in order to run correctly.

## Usage

The easiest way to reproduce our results is using the [Dockerfile](Dockerfile).
To run using Docker, you need to [install Docker on your machine][9], then build the included Dockerfile. 
```
$ docker build . -t sctpfm
```
The entrypoint for the Dockerfile is `bash`, which you can use to interact with the [Makefile](korg-changes/Makefile). 
```
$ docker run -t sctpfm
```
The Makefile has targets to reproduce each result.
* `sctpOffPath`: Generates the Off-Path attacks for all 10 properties, with and without the patch.
* `sctpEvilServer`: Generates the Evil-Server attacks for all 10 properties, with and without the patch.
* `sctpOnPath`: Generates the On-path attacks for all 10 prop- erties, with and without the patch.
* `sctpReplay`: Generates the Replay attacks for all 10 prop- erties, with and without the patch.

Running all of the targets in the Makefile, inside the Docker image, should reproduce the results saved in the results directory of our artifacts (or produce equivalent outputs). Doing this from start to finish might take 24 hours. Note, the targets cannot be run simultaneously; you must wait until one finishes before running the next. This is for two reasons. First, [SPIN][10] creates intermediary files, and if two SPIN instances are run at once in the same folder, one can gobble the files created by the other, leading to crashes or unsound results. And second, model checking involves constructing and storing a large state space in memory, an operation that is inherently difficult and out of the scope of this project to parallelize.

In addition to these four targets, the code artifacts also allow you to analyze the two ambiguities described in the paper.
You can generate attacks against the first ambiguity by running:
```
python3 korg/Korg.py \
    --model=demo/SCTP/ambiguity1/SCTP-9260.pml \
    --phi=demo/SCTP/ambiguity1/phi.pml \
    --Q=demo/SCTP/ambiguity1/Q.pml \
    --IO=demo/SCTP/ambiguity1/IO.txt \
    --max_attacks=10 \
    --with_recovery=true \
    --name=ambiguity1 \
    --characterize=false
```
or against the second ambiguity by running:
```
python3 korg/Korg.py \
    --model=demo/SCTP/ambiguity2/SCTP-9260.pml \
    --phi=demo/SCTP/ambiguity2/phi.pml \
    --Q=demo/SCTP/ambiguity2/Q.pml \
    --IO=demo/SCTP/ambiguity2/IO.txt \
    --max_attacks=10 \
    --with_recovery=true \
    --name=ambiguity2 \
    --characterize=false
```
Once you’ve produced all the attacks you can analyze them by looking at the resulting attacker code saved in `out` inside the Docker image.

[1]: https://jakegines.in/
[2]: https://mxvh.pl/
[3]: https://defloor.info/
[4]: https://cnitarot.github.io/
[5]: https://www.fh-muenster.de/eti/personen/professoren/tuexen/
[6]: https://www.usenix.org/conference/usenixsecurity24
[7]: https://cnitarot.github.io/papers/sctp_usenix2024.pdf
[8]: https://www.rfc-editor.org/errata/rfc9260
[9]: https://docs.docker.com/get-docker/
[10]: https://spinroot.com/
