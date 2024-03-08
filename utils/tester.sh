#!/bin/sh

usage() {
  echo "Usage: ./tester.sh [file.pml] [ltl-folder] [output-folder]"
  echo "Automatically test a Promela file against a set of properties"
  echo ""
  echo "Options:"
  echo "  -h, --help         Show this help message and exit!" 
}

# Check if '-h' or '--help' flags are passed
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$2" = "-h" ] || [ "$2" = "--help" ]; then
    usage
    exit 0
fi

spinfile=$1
ltl_folder=$2
output_folder=$3

# ensure spin compile
spin $spinfile > /tmp/spintmp

if grep -q "syntax error" /tmp/spintmp; then
  echo "there seems to be a syntax error in the model"
  exit 0
fi

if ! grep -q "processes created" /tmp/spintmp; then
  echo "the spin model creates no processes ... check to see if it compiles"
  exit 0
fi

rm /tmp/spintmp
mkdir $output_folder
touch "$output_folder/results.md"

for entry in `ls $ltl_folder`; do
  if [[ $entry == *.pml ]]
  then
    cp $spinfile "/tmp/spintemp.pml"
    echo "\n" >> "/tmp/spintemp.pml"
    cat "$ltl_folder"/"$entry" >> "/tmp/spintemp.pml"
    filename="${entry%.pml}"
    spin -run -a -DNOREDUCE -m600000 "/tmp/spintemp.pml" 2>&1 | tee "$output_folder/$filename-out"

    # if there is a trail, we grab it and send it to output folder
    if grep -q "trail" "$output_folder/$filename-out" && grep -q "pan: wrote" "$output_folder/$filename-out"; then
      cp spintemp.pml.trail "$output_folder/$filename-trail"
    fi

    # check for violation/acceptance cycle in results
    if grep -q "assertion violated" "$output_folder/$filename-out"; then
      echo "$filename - property violation" >> "$output_folder/results.md"
    elif grep -q "acceptance cycle" "$output_folder/$filename-out"; then
      echo "$filename - acceptance cycle" >> "$output_folder/results.md"
    else 
      echo "$filename - no violations" >> "$output_folder/results.md"
    fi
    # cleanup
    rm "pan" 2> /dev/null
    rm "/tmp/spintemp.pml" 2> /dev/null
    rm "spintemp.pml.trail" 2> /dev/null
  fi
done
