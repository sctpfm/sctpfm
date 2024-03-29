import subprocess
import sys
import os
from   glob            import glob
from   korg.Construct  import makeAttackTransferCheck
from   korg.printUtils import *
import traceback


def nontrivialProps(P, Q, props):
    ret = set()
    for phi in props:
        # We assume this file does not yet exist
        tmpname = str(abs(hash(P + Q + phi))) + ".temporary.pml"
        if models(P, phi, Q, tmpname, True):
            ret.add(phi)
        else:
            print(makeRed(                 \
                phi                        \
                + " was not supported by " \
                + P + " || " + Q           \
                + " so cannot be attacked."))
        bigCleanUp(tmpname)
    return list(ret)

def testRemaining(attackPath, P, Q, props, comparing=False, testWithoutRecovery=False):
    if attackPath[-1] != "/":
        attackPath += "/"
    # Remove any trivial props
    props = nontrivialProps(P, Q, props)
    
    recoveryOptions = [ True, False ] if testWithoutRecovery == True else [ True ]

    for attackerModel in glob(attackPath + "*.pml"):
        
        for phi in props:

            for _recovery in recoveryOptions:

                checkText = makeAttackTransferCheck(attackerModel, P, phi, _recovery)
                newname = str(abs(int(hash(checkText)))) + ".pml"
                with open(newname, "w") as fw:
                    fw.write(checkText)
                result = check(newname)
                if result == False:
                    print(
                        ("" if comparing == False 
                            else 
                            makeBlue("[ comparing to " + P + " ]\n\t\t")) +
                        makeGreen(
                            attackerModel                                  + 
                            " is an attack "                               +
                            ("with " if _recovery == True else "without ") +
                            "recovery against\n\t\t\t"                     + 
                            phi))
                elif result == True and comparing == True:
                    print(
                        makeFail(
                            "\n\t\t"                                   + 
                            attackerModel                              + 
                            " does ")                                  + 
                        makeBold("NOT")                                + 
                        makeFail(
                            "\n\t\twork as an attack " +
                            ( "with " if _recovery == True else "without ") +
                            "recovery against "                             +
                            phi                                             +
                            "\n\t\twhen applied to "                        +
                            P))
                os.remove(newname)


# Also adapted from RFCNLP code.
def bigCleanUp(cur_model_name):
    for file in glob("*.trail") + \
                glob("*tmp*")   + \
                glob("pan")     + \
                glob("*.pml")   + \
                glob("._n_i_p_s_"):
        if file != cur_model_name + ".pml" and \
           file != cur_model_name + "_CORRECT.pml":
            os.remove(file)

"""
Adapted from some logic in RFCNLP.
Deletes syntactically redundant attacks.
"""
def removeRedundant(attackPath):
    
    attacker_hashes = set()

    if attackPath[-1] != "/":
        attackPath += "/"
    
    for attacker in glob(attackPath + "*.pml"):

        print("Considering attacker " + attacker + " for possible removal")
        attacker_body = ""
        l = 0
        with open(attacker, "r") as fr:
            for line in fr:
                if (l > 0):
                    attacker_body += "\n" + line
                l += 1
        attacker_hash = hash(attacker_body)
        
        if (attacker_hash in attacker_hashes):
            print("Removing redundant attacker " + attacker)
            os.remove(attacker)
        
        else:
            attacker_hashes.add(attacker_hash)
            print("Did not remove.")

'''
Given the path to a model containing one or more properties,
checks if that model violates one or more of those properties.

INPUT:
    modelFile - the string containing the path to the model file
OUTPUT:
    true iff modelFile runs successfully without acceptance cycles
    or violations else false
'''
def check(modelFile, maxDepth=600000):

    print("Calling check(" + modelFile + ") ...")

    if maxDepth > 600000 * 4:
        print("maxDepth too large for any realistic run.  Edit the code if " \
            + "you actually really want to do this ... in Characterize.py.")
        return None

    args = "spin -run -a -DNOREDUCE -m" + str(maxDepth) + " " + str(modelFile)
    
    args = [a.strip() for a in args.split(" ")]
    args = [a for a in args if len(a) > 0]
    ret = None

    ret = ""
    print("Calling ", args)

    timedOut = False
    try:
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in iter(process.stdout.readline, b''):
            line = str(line.decode('utf-8'))
            if ("violated" in line) or ("acceptance cycle" in line):
                process.stdout.close()
                process.wait()
                return False
            
            if ("Search not completed" in line) or ("depth too small" in line):
                timedOut = True

        process.stdout.close()
        process.wait()
        
        if timedOut:
            print("Search depth was too small at " \
                + str(maxDepth), \
                " doubling depth ...")
            return check(modelFile, maxDepth * 2)
        
        if process.returncode != 0:
            print("ret code = ", process.returncode, " so returning None ....")
            return None
    
    except Exception as e:
        traceback.print_exception(e)
        print("An error occurred: ", e)
        return None

    return True

def makeAllTrails(modelFile, numTrails=100):
    args = ""
    commandPrefix = "spin -run -a -DNOREDUCE "
    if numTrails <= 1:
        args = commandPrefix + modelFile
    else:
        args = commandPrefix + "-e -c" + str(numTrails) + " " + modelFile
    subprocess.run(args.split(" "))
    
