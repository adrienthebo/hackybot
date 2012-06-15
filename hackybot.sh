
initialize_bot() {


  # Create a root directory for us to play with.
  export app_root=$(mktemp -d -t hackybot)

  export app_input="${app_root}/input"
  export app_pid="${app_root}/pidfile"
  export app_log="${app_root}/logfile"

  _debug "app_root is $app_root"
  _debug "read FIFO is $app_input"

  mkfifo $app_input
}

#####
#
# Initialize and background the bot connection, establish signal handlers, and
# register this connection with the IRC server.
#
start_bot() {

  _debug "Starting bot worker"

  _register_exit_handler

  (
    tail -f $app_input | openssl s_client -quiet -connect "${HACKYSERVER}:${HACKYPORT}" 2>/dev/null| while read line; do

      # ew.
      _log_pids

      _debug "<- $line"
      echo $line >> $app_log

      case $line in
      *PING*)
        irc "PONG"
        ;;
      *)
        ;;
      esac
    done
  ) &

  sleep 2

  _register_with_server
}

#####
#
# Send a message to the server, that's been properly formatted. Adds in
# optional logging hooks.
#
irc() {
  sleep 1
  _debug "-> '$@'"
  echo -ne "$@\r\n" > $app_input
}

#####
#
# Send a private message to the server.
privmsg() {
  irc privmsg $1 ":$2"
}

wait_for_welcome() {
  _debug_nonewline "Waiting for welcome"
  while ! grep "001 $HACKYBOT" $app_log > /dev/null; do
    _debug_nonewline '.'
    sleep 1
  done
}

################################################################################
# Private methods. If you call these then I will laugh at you when things go
# horribly awry.

_register_with_server() {
  irc "USER $HACKYBOT 0 * :TURN THE HACKINESS UP TO 11"
  irc "NICK $HACKYBOT"
  irc "MODE $HACKYBOT +b"
}

_debug() {
  _debug_nonewline "$@\n"
}

_debug_nonewline() {
  if [ -n "$DEBUG" ]; then echo -ne "$@"; fi
}

_register_exit_handler() {
  trap _cleanup_on_exit SIGTERM SIGINT SIGQUIT EXIT
}

_cleanup_on_exit() {
  echo -e "killing these:\n$(cat $app_pid)"
  cat $app_pid | xargs kill
  exit
}

_log_pids() {
  ps -eo pid,ppid | awk "(\$2 ~ /$$/) { printf(\"%s\\n\", \$1); }"
  ps -eo pid,ppid | awk "(\$2 ~ /$$/) { printf(\"%s\\n\", \$1); }" > $app_pid
  echo $$
  echo $$ >> $app_pid
}
