from korg.CLI          import *
from korg.Characterize import *
from korg.Construct    import *
from korg.printUtils   import makeBlue
from glob              import glob

def main():
    args = getArgs()
    model, phi, Q, IO, max_attacks, \
        with_recovery, name, characterize = parseArgs(args)
    return body(model, phi, Q, IO, max_attacks, with_recovery, name, characterize)

def parseArgs(args):
    P, Q, IO, phi = (None,)*4
    if args.dir:
        demo_items = glob(args.dir)
        for item in demo_items:
            if 'P.pml' in item:
                P = item
            elif 'Q.pml' in item:
                Q = item
            elif 'Phi.pml' in item:
                phi = item
            elif 'IO.txt' in item:
                IO = item
    else:
        P, Q, IO, phi = args.model, args.Q, args.IO, args.phi
    
    return P,               \
        phi,                \
        Q,                  \
        IO,                 \
        args.max_attacks,   \
        args.with_recovery, \
        args.name,          \
        args.characterize

def checkArgs(max_attacks, phi, model, Q, basic_check_name, IO):
    if max_attacks == None or max_attacks < 1:
        printInvalidNum(max_attacks)
        return 1

    # Can we negate phi?  This is important.
    if not negateClaim(phi):
        printCouldNotNegateClaim(phi)
        return 2
    
    # Check validity: Does model || Q |= phi?
    # if not models(model, phi, Q, basic_check_name):
    #     printInvalidInputs(model, phi, Q)
    #     return 3
    
    # Get the IO.  Is it empty?
    if IO == None:
        return 4
    
    _IO = getIO(IO)
    if _IO == None or len(list(_IO)) == 0:
        printZeroIO(IO)
        return 5
    
    return _IO

def body(model, phi, Q, IO, max_attacks=1, \
         with_recovery=True, name=None, characterize=False,
         comparisons=[], doTestRemaining=False):
    '''
    Body attempts to find attackers against a given model. The attacker 
    is successful if the given phi is violated. The phi is initially 
    evaluated by being composed with Q. 

    @param model        : a promela model 
    @param phi          : LTL property satisfied by model || Q
    @param Q            : a promela model
    @param IO           : Input Output interface of Q's communication channels
    @param max_attacks  : how many attackers to generate
    @param with_recovery: should the attackers be with_recovery?
    @param name         : name of the files
    @param characterize : do you want us to characterize attackers after 
                          producing them?

    Other options are specialized for reproducing paper results.
    '''
    
    # The name of the file we use to check that model || Q |= phi
    basic_check_name  = name + "_model_Q_phi.pml"
    # The name of the file where we write daisy(Q)
    daisy_name        = name + "_daisy.pml"
    # The name of the file we use to check that (model, (Q), phi) has a 
    # with_recovery attacker
    with_recovery_phi_name   = name + "_with_recovery_phi.pml"
    # The subdirectory of out/ where we write our results
    attacker_name     = name + "_" + str(with_recovery)
    # The name of the file we use to check that model || daisy(Q) |/= phi
    daisy_models_name = name + "_daisy_check.pml" 

    IO = checkArgs(max_attacks, phi, model, Q, basic_check_name, IO)
    if IO in { 1, 2, 3, 4, 5 }:
        cleanUp()
        return IO
    IO = sorted(list(IO)) # sorted list of events
    # Make daisy attacker
    net, label = makeDaisy(IO, Q, with_recovery, daisy_name)
    daisy_string = makeDaisyWithEvents(IO, with_recovery, net, label)
    writeDaisyToFile(daisy_string, daisy_name)
    
    if with_recovery == False:
        daisyPhi = phi 
    else:
        daisyPhiString = makeDaisyPhiFinite(label, phi)
        with open(with_recovery_phi_name, "w") as fw:
            fw.write(daisyPhiString)
        daisyPhi = with_recovery_phi_name
            
    # model, phi, N, name
    _models = models(model, daisyPhi, daisy_name, daisy_models_name)

    print("Models? ", _models)
        
    if net == None or _models == True:
        printNoSolution(model, phi, Q, with_recovery)
        cleanUp()
        return 6

    if _models == None:
        # We need to indicate that it was a real timeout.
        print("This looks like a real timeout, or an exception in Spin -- see " + daisy_models_name)
        cleanUp()
        return 7 # New ret code, 7 means "timed out"
    
    makeAllTrails(daisy_models_name, max_attacks) 
    # second arg is max# attacks to make

    cycle_indicator = None if with_recovery == False else ( "[" + label + " = 1]" )

    cmds                = trailParseCMDs(daisy_models_name)
    attacks, provenance = parseAllTrails(cmds, 
                                         with_recovery=with_recovery, 
                                         debug=False, 
                                         cycle_indicator=cycle_indicator)

    print("Writing attacks ...")
    
    # Write these attacks to models
    writeAttacks(attacks, provenance, net, with_recovery, attacker_name)

    ret = None
    
    # Characterize the attacks
    if characterize:
        (E, A) = characterizeAttacks(model, phi, with_recovery, attacker_name)
        cleanUp()
        ret = 0 if (E + A) > 0 else -1
    else:
        cleanUp()
        ret = 0 # assume it worked if not asked to prove it ...

    print("Removing redundant attack files ...")

    attackPath = "out/" + name + "_" + str(with_recovery)
    removeRedundant(attackPath)
    
    # Are there other props named phiJ.pml for any J?
    # If so, let's try them!
    propFilename = phi.split("/")[-1]
    propPattern  = phi.replace(propFilename, "phi*.pml")
    otherProps   = [a for a in glob(propPattern)]

    """
    If you would like to test your attacks generated using model M'
    on some other model M, you can replace "model" in the line of code
    below with the path to M.  We don't hard-code this as a CLI option
    because it's unlikely anyone besides myself (Max) will ever need to
    do this.  For example:

      testRemaining(attackPath, "demo/DCCP/DCCP.pml", Q, otherProps)

    """
    if doTestRemaining == True:

        testRemaining(attackPath, model, Q, otherProps)
        for comparison in comparisons:
            print("\t testing if attacks transfer to " + comparison)
            testRemaining(attackPath, comparison, Q, otherProps, comparing=True)

    return ret

if __name__== "__main__":
    main()
