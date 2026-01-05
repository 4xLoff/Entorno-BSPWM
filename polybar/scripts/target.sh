target=$(cat /tmp/name)

if [ "$target" = "Null" ]; then
  echo "Waiting..."
else  
  echo "%{F#9658A4}   %{F#93A1A1}$(cat /tmp/name)  %{F#9658A4}  %{F#93A1A1}$(cat /tmp/target)"
fi

