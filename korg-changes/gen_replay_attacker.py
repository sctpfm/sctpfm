# ==============================================================================
# File      : gen-attacker.py
# Author    : [Redacted]
# Authored  : 30 November 2023
# Purpose   : generate replay attackers on Promela channels
# ==============================================================================
import sys, re, subprocess, os

def show_help() -> None:
    msg = (
    "Usage: \n"
    "   python arslan.py [arguments] \n\n"
    "Arguments: \n"
    "   --model=path/to/model.pml               Promela model to generate attackers on\n"
    "   --attacker=[replay,replay_mem] \n"    
    "                                           Attacker model\n"
    "   --inchan=[input channel]                Input channel\n"
    "   --outchan=[output channel]              Output channel\n"
    "   --output=path/to/file.pml               Outputted file name\n"
    "   --mem=[number]                          size of memory (if memory attacker selected)\n"
    "   --reset-triggers=[array]                memory reset triggers (if memory attacker selected)\n"
    )
    print(msg)

def fileReadLines(fileName) -> str:
    try:
        txt = None
        with open(fileName, 'r') as fr:
            txt = fr.readlines()
        return txt
    except Exception:
        return ""

def fileRead(fileName) -> str:
    try:
        txt = None
        with open(fileName, 'r') as fr:
            txt = fr.read()
        return txt
    except Exception:
        return ""

def parse_channels(model) -> dict():
    channels = {}
    for line in model:
        if line.startswith("chan "):
            data = re.search("chan ([a-zA-Z\_\-]+).*\{(.+)\}", line)
            # note, we don't have to think very hard about parsing Promela types.
            # this is because mtype:whatever, mtype, and generic types are interchangable in Promela grammar
            name, ctype = data.group(1), data.group(2).replace(" ","").split(",")
            channels[name] = tuple(ctype)
        else : continue
    return channels

def ensure_compile(model_path) -> None:
    cmd = ['spin', model_path]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    filename = os.path.basename(model_path)
    userdir = os.getcwd()

    # Convert bytes to string
    stdout = stdout.decode()
    stderr = stderr.decode()
    assert "syntax error" not in stdout, "there seems to be a syntax error in the model"
    assert "processes created" in stdout, "the spin model creates no processes ... check to see if it compiles"

def gen_replay(model, in_chan, in_chan_type, out_chan, out_chan_type) -> str:
    ret_string = ""

    # add memory channel
    ret_string+= "chan attacker_mem = [0] of " + ("{ " + str(in_chan_type)[1:-1] + " }") .replace("'","") + ";\n"
    ret_string+= "\n"

    ret_string+= "active proctype attacker_replay() {\n"

    # proctype variables
    item_arr = []
    item_count = 0
    for item in in_chan_type:
        item_arr.append("b_" + str(item_count))
        ret_string+= str(item) + " " + item_arr[item_count] + ";\n"
        item_count+=1

    ret_string+="MAIN:\n"
    ret_string+="  do\n"

    fs = (str([item for item in item_arr])[1:-1]).replace("'","")

    ret_string+="  :: " + str(in_chan) + " ? <" + fs + "> -> attacker_mem ! " + fs + ";\n"
    ret_string+="  :: attacker_mem ? " + fs + " -> " + str(out_chan) + " ! " + fs + "; "  + str(in_chan) + " ? " + fs + ";\n"
    ret_string+="  :: goto MAIN;\n"
    ret_string+="  :: goto BREAK;\n"
    ret_string+="  od\n"
    ret_string+="BREAK:\n"
    ret_string+="}"

    mret = model[:model.rindex("}")+1] + "\n\n" + ret_string + "\n" + model[model.rindex("}")+1:]

    return mret

