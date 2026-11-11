#!/bin/zsh
set -eu
project_dir="${0:A:h}"
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$project_dir" "$@"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$project_dir" "$@"
else
  print 'Godot 4 не найден. Откройте project.godot через установленный редактор Godot.'
  exit 1
fi
