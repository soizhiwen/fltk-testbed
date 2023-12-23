LOG_DIR="/home/engineer/fltk-testbed/logging"
EXP_NAME="exp_23"

cd $LOG_DIR/$EXP_NAME

# Get create timestamp from fl-server.log
awk '/has been created/ {sub("test/trainjob-", "", $6); print $1, $2, $6}' \
    fl-server.log > create.log

# Get start timestamp from each pod log
find $LOG_DIR/$EXP_NAME -type f -name "trainjob-*.log" \
    -exec grep "Preparing learner model with distributed=True" {} \; | \
    awk '{gsub("Client-0-", "", $3); print $1, $2, $3}' | \
    sort > start.log

# Get stop timestamp from each pod log
find $LOG_DIR/$EXP_NAME -type f -name "trainjob-*.log" \
    -exec awk '/Stopping client.../ {sub(".*/trainjob-", "", FILENAME); sub("-master-0.log", "", FILENAME); print $1, $2, FILENAME}' {} \; | \
    sort > stop.log


