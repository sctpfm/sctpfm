import argparse
from   glob import glob
import os
import sys

def str2bool(v):
    if isinstance(v, bool):
       return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

def getArgs():
	parser = argparse.ArgumentParser(
		description='Synthesize a (P, phi)-Attacker.',
		formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser._action_groups.pop()
	required = parser.add_argument_group('required arguments')
	optional = parser.add_argument_group('optional arguments')

	required.add_argument(
		'--model', 
		metavar='model', 
		type=str, 
		help='A relative or absolute path to a Promela model of a protocol M ' \
			+ 'to be attacked, e.g. demo/TCP.pml.',
		required=False)
	required.add_argument(
		'--phi', 
		metavar='phi', 
		type=str, 
		help='A relative or absolute path to a Promela file containing an LTL '\
			+ 'claim phi about M and N, such that (M || N) |= phi, e.g. '\
			+ 'demo/noHalfOpenConnections.pml.',
		required=False)
	required.add_argument(
		'--Q',
		metavar='Q',
		type=str,
		help='A relative or absolute path to a Promela model of a protocol Q '\
			+ 'to be replaced and recovered-to by our attacker, e.g. '\
			+ 'demo/network.pml.',
		required=False)
	required.add_argument(
		'--IO',
		metavar='IO',
		type=str,
		help='The input-output interface of N, in a yaml-ish format.',
		required=False)
	required.add_argument(
		'--max_attacks',
		metavar='max_attacks',
		default=1,
		type=int,
		help='The maximum number of attackers to generate.',
		required=False)
	optional.add_argument(
		'--with_recovery',
		metavar='with_recovery',
		type=str2bool,
		default=False,
		nargs='?',
		const=True,
		help='True iff you want the recovered attackers to be attackers with '\
			+ 'recovery, else false.',
		required=False)
	required.add_argument(
		'--name',
		metavar='name',
		type=str,
		help='The name you want to give to this experiment.',
		required=True)
	optional.add_argument(
		'--characterize',
		metavar='characterize',
		type=str2bool,
		default=False,
		nargs='?',
		const=True,
		help='True iff you want the tool to tell you if the results are '\
			+ 'A-, E-, or not attackers at all.  May substantially add to '\
			+ 'runtime!',
		required=False)
	required.add_argument(
		'--dir',
		metavar='dir',
		type=str,
		help='The path to the directory that contains your models, directory '\
		    + 'MUST contain P.pml, Q.pml, Phi.pml, IO.txt.',
		required=False)

	if len(sys.argv[1:])==0:
	    parser.print_help()
	    print("\nNote: *either* --dir *or* (--phi, --P, --Q, and --IO) is " + \
	    	   "required.  This is an exclusive-or *either*.")
	    parser.exit()

	args = parser.parse_args()
	if (not (args.dir or 
		    (args.phi and args.Q and args.model and args.IO))):
		print("\nNote: *either* --dir *or* (--phi, --P, --Q, and --IO) is " + \
			   "required.  This is an exclusive-or *either*.")
		parser.exit()

	return args

trails = lambda : glob("*.trail")

def cleanUpTargeted(target):
	files = glob(target)
	for file in files:
		os.remove(file)

def cleanUp():
	cleanUpTargeted("*.trail"   )
	cleanUpTargeted("*tmp*"     )
	cleanUpTargeted("pan"       )
	cleanUpTargeted("*.pml"     )
	cleanUpTargeted("._n_i_p_s_")

def cleanUpAlias():
	cleanUp()

def addTrailNumberToArgs(args, num):
	ret = []
	for arg in args:
		if arg != "-t":
			ret.append(arg)
		else:
			if num > 0:
				ret.append(arg + str(num))
			else:
				ret.append(arg)
	return ret

def handleTs(args, name):
	args = args.split(" ")
	num  = len(glob(name + "*.trail"))
	if num == 0:
		return []
	elif num == 1:
		return [args]
	else:
		return [addTrailNumberToArgs(args, i) for i in range(0, num)]

def trailParseCMDs(tmpName):
	"""
	-t means "inspect a trail"
	-s means "show all send events"
	-r means "show all receive events"
	-p means "show all state changes at each time step"
	-g means "show global variable values at each time step"
	"""
	args = "spin -t -s -r -p -g " + tmpName
	return handleTs(args, tmpName)

# Error message for if we were handed apparently invalid inputs.
def printInvalidInputs(model, phi, N):
	print("In order for the problem (model, phi, N) to be non-trivial, we "\
		 + "require that (model || N) |= phi.  However, this does not appear "\
		 + "to be the case.")

# Error message for if we cannot find any solution.
def printNoSolution(model, phi, N, with_recovery):
	possiblyFinite = "with_recovery" if with_recovery else ""
	print("We could not find any " \
		  + possiblyFinite         \
		  + "(model, (N), phi)-attacker A.")

# Error message when we could not negate the claim phi.
def printCouldNotNegateClaim(phi):
	if phi == None:
		print("No property phi provided; giving up.")
	else:
		print("We could not negate the claim in " + phi + "; giving up.")

# Error message when we could not get any inputs or outputs.
def printZeroIO(IO):
	print("We could not find any inputs or outputs in " + IO + "; giving up.")

# Error message when num is too small
def printInvalidNum(num):
	print("--num option must be > 0, was: " + str(num) + "; giving up.")