def gen_replay_mem(model, in_chan, in_chan_type, out_chan, out_chan_type, mem:int, rt) -> str:
    ret_string = ""

    # add memory channel
    ret_string+= "chan attacker_mem = ["+str(mem)+"] of " + ("{ " + str(in_chan_type)[1:-1] + " }") .replace("'","") + ";\n"
    ret_string+= "\n"

    ret_string+= "active proctype attacker_replay() {\n"

    # proctype variables
    item_arr = []
    item_count = 0

    # formulate string of general message input variables
    for item in in_chan_type:
        item_arr.append("b_" + str(item_count))
        ret_string+= str(item) + " " + item_arr[item_count] + ";\n"
        item_count+=1

    # put the general input variables into a promela-formatted string
    fs = (str([item for item in item_arr])[1:-1]).replace("'","")

    ret_string+="MAIN:\n"
    ret_string+="  do\n"
    ret_string+="  :: atomic { "+str(in_chan)+" ?? <" + fs + "> -> attacker_mem ! " + fs +"; }\n"
    ret_string+="  :: atomic { attacker_mem ?? " + fs + " -> " + str(out_chan) + " ! " + fs + "; }\n"
    ret_string+="  :: atomic { attacker_mem ?? " + fs + "; }\n"

    # go through all reset triggers
    for trigger in rt:
        # create item string, replace empty characters with generalized type chars if required
        item = list(trigger)
        for i in range(len(item)):
            if item[i] == "_" : item[i] = item_arr[i]

        trigger_list = str(item).replace("[","").replace("]","").replace("'","").replace(" ","")

        ret_string+="  :: atomic { " + str(in_chan) + " ? <" + trigger_list + "> -> \n"
        ret_string+="    do\n"
        ret_string+="    :: attacker_mem ? "+ fs +" -> skip;\n"
        ret_string+="    :: empty(attacker_mem) ->\n"
        ret_string+="      attacker_mem ! "+ trigger_list +";\n"
        ret_string+="      goto MAIN;\n"
        ret_string+="    od; }\n"
    ret_string+="  :: goto MAIN;\n"
    ret_string+="  :: goto BREAK;\n"
    ret_string+="  od\n"
    ret_string+="BREAK:\n"
    ret_string+="}"

    mret = model[:model.rindex("}")+1] + "\n\n" + ret_string + "\n" + model[model.rindex("}")+1:]

    return mret

def main() -> None:
    args = sys.argv[1:]  
    if len(args) == 0 or args[0] in ["help", "--help", "-h", "-help"]:
        show_help()
        sys.exit()

    # default memory value
    mem = 0
    rt = []

    for arg in args:
        if arg.startswith("--model="):
            model_path = arg.split("=", 1)[1]
        elif arg.startswith("--attacker="):
            attacker = arg.split("=", 1)[1]
        elif arg.startswith("--inchan="):
            in_chan = arg.split("=", 1)[1]
        elif arg.startswith("--outchan="):
            out_chan = arg.split("=", 1)[1]
        elif arg.startswith("--output="):
            out_file = arg.split("=", 1)[1]
        elif arg.startswith("--mem="):
            mem = int(arg.split("=", 1)[1])
        elif arg.startswith("--reset-triggers="):
            rt = [tuple(match.split(",")) for match in re.findall(r'\(([^)]+)\)', arg.split("=", 1)[1])]

    if not model_path or not attacker or not in_chan or not out_chan or not out_file:
        print("error: all arguments are required. \n")
        show_help()
        sys.exit(1)

    ensure_compile(model_path)
    model = fileRead(model_path)

    # extract channels to be analyzed from model file
    channels = parse_channels(fileReadLines(model_path))
    assert mem >= 0, "memory value must be positive"
    assert all(len(rtb) == len(rt[0]) for rtb in rt), "not all reset triggers are the same length"
    if len(rt) > 0 : assert len(channels[in_chan]) == len(rt[0]), "length of reset triggers not right"
    assert in_chan in channels and out_chan in channels, "specified input and output channels not found"
    assert channels[in_chan] == channels[out_chan], "channel types must be equivalent"

    model_with_attacker = str;
    match attacker:
        case "replay":
            model_with_attacker = gen_replay(model, in_chan, channels[in_chan], out_chan, channels[out_chan])
        case "replay_mem":
            model_with_attacker = gen_replay_mem(model, in_chan, channels[in_chan], out_chan, channels[out_chan], mem, rt)
        case _:
            print("error: inputted an invalid attacker model. \n")
            sys.exit(1)

    # Write the modified model to the output file
    with open(out_file, 'w') as file:
        file.write(model_with_attacker)

if __name__== "__main__":
    main()