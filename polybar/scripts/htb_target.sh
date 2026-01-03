#!/bin/bash

target="$(cat /tmp/target 2>/dev/null | xargs)"  # xargs elimina espacios y saltos
name="$(cat /tmp/name 2>/dev/null | xargs)"    # xargs elimina espacios y saltos

# Si los archivos contienen "Null" (texto) o están vacíos, mostrar "Waiting..."
if [[ "$target" == "Null" || "$name" == "Null" || -z "$target" || -z "$name" ]]; then
  echo "%{F#e51d0b}ﲅ %{u-}%{F#ffffff} Waiting..."
elif [[ -n "$target" && -n "$name" ]]; then
  echo "%{F#e51d0b} %{F#ffffff}${target}  %{F#e51d0b}  %{F#ffffff}${name}"
else
  echo "%{F#e51d0b}ﲅ %{u-}%{F#ffffff} Waiting..."
fi
