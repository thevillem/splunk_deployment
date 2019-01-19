#!/bin/sh

# This script provides an example of how to deploy the universal forwarder
# to many remote hosts via ssh and common Unix commands.
#
# Note that this script will only work unattended if you have SSH host keys
# setup & unlocked.
# To learn more about this subject, do a web search for "openssh key management".


# ----------- Adjust the variables below -----------

# This is the path to the tar file that you wish to push out.  You may
# wish to make this a symlink to a versioned tar file, so as to minimize
# updates to this script in the future.

SPLUNK_FILE="/var/tmp/splunk-7.2.3-06d57c595b80-Linux-x86_64.tgz"

# This is where the tar file will be stored on the remote host during
# installation.  The file will be removed after installation.  You normally will
# not need to set this variable, as $NEW_PARENT will be used by default.
#
SCRATCH_DIR="/var/tmp/"

# The location in which to unpack the new tar file on the destination
# host.  This can be the same parent dir as for your existing
# installation (if any).  This directory will be created at runtime, if it does
# not exist.

NEW_PARENT="/opt"

# A directory on the current host in which the output of each installation
# attempt will be logged.  This directory need not exist, but the user running
# the script must be able to create it.  The output will be stored as
# $LOG_DIR/<[user@]destination host>.  If installation on a host fails, a
# corresponding file will also be created, as
# $LOG_DIR/<[user@]destination host>.failed.

LOG_DIR="/var/tmp/indxr-install"

# For conversion from normal Splunk Enterprise installs to the universal forwarder:
# After installation, records of progress in indexing files (monitor)
# and filesystem change events (fschange) can be imported from an existing
# Splunk Enterprise (non-forwarder) installation.  Specify the path to that installation here.
# If there is no prior Splunk Enterprise instance, you may leave this variable empty ("").
#
# NOTE: THIS SCRIPT WILL STOP THE SPLUNK ENTERPRISE INSTANCE SPECIFIED HERE.
#
# OLD_SPLUNK="/opt/splunk"

# If you use a non-standard SSH port on the remote hosts, you must set this.
# SSH_PORT=1234

# You must remove this line, or the script will refuse to run.  This is to
# ensure that all of the above has been read and set. :)

UNCONFIGURED=0

# ----------- End of user adjustable settings -----------


# helpers.

faillog() {
  echo "$1" >&2
}

fail() {
  faillog"ERROR: $@"
  exit 1
}

# error checks.

test "$UNCONFIGURED" -eq 1 && \
  fail "This script has not been configured.  Please see the notes in the script."
test -z "$NEW_PARENT" && \
  fail "No installation destination provided!  Please set NEW_PARENT."
test -z "$SPLUNK_FILE" && \
  fail "No splunk package path provided!  Please populate SPLUNK_FILE."
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR" || fail "Cannot create log dir at \"$LOG_DIR\"!"
fi

# some setup.

if [ -z "$SCRATCH_DIR" ]; then
  SCRATCH_DIR="$NEW_PARENT"
fi

NEW_INSTANCE="$NEW_PARENT/splunk" # this would need to be edited for non-UF...

#
#
# create script to run remotely.
#
#

echo "Starting Splunk Indexer Install."

exec 5>&1 # save stdout.
exec 6>&2 # save stderr.

LOG="$LOG_DIR/install.log"
FAILLOG="$LOG_DIR/failed.log"

# redirect stdout/stderr to logfile.
exec 1> "$LOG"
exec 2> "$FAILLOG"

###   try untarring tar file.
{
  sudo tar -zxf "$SPLUNK_FILE" -C "$NEW_PARENT"
  sudo chown -R ec2-user:ec2-user /opt/splunk
} || {
  fail"could not untar $SPLUNK_FILE to $NEW_PARENT."
}

###   extract indexer config files
{
  tar -xzf /var/tmp/indxr-conf.tgz -C "$SCRATCH_DIR"
} || {
  fail"could not untar indexer configuration."
}

### Configure Initial Splunk User
{
  cp "$SCRATCH_DIR/indxr-conf/user-seed.conf" /opt/splunk/etc/system/local/
} || {
  fail"could not move user-seed.conf"
}

### Configure Splunk Web
{
  cp "$SCRATCH_DIR/indxr-conf/web.conf" /opt/splunk/etc/system/local/
} || {
  fail"could not move web.conf"
}


### Configure Splunk Inputs
{
  echo "[default]" > /opt/splunk/etc/system/local/inputs.conf
  echo "host=splunk-indxr" >> /opt/splunk/etc/system/local/inputs.conf
  } || {
  fail"could not write inputs.conf"
}


### Configure Splunk Launch
{
  cp "$SCRATCH_DIR/indxr-conf/splunk-launch.conf" /opt/splunk/etc/
} || {
  fail"could not move splunk-launch.conf"
}

### Configure Splunk Launch
{
  echo "[diskUsage]" >> /opt/splunk/etc/system/local/server.conf
  echo "minFreeSpace = 500" >> /opt/splunk/etc/system/local/server.conf
} || {
  fail"could not update server.conf"
}

###   start new instance.
{
  "$NEW_INSTANCE/bin/splunk" start --accept-license --answer-yes --no-prompt
} || {
  fail"could not start new splunk instance!"
}

###   remove downloaded file.
{
  rm -f "$SPLUNK_FILE"
} || {
  fail"could not delete downloaded file $SPLUNK_FILE!"
}

# restore stdout/stderr.
exec 1>&5
exec 2>&6

if [[ ! -f $FAILLOG ]]; then
    echo "SUCCEEDED"
else
    echo "-->   FAILED   <--"
fi

# Voila.
#
#
# end of script.
#
#