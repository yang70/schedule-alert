#!/usr/bin/env bash
set -euo pipefail
key_file=${LIGHTSAIL_KEY_FILE:-}
if [[ -z "$key_file" ]]; then
  shopt -s nullglob
  keys=("$HOME"/.ssh/lightsail/LightsailDefaultKey-*.pem)
  [[ ${#keys[@]} == 1 ]] || { echo 'Set LIGHTSAIL_KEY_FILE to the intended SSH key.' >&2; exit 1; }
  key_file=${keys[0]}
fi
ssh -i "$key_file" "${DEPLOY_USER:-ubuntu}@${DEPLOY_HOST:-44.226.63.157}" 'cd ~/schedule && ./bin/deploy.sh'
