#!/usr/bin/env bash

# -------------------------------------------------------------------
#
# DIRECTORY DESCENDING WORD LADDER
#
# -------------------------------------------------------------------
#
# (c) 2012 Sean Stickle, sean@stickle.net
#
# This script takes two words, FROM and TO, and makes a connecting
# series of words which vary, at each step, by only one letter.
#
# We do this in the following way:
#
#   1. Create a directory named after the FROM word, and change
#      into that directory.
#   2. Grep the wordlist for all words that are Hamming distance
#      of 1 from the current directory's name.
#   3. Create subdirectories named after each of those words.
#   4. Check to see if there are any directory paths that terminate
#      with the TO word.
#   5. If not, repeat step 2 through 4 until a directory path
#      that terminates in the TO word is found.
#   6. Print out the path.
#   7. Terminate.
#
# If there are no matches, the script exits with return code of 1.
#
# WARNING: This script abuses the file system to accomplish a
# fairly mundane data processing task, and may cause depletion of
# your inodes.
#
# -------------------------------------------------------------------
#
# EXAMPLE RUNS (on a 2009 MacBook Pro, SATA hard drive):
#
#   dog -> dig      Results:  /dog/dig
#                   Time:     1 sec
#
#   dog -> dad      Results:  /dog/dag/dad
#                   Time:     11 secs
#
#   dog -> cat      Results:  /dog/cog/cag/cat
#                   Time:     6 mins, 3 secs
#
#   lead -> gold    Results:  /lead/load/goad/gold
#                   Time:     1 min, 19 secs
#
#   word -> test    Results:  /word/wort/tort/tost/test
#                   Time:     50 mins, 23 secs
#
# -------------------------------------------------------------------

# Set WORDLIST to the location of the Unix words file, or
# whatever similarly-formatted word file of your own.

WORDLIST=/usr/share/dict/words

# Where the script is running from
HOME=$(pwd)

# FROM is the source word for the ladder. TO is the target
# word for the ladder. They must be of the same length.
FROM=$1
TO=$2

# Check that we have both a FROM and a TO word
if [ -z $FROM ] || [ -z $TO ]; then
  echo "You need to enter both a FROM and a TO string."
  exit
fi

# Word ladders are for strings of the same length.
if [ ! ${#FROM} == ${#TO} ]; then
  echo "Length of FROM and TO strings must be the same."
  exit
fi

# Check to see if a directory is already in the ALL_DIRS array.
# If it is, that means we've already tried processing it, which
# means that we haven't created any deeper directories to work
# on. This means that there are no further links in possible
# ladders, and we've reached the end of our search without
# finding a complete ladder.
dir_already_processed () {
    local DIR=$1
    shift
    local ALL_DIRS=("$@")
    for X in "${ALL_DIRS[@]}"; do
      [[ $X == $DIR ]] && return 0
    done
    return 1
}

# In each directory, we keep a list of all the other words that
# have had directories created elsewhere on the same level or in
# a more root-ward path. Since some other branch is exploring
# the chain from those words, we don't want to create a duplicate
# branch, as it would be redundant. This list of words allows us
# to skip creating those redundant branches.
#
# We need to know the actual words that are being processed else-
# where, not the whole path, so we strip off everything but the
# basename.
make_usedwords () {
  find $HOME/$FROM -type d | xargs -n1 basename > usedwords
}

# Take a word, find all variations in the wordlist of Hamming
# distance 1, and create directories for all (except for those
# words that have directories already created at a level closer
# to the root.
make_subdirs () {
  DIRECTORY=$1

  # Replace a letter of the word with a period ("."), which
  # will be used as a regex match for "any character". Do this
  # for all the letters, and we have a set of regexes that will
  # match all Hamming distance 1 words in the wordlist.
  I=0
  REGEXES=""
  while [ $I -lt ${#DIRECTORY} ]; do
    CAR=${DIRECTORY:0:$I}
    CDR=${DIRECTORY:$I+1}
    REGEXES="$REGEXES"" "$CAR.$CDR
    let I=I+1
  done

  # Match the regexes against the wordlist.
  for REGEX in $REGEXES; do
    grep "^$REGEX$" $WORDLIST >> matches
  done

  # Create usedword files in this directory, so that we don't
  # create any subdirectories with words already being worked
  # on in some other directory branch.
  make_usedwords

  # Take all the matches, subtract the words that have been
  # used at a higher directory level, and create subdirectories
  # for each word.
  grep -v -f usedwords matches | xargs -n1 mkdir -p
}

# Check to see if one or more directories exists with the
# target word.
check_for_success () {
  if [ $(find $HOME/$FROM -type d -name $TO | wc -l) -eq 0 ]; then
    SUCCESS=1
  else
    SUCCESS=0
  fi
}

# Each time we run, we want to only process the deepest directories.
# Some branches may terminate earlier than others, if they exhaust
# possible variations. We only want to work on the currently active
# potential word ladders.
get_deepest_directories() {
  # Get the length of the longest paths. Since all word variations
  # are of equal length, path length is directly proportional to
  # directory depth.
  DIRLENGTH=$(find . -type d | awk '{if (length > x) {x = length}} END {print x}')
  # Get all the directories that have the same longest path length.
  find . -type d | awk -v dirlength=$DIRLENGTH '{if (length == dirlength) {print $0}}'
}

# Start the search. Create our root word, and basic setup.
mkdir -p $FROM
cd $FROM
make_usedwords
cd ..

# Initialize our success flag (initially set to false), and the
# array that will track all processed directories.
SUCCESS=1
ALL_DIRS=()

# Climb the ladder.
while [ $SUCCESS -ne 0 ]; do
  for DIR in $(get_deepest_directories); do
    # If we've already processed this directory, it means
    # we've made no deeper directories, which means we've
    # exhausted possible options, and we're done.
    if dir_already_processed "$DIR" "${ALL_DIRS[@]}"; then
      echo "No path from $FROM to $TO."
      exit 1
    # Otherwise, keep on processing.
    else
      cd $DIR
      make_subdirs $(basename $DIR)
      cd $HOME
      ALL_DIRS+=($DIR)
    fi
  done
  check_for_success
done

# Print out all matching paths, and exit with success.
find $HOME/$FROM -type d -name $TO | sed s#$HOME##
exit 0
