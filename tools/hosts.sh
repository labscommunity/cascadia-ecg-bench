# ssh target resolution for the bench fleet (source me)
SSHOPTS=(-o ConnectTimeout=15 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=20)
target() {
  case "$1" in
    alpha)   echo "-i $HOME/.ssh/id_ed25519 tatef@100.115.173.79" ;;
    beta)    echo "-i $HOME/.ssh/id_ed25519 tatef@100.123.247.94" ;;
    charlie) echo "-i $HOME/.ssh/id_ed25519 tatef@100.72.211.81" ;;
    delta)   echo "-i $HOME/.ssh/id_ed25519 tatef@100.117.239.78" ;;
    tate07)  echo "-o UserKnownHostsFile=/dev/null cascadia-tate-07-ts" ;;
    tate08)  echo "-o UserKnownHostsFile=/dev/null cascadia-tate-08" ;;
    *) echo "unknown host $1" >&2; return 1 ;;
  esac
}