'''
Given the paths to a model and a property, checks if that 
model makes true that property.

INPUT:
    model - the string containing the path to the model file
    phi   - the string containing the path to the ltl model file
    N     - the string containing the path to the N model file
    name  - where to save the intermediary model file to
OUTPUTS:
    true iff the model (model || phi || N) runs successfully without
    acceptance cycles or violations else false
'''
def models(model, phi, N, name, removeAfter=False):
    
    if None in { model, phi, N, name }:
        print("None in arguments to models() ... some kind of bug.")
        return False
    
    fmrLines = ""
    fNrLines = ""
    fprLines = ""
    
    with open(model, 'r') as fmr:
        fmrLines = fmr.read()

    with open(N, 'r') as fNr:
        fNrLines = fNr.read()

    with open(phi, 'r') as fpr:
        fprLines = fpr.read()

    with open(name, 'w') as fw:
        fw.write(fmrLines + "\n" + fNrLines + "\n" + fprLines)

    assert(os.path.isfile(name))

    print("About to model check: \n\n" + 
        fmrLines + "\n" + fNrLines + "\n" + fprLines + 
        "\n\n")

    ret = check(name)

    if removeAfter == True:
        os.remove(name)

    return ret

# Parses output of reading trail using Spin.
def parseTrail(trail_body, cycle_indicator=None):

    print("\n\n-------------- PARSING TRAIL: \n")
    print(trail_body)

    with_recovery = True

    if cycle_indicator == None:
        with_recovery = False
        cycle_indicator = "CYCLE"

    ret, i = [[], []], 0

    for line in trail_body.split("\n"):

        if "(daisy:" in line:

            # https://stackoverflow.com/a/29571669/1586231
            LL = line.rstrip("*")
            chan = LL[line.rfind("(")+1:-1]
            msg, evt = None, None
            
            if "Recv " in line:
            
                msg = LL[line.rfind("Recv ") + 5:].split()[0]
                evt = "?"

            """
            Note - it would be tempting to think, "surely, Spin does not use both `Send` and
            `Sent` in its output, right?"  But, actually, Spin does exactly this, apparently
            depending on the size of the channel.  Here is an example:


             48:    proc  1 (peerB:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:156 Send DCCP_CLOSEREQ    -> queue 1 (BtoN)
             48:    proc  1 (peerB:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:156 (state 37)    [BtoN!DCCP_CLOSEREQ]
                    queue 1 (BtoN): [DCCP_CLOSEREQ]
             50:    proc  2 (daisy:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:217 Recv DCCP_CLOSEREQ    <- queue 1 (BtoN)
             50:    proc  2 (daisy:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:217 (state 13)    [BtoN?DCCP_CLOSEREQ]
                    queue 1 (BtoN): 
             52:    proc  1 (peerB:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:132 (state 13)    [before_state[1] = state[1]]
                    queue 1 (BtoN): 
             54:    proc  1 (peerB:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:133 (state 14)    [state[1] = 6]
                    state[0] = 0
                    state[1] = 6
                    queue 1 (BtoN): 
             56:    proc  2 (daisy:1) attack-promela-models.DCCP.props.phi1-DCCP-_daisy_check.pml:237 Sent DCCP_CLOSEREQ    -> queue 2 (NtoB)


            So, in order to support various channel semantics, we need to look for both!
            """
            
            if "Send" in line and msg == None and evt == None:
            
                msg = LL[line.rfind("Send ") + 5:].split()[0]
                evt = "!"

            if "Sent" in line and msg == None and evt == None:
            
                msg = LL[line.rfind("Sent ") + 5:].split()[0]
                evt = "!"
            
            if evt != None and msg != None:

                ret[i].append(chan + " " + evt + " " + msg)

            if cycle_indicator in line and (with_recovery == True):

                i = 1
        
        elif cycle_indicator in line and (with_recovery == False):
            
            i = 1

    print("\n\n----- parsed to: ")
    print("\n".join([str(r) for r in ret]))
    print("\n````````````````````````````````````````````````````")
    
    return ret

def parseAllTrails(cmds, with_recovery=False, debug=False, cycle_indicator=None):

    print("\n----> Calling parseAllTrails()")

    ret = []
    prov = []
    with open(os.devnull, 'w') as devnull:
        for cmd in cmds:
            output = subprocess.check_output(cmd, stderr=devnull)
            if sys.stdout.encoding != None:
                output = output.decode(sys.stdout.encoding)
            output = str(output).strip().replace("\\n", "\n")\
                                        .replace("\\t", "\t")
            parsed = parseTrail(output, cycle_indicator)
            ret.append(parsed)
            prov.append(cmd)
    return ret, prov

def attackType(A, E):
    # if A == 1 then E == 1
    # <=> not (A == 1 and E == 0)
    assert(not (A and not E))
    if A:
        return "A-attack"
    if E:
        return "E-attack"
    return "NOT AN ATTACK"

def characterizeAttacks(model, phi, with_recovery=True, name="run"):

    assert(os.path.isdir("out/" + name))

    nE, nA = 0, 0

    with open("out/" + name + "/log.txt", "w") as fw:

        if not (os.path.isdir("out/" + name + "/artifacts")):
            os.mkdir("out/" + name + "/artifacts")

        fw.write("model,A/E,with_recovery?\n")
        for attackModel in glob("out/" + name + "/attacker*.pml"):
            # is it a forall attack?
            attackName = os.path.basename(attackModel).replace(".pml", "")
            aName = "out/" + name + "/artifacts/" + attackName + "_A.pml"
            eName = "out/" + name + "/artifacts/" + attackName + "_E.pml"
            A = (models(model, "negated.pml", attackModel, aName) == True )
            E = (models(model, phi,           attackModel, eName) == False)
            if A:
                nA += 1
            elif E:
                nE += 1
            fw.write(",".join([ \
                attackModel, attackType(A, E), str(with_recovery)]) + "\n")
            
    return (nE, nA)
