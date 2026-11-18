# Runs a function and measures the time the function takes to execute.
# The time is saved in the variable provided as first argument.
#
# Arguments:
#   $1 - Variable to store the duration in
timer() {
  local output_var="$1"
  local start_time
  local end_time
  local duration_ms

  shift

  start_time=$(date +%s%N)

  "$@"

  end_time=$(date +%s%N)
  duration_ms=$(( (end_time - start_time) / 1000000 ))

  printf -v "$output_var" '%s' "$duration_ms"
}
