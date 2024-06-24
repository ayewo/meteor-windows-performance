#!/bin/bash

# High precision execution time calculation using "date" courtesy of: https://stackoverflow.com/a/32272632

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

set -x

#timings_folder="$HOME/meteor-timings"
timings_folder=${timings_folder}

cd $timings_folder


# Step 1.0.
set +x
nvm use 14.17.3
set -x
command="npm install -g meteor"
time_start=$(date +%s.%N)
time -p $command
time_end=$(date +%s.%N)
duration=$(echo "$time_end - $time_start" | bc)
echo "1, '$command', $time_start, $time_end, $duration" > $timings_folder/timings.csv


# Step 2.0.
set +x
export PATH="$HOME/.meteor:$PATH"
set -x
command="meteor create testapp --blaze"
time_start=$(date +%s.%N)
time -p $command
time_end=$(date +%s.%N)
duration=$(echo "$time_end - $time_start" | bc)
echo "2, '$command', $time_start, $time_end, $duration" >> $timings_folder/timings.csv


# Step 3.0.
cd testapp
command="meteor"
time_start=$(date +%s.%N)

$command > meteor.log 2>&1 &
# Store the PID of the meteor process
METEOR_PID=$!
# Wait for "App running at: http://localhost:3000/" string to appear in the server output
while ! grep -q "App running at: http://localhost:3000/" meteor.log; do
    sleep 1
done
echo "Meteor server is running"

time_end=$(date +%s.%N)
duration=$(echo "$time_end - $time_start" | bc)
echo "3, '$command', $time_start, $time_end, $duration" >> $timings_folder/timings.csv
kill $METEOR_PID


# Step 4.0.
command="meteor add ostrio:flow-router-extra"
time_start=$(date +%s.%N)
time -p $command
time_end=$(date +%s.%N)
duration=$(echo "$time_end - $time_start" | bc)
echo "4, '$command', $time_start, $time_end, $duration" >> $timings_folder/timings.csv


# Step 5.0.
set +x
nvm use 20.11.1
set -x
command="meteor update --release 3.0-alpha.19"
time_start=$(date +%s.%N)
time -p $command
time_end=$(date +%s.%N)
duration=$(echo "$time_end - $time_start" | bc)
echo "5, '$command', $time_start, $time_end, $duration" >> $timings_folder/timings.csv
cd -

<<'###COMMENT-BLOCK'
###COMMENT-BLOCK