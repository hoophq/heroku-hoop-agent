#!/usr/bin/env bash
set -e

[[ "$CONNECTION_DEBUG" == "1" ]] && set -x

Help()
{
   cat <<EOF
DESCRIPTION
       Create an SSH session to a dyno

OPTIONS
       --app=(app)
          (required) app to run command against

       --dyno=(dyno)
          specify the dyno to connect to

       --status
          lists the status of the SSH server in the dyno

       --pipe (command)
          The command which will be used against the input. This mode requires that
          a base64 command is available in the dyno.

       --interactive
          Use this flag to run your command in interactive mode.

       --help
          Show this help
EOF
}

# read arguments
PARSED_ARGUMENTS=$(getopt \
  --options "" \
  --long app:,dyno:,status,pipe:,interactive,help \
  --name "$(basename "$0")" \
  -- "$@"
)
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"

APP_NAME=
DYNO=
PIPE_EXEC=
SSH_STATUS=0
SHELL_INTERACTIVE=0

while :
do
  case "$1" in
    --app)          APP_NAME="$2"; shift 2;;
    --dyno)         DYNO="$2"; shift 2;;
    --pipe)         PIPE_EXEC="$2"; shift 2;;
    --status)       SSH_STATUS=1; shift;;
    --interactive)  SHELL_INTERACTIVE=1; shift;;
    --help)         Help; exit 0 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1"; break;;
  esac
done

export HOME=${HOME:-/app}
: "${APP_NAME:? Required argument --app not set}"

# it will restart the app in the first time
# if dyno it's not provided it will restart all dynos
heroku features:info runtime-heroku-exec --app $APP_NAME --json | grep 'enabled": false' && \
	heroku features:enable runtime-heroku-exec --app $APP_NAME && \
  echo "Restarting app/dyno=$APP_NAME/${DYNO:-*}" >&2 && \
	heroku ps:restart $DYNO --app $APP_NAME && \
  echo -n "Waiting dyno's to restart ..." >&2 && \
  sleep 3 && echo " done!" >&2

if [ -n "$DYNO" ]; then
  DYNO="--dyno $DYNO"
fi

if [ "$SSH_STATUS" == "1" ]; then
  heroku ps:exec --app $APP_NAME $DYNO --status
  exit $?
fi

if [ "$SHELL_INTERACTIVE" == "1" ]; then
  PIPE_EXEC=${PIPE_EXEC:-bash}
  heroku ps:exec --app $APP_NAME $DYNO -- "$PIPE_EXEC"
  exit $?
fi

STDIN_INPUT="$(</dev/stdin)"
if [ -n "$PIPE_EXEC" ]; then
  STDIN_INPUT="$(base64 <<< $STDIN_INPUT)"
  heroku ps:exec --app $APP_NAME $DYNO -- \
	  /bin/bash -e -l -c "echo -n $STDIN_INPUT |base64 -d | $PIPE_EXEC"
  exit $?
fi

heroku ps:exec --app $APP_NAME $DYNO -- "$STDIN_INPUT"
