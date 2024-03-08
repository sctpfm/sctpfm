FROM ubuntu:24.04

RUN DEBIAN_FRONTEND="noninteractive" apt-get -y update
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y upgrade
RUN DEBIAN_FRONTEND="noninteractive" \
    apt-get install -y apt-utils

RUN apt-get update -y && apt-get install -y python3-venv python3-pip
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip


RUN DEBIAN_FRONTEND="noninteractive"     \
    apt-get install -y build-essential   \
                       git               \
                       bison             \
                       flex              \
                       graphviz          \
                       time              \
                       tree
RUN pip3 install green


# Deal with locales so that updates & installs go through nicely
RUN apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Update and upgrade
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y

RUN apt-get update && \
    apt-get install -y wget make unzip


# Install Spin
RUN wget https://github.com/nimble-code/Spin/archive/refs/tags/version-6.5.2.zip
RUN unzip version-6.5.2.zip
WORKDIR Spin-version-6.5.2/Src
RUN mkdir -p /usr/local/share/man/man1/

RUN make install
WORKDIR ../..

# Install git and then KORG
RUN git clone https://github.com/maxvonhippel/AttackerSynthesis.git
WORKDIR AttackerSynthesis

# Make changes to KORG
COPY korg-changes/Characterize.py        korg/Characterize.py
COPY korg-changes/CLI.py                 korg/CLI.py
COPY korg-changes/Construct.py           korg/Construct.py
COPY korg-changes/gen_replay_attacker.py korg/gen_replay_attacker.py
COPY korg-changes/Korg.py                korg/Korg.py
COPY korg-changes/printUtils.py          korg/printUtils.py
COPY korg-changes/Makefile               Makefile

# Copy over attacker models
RUN mkdir demo/SCTP/
COPY properties demo/SCTP/canonical-properties
COPY attacker-models/evilServer/* demo/SCTP/.
COPY attacker-models/offPath/*    demo/SCTP/.
COPY attacker-models/onPath/*     demo/SCTP/.
COPY attacker-models/replay/*     demo/SCTP/.

RUN pip3 install .

# Set up the replay stuff
RUN mkdir replayExperiment
COPY utils/tester.sh replayExperiment/.

ENTRYPOINT ["/bin/bash"]
