#!/bin/bash

# Find the root directory of the repository.
rootdir="$(cd -- "$(dirname -- "$0")/.." && pwd)"

# shellcheck source=../bashu
source "$rootdir/bashu"

declare -i fd

random_int() {
  local lo hi
  local n=${3:-1}
  case $# in
    0)
      lo=0
      hi=100
      ;;
    1)
      lo=0
      hi=$1
      ;;
    *)
      lo=$1
      hi=$2
      ;;
  esac
  shuf -i "${lo}-${hi}" -n "$n"
}

random_word() {
  local dict=/usr/share/dict/words
  local word="'"
  until [[ "$word" != *"'"* ]]; do
    word=$(shuf -n 1 "$dict")
  done
  echo "$word"
}

getlineno() {
  local filename=$1; shift
  local pattern="$*"'$'

  grep -ne "$pattern" "$filename" | head -1 | cut -d':' -f1
}

setup() {
  exec {fd}<> <(:)
}

teardown() {
  [[ ! -t $fd ]] && exec {fd}>&-
}

backup_var() {
  local v
  v="$(declare -p "$1" | sed -e "s/$1=/_$1=/" -e "s/declare /declare -g /")" \
    && eval "$v"
}

backup() {
  backup_var bashu_is_running
  backup_var bashu_current_test
  backup_var bashu_is_failed
  backup_var bashu_err_funcname
  backup_var bashu_err_source
  backup_var bashu_err_lineno
  backup_var bashu_all_testcases
  backup_var bashu_performed_testcases
  backup_var bashu_passed_testcases
  backup_var bashu_failed_testcases
  backup_var bashu_err_trace_stack
  backup_var bashu_err_trace_stack_aux
  backup_var bashu_err_status_stack
}

fuzz() {
  local r
  backup
  bashu_is_running=$(random_int 10)
  bashu_current_test="testcase_$(random_word)"
  bashu_is_failed=$(random_int 10)
  bashu_err_funcname=()
  bashu_err_source=()
  bashu_err_lineno=()
  bashu_all_testcases=()
  bashu_performed_testcases=()
  bashu_passed_testcases=()
  bashu_failed_testcases=()
  bashu_err_trace_stack=()
  bashu_err_trace_stack_aux=()
  bashu_err_status_stack=()
  r=$(random_int 1 4)
  for (( i=0; i<r; i++ )); do
    bashu_err_funcname+=("func_$(random_word)")
    bashu_err_source+=("source_$(random_word)")
    bashu_err_lineno+=("$(random_int 500)")
    bashu_all_testcases+=("testcase_$(random_word)")
    bashu_performed_testcases+=("testcase_$(random_word)")
    bashu_passed_testcases+=("testcase_$(random_word)")
    bashu_failed_testcases+=("testcase_$(random_word)")
    bashu_err_trace_stack+=("$(random_word)")
    bashu_err_trace_stack_aux+=("$(random_int 10)")
    bashu_err_status_stack+=("$(random_int 10)")
  done
  bashu_err_status=$(random_int 10)
}

testcase_formatter_result_default_when_success() {
  setup
  bashu_is_running=1
  bashu_current_test="${FUNCNAME[0]}"
  bashu_is_failed=0

  bashu_dump_result "$fd"
  fuzz
  read -r -u "$fd" v; eval "$v"
  _bashu_formatter_default "$fd" >/dev/null
  [ "$bashu_is_running" -eq 1 ]
  [ "$bashu_current_test" == "${FUNCNAME[0]}" ]
  [ "$bashu_is_failed" -eq 0 ]
  teardown
}

testcase_formatter_result_default_when_success_output() {
  local _output

  setup
  bashu_is_running=1
  bashu_current_test="${FUNCNAME[0]}"
  bashu_is_failed=0

  bashu_dump_result "$fd"
  read -r -u "$fd" v; eval "$v"
  _output="$(_bashu_formatter_default "$fd")"
  [ "$_output" == "." ]
  teardown
}

testcase_formatter_result_default_when_failure() {
  local r=$(( RANDOM % 10 + 1 ))
  local lineno
  lineno=$(getlineno "$0" "_bashu_errtrap \$r 0  # testcase_formatter_result_default_when_failure")

  setup
  _bashu_errtrap $r 0  # testcase_formatter_result_default_when_failure
  bashu_postprocess $r
  bashu_dump_result "$fd"

  fuzz
  read -r -u "$fd" v; eval "$v"
  _bashu_formatter_default "$fd" >/dev/null
  [ "$bashu_is_running" -eq 1 ]
  [ "$bashu_current_test" == "${FUNCNAME[0]}" ]
  [ "$bashu_is_failed" -eq 1 ]
  [ "${bashu_err_funcname[*]}" == "${FUNCNAME[0]}" ]
  [ "${bashu_err_source[*]}" == "$0" ]
  [ "${bashu_err_lineno[*]}" == "$lineno" ]
  [ "$bashu_err_status" -eq $r ]
  teardown
}

testcase_formatter_result_default_when_failure_output() {
  local _output
  local r=$(( RANDOM % 10 + 1 ))

  setup
  _bashu_errtrap $r 0  # testcase_formatter_result_default_when_failure_output
  bashu_postprocess $r
  bashu_dump_result "$fd"

  read -r -u "$fd" v; eval "$v"
  _output="$(_bashu_formatter_default "$fd")"
  [ "$_output" == "F" ]
  teardown
}

testcase_formatter_summary_default_when_success() {
  setup
  bashu_is_running=0
  bashu_all_testcases=("testcase_$(random_word)")
  bashu_performed_testcases=("${bashu_all_testcases[@]}")
  bashu_passed_testcases=("${bashu_all_testcases[@]}")
  bashu_failed_testcases=()
  bashu_err_trace_stack=()
  bashu_err_trace_stack_aux=()
  bashu_err_status_stack=()

  bashu_dump_summary "$fd"
  fuzz
  read -r -u "$fd" v; eval "$v"
  _bashu_formatter_default "$fd" >/dev/null
  [ "$bashu_is_running" -eq 0 ]
  [ "${bashu_all_testcases[*]}" == "${_bashu_all_testcases[*]}" ]
  [ "${bashu_performed_testcases[*]}" == "${_bashu_performed_testcases[*]}" ]
  [ "${bashu_passed_testcases[*]}" == "${_bashu_passed_testcases[*]}" ]
  [ "${bashu_failed_testcases[*]}" == "${_bashu_failed_testcases[*]}" ]
  [ "${bashu_err_trace_stack[*]}" == "${_bashu_err_trace_stack[*]}" ]
  [ "${bashu_err_trace_stack_aux[*]}" == "${_bashu_err_trace_stack_aux[*]}" ]
  [ "${bashu_err_status_stack[*]}" == "${_bashu_err_status_stack[*]}" ]
  teardown
}

testcase_formatter_summary_default_when_success_rand() {
  local r

  setup
  r=$(random_int 1 5)
  bashu_is_running=0
  bashu_all_testcases=()
  for ((i=0; i<r; i++)); do
    bashu_all_testcases+=("testcase_$(random_word)")
  done
  bashu_performed_testcases=("${bashu_all_testcases[@]}")
  bashu_passed_testcases=("${bashu_all_testcases[@]}")
  bashu_failed_testcases=()
  bashu_err_trace_stack=()
  bashu_err_trace_stack_aux=()
  bashu_err_status_stack=()

  bashu_dump_summary "$fd"
  fuzz
  read -r -u "$fd" v; eval "$v"
  _bashu_formatter_default "$fd" >/dev/null
  [ "$bashu_is_running" -eq 0 ]
  [ "${bashu_all_testcases[*]}" == "${_bashu_all_testcases[*]}" ]
  [ "${bashu_performed_testcases[*]}" == "${_bashu_performed_testcases[*]}" ]
  [ "${bashu_passed_testcases[*]}" == "${_bashu_passed_testcases[*]}" ]
  [ "${bashu_failed_testcases[*]}" == "${_bashu_failed_testcases[*]}" ]
  [ "${bashu_err_trace_stack[*]}" == "${_bashu_err_trace_stack[*]}" ]
  [ "${bashu_err_trace_stack_aux[*]}" == "${_bashu_err_trace_stack_aux[*]}" ]
  [ "${bashu_err_status_stack[*]}" == "${_bashu_err_status_stack[*]}" ]
  teardown
}

testcase_formatter_summary_default_when_success_output() {
  local _output
  local expected=$'\n'"1 passed"

  setup
  bashu_is_running=0
  bashu_all_testcases=("testcase_$(random_word)")
  bashu_performed_testcases=("${bashu_all_testcases[@]}")
  bashu_passed_testcases=("${bashu_all_testcases[@]}")
  bashu_failed_testcases=()
  bashu_err_trace_stack=()
  bashu_err_trace_stack_aux=()
  bashu_err_status_stack=()

  bashu_dump_summary "$fd"
  read -r -u "$fd" v; eval "$v"
  _output="$(_bashu_formatter_default "$fd")"
  [ "$_output" == "$expected" ]
  teardown
}

testcase_formatter_summary_default_when_success_output_rand() {
  local _output
  local expected
  local r

  setup
  r=$(random_int 1 5)
  bashu_is_running=0
  bashu_all_testcases=()
  for ((i=0; i<r; i++)); do
    bashu_all_testcases+=("testcase_$(random_word)")
  done
  bashu_performed_testcases=("${bashu_all_testcases[@]}")
  bashu_passed_testcases=("${bashu_all_testcases[@]}")
  bashu_failed_testcases=()
  bashu_err_trace_stack=()
  bashu_err_trace_stack_aux=()
  bashu_err_status_stack=()

  bashu_dump_summary "$fd"
  read -r -u "$fd" v; eval "$v"
  _output="$(_bashu_formatter_default "$fd")"
  expected=$'\n'"$r passed"
  [ "$_output" == "$expected" ]
  teardown
}

series_of_malicious_commands() {
  local hoge=1
  local fuga=2
  local str="hello world"

  [ "$hoge" -eq 13 ]
  [ $fuga -eq 33 ]
  [ "$str" == "HELLO WORLD" ]

  [ $((hoge + fuga)) -eq 124 ]  # comment
  [ -z "$hoge" ]  # comment # comment2

  false "this" "is" "a" \
        "long" "command"
  false "this" "is" "also" "a" \  # comment
        "very" "very" "long" \
        "command"

  [   $((hoge+fuga))   -eq   11  ]
  [   $(( hoge  +  fuga ))  -eq  13  ]
}

testcase_formatter_normalize_command() {
  local source="$0"
  local lineno
  local _output
  local expected

  # Case 1
  lineno=$(getlineno "$0" "\[ \"\$hoge\" -eq 13 \]")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ \"\$hoge\" -eq 13 ]"
  [ "$_output" == "$expected" ]

  # Case 2
  lineno=$(getlineno "$0" "\[ \$fuga -eq 33 \]")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ \$fuga -eq 33 ]"
  [ "$_output" == "$expected" ]

  # Case 3
  lineno=$(getlineno "$0" "\[ \"\$str\" == \"HELLO WORLD\" \]")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ \"\$str\" == \"HELLO WORLD\" ]"
  [ "$_output" == "$expected" ]
}

testcase_formatter_normalize_command_comment() {
  local source="$0"
  local lineno
  local _output
  local expected

  # Case 1
  lineno=$(getlineno "$0" "\[ \$((hoge + fuga)) -eq 124 \]  # comment")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ \$((hoge + fuga)) -eq 124 ]"
  [ "$_output" == "$expected" ]

  # Case 2
  lineno=$(getlineno "$0" "\[ -z \"\$hoge\" \]  # comment # comment2")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ -z \"\$hoge\" ]"
  [ "$_output" == "$expected" ]
}

testcase_formatter_normalize_command_backslash() {
  local source="$0"
  local lineno
  local _output
  local expected

  # Case 1
  lineno=$(getlineno "$0" "false \"this\" \"is\" \"a\" \\\\")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="false \"this\" \"is\" \"a\""
  [ "$_output" == "$expected" ]

  # Case 2
  lineno=$(getlineno "$0" "false \"this\" \"is\" \"also\" \"a\" \\\\  # comment")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="false \"this\" \"is\" \"also\" \"a\""
  [ "$_output" == "$expected" ]
}

testcase_formatter_normalize_command_spaces_between_args() {
  local source="$0"
  local lineno
  local _output
  local expected

  # Case 1
  lineno=$(getlineno "$0" "\[   \$((hoge+fuga))   -eq   11  \]")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ \$((hoge+fuga)) -eq 11 ]"
  [ "$_output" == "$expected" ]

  # Case 2
  lineno=$(getlineno "$0" "\[   \$(( hoge  +  fuga ))  -eq  13  \]")
  _output=$(_bashu_formatter_normalize_command "$source" "$lineno")
  expected="[ \$(( hoge + fuga )) -eq 13 ]"
  [ "$_output" == "$expected" ]
}

failed_function() {
  local hoge=1
  local fuga=2

  [ $((hoge + fuga)) -eq 4 ]
  return
}

testcase_formatter_redefine_failed_function() {
  local f c
  local fifo=fifo
  local _output
  local expected

  f="failed_function"
  c="[ \$((hoge + fuga)) -eq 4 ]"
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function ()
{
 local hoge=1;
 local fuga=2;
echo [ \$((hoge + fuga)) -eq 4 ] >${fifo};
 [ \$((hoge + fuga)) -eq 4 ];
 return;
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_string() {
  local str="hello world"

  [ "$str" == "Hello World" ]
  return
}

testcase_formatter_redefine_failed_function_string() {
  local f c
  local fifo=fifo
  local _output
  local expected

  f="failed_function_string"
  c="[ \"\$str\" == \"Hello World\" ]"
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_string ()
{
 local str="hello world";
echo [ "\"\$str\"" == "\"Hello World\"" ] >${fifo};
 [ "\$str" == "Hello World" ];
 return;
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_single() {
  [ $((1 + 2)) -eq 4 ]
}

testcase_formatter_redefine_failed_function_single_command() {
  local f c
  local fifo=fifo
  local _output
  local expected

  f="failed_function_single"
  c="[ \$((1 + 2)) -eq 4 ]"
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_single ()
{
echo [ \$((1 + 2)) -eq 4 ] >${fifo};
 [ \$((1 + 2)) -eq 4 ];
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_with_comments() {
  true
  false  # comment
}

testcase_formatter_redefine_failed_function_with_comments() {
  local f c
  local fifo=fifo
  local _output
  local expected

  f="failed_function_with_comments"
  c="false"
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_with_comments ()
{
 true;
echo false >${fifo};
 false;
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_multi_same_commands() {
  true
  false "hoge"
  true
  false "fuga"
  true
  false
  true
}

testcase_formatter_redefine_failed_function_multi_same_commands() {
  local f c
  local fifo=fifo
  local _output
  local expected

  f="failed_function_multi_same_commands"
  c="false"
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_multi_same_commands ()
{
 true;
echo false "\"hoge\"" >${fifo};
 false "hoge";
 true;
echo false "\"fuga\"" >${fifo};
 false "fuga";
 true;
echo false >${fifo};
 false;
 true;
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_spaces_between_args() {
  local hoge=1
  local fuga=2

  [   $((hoge+fuga))   -eq   11  ]
}

testcase_formatter_redefine_failed_function_spaces_between_args() {
  local f c
  local fifo=fifo
  local _output
  local expected

  f="failed_function_spaces_between_args"
  c="[ \$((hoge+fuga)) -eq 11 ]"
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_spaces_between_args ()
{
 local hoge=1;
 local fuga=2;
echo [ \$((hoge+fuga)) -eq 11 ] >${fifo};
 [ \$((hoge+fuga)) -eq 11 ];
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_spaces_between_args2() {
  local hoge=1
  local fuga=2

  [   $((  hoge  +  fuga  ))   -eq   13   ]
}

testcase_formatter_redefine_failed_function_spaces_between_args2() {
  local f c
  local fifo=fifo
  local _output
  local expected
  local lineno

  lineno=$(getlineno "$0" "\[   \$((  hoge  +  fuga  ))   -eq   13   \]")
  f="failed_function_spaces_between_args2"
  c=$(_bashu_formatter_normalize_command "$0" "$lineno")
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_spaces_between_args2 ()
{
 local hoge=1;
 local fuga=2;
echo [ \$(( hoge + fuga )) -eq 13 ] >${fifo};
 [ \$(( hoge + fuga )) -eq 13 ];
}
EOF
  )
  [ "$_output" == "$expected" ]
}

failed_function_same_commands() {
  local _output
  local expected

  _output="hello"
  expected="hello"
  [ "$_output" == "$expected" ]

  _output="world"
  expected="world"
  [ "$_output" == "$expected" ]

  _output="hello"
  expected="world"
  [ "$_output" == "$expected" ]  # failed_function_same_commands

  _output="!"
  expected="!"
  [ "$_output" == "$expected" ]
}

testcase_formatter_redefine_failed_function_same_commands() {
  local f c
  local fifo=fifo
  local _output
  local expected
  local lineno

  lineno=$(getlineno "$0" "\[ \"\$_output\" == \"\$expected\" \]  # failed_function_same_commands")
  f="failed_function_same_commands"
  c=$(_bashu_formatter_normalize_command "$0" "$lineno")
  _output=$(_bashu_formatter_redefine_failed_function "$f" "$c" "$fifo")
  expected=$(cat <<EOF
failed_function_same_commands ()
{
 local _output;
 local expected;
 _output="hello";
 expected="hello";
echo [ "\"\$_output\"" == "\"\$expected\"" ] >${fifo};
 [ "\$_output" == "\$expected" ];
 _output="world";
 expected="world";
echo [ "\"\$_output\"" == "\"\$expected\"" ] >${fifo};
 [ "\$_output" == "\$expected" ];
 _output="hello";
 expected="world";
echo [ "\"\$_output\"" == "\"\$expected\"" ] >${fifo};
 [ "\$_output" == "\$expected" ];
 _output="!";
 expected="!";
echo [ "\"\$_output\"" == "\"\$expected\"" ] >${fifo};
 [ "\$_output" == "\$expected" ];
}
EOF
  )
  [ "$_output" == "$expected" ]
}



dummy_testcase() {
  false  # dummy_testcase
}

testcase_formatter_summary_default_evaluate() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "false  # dummy_testcase")
  err_info=("dummy_testcase" "dummy_testcase" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="false"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_compare_numerals() {
  local hoge=1
  local fuga=2

  [ $(( hoge + fuga )) -eq 4 ]  # dummy_testcase_compare_numerals
}

testcase_formatter_summary_default_evaluate_compare_numerals() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[ \$(( hoge + fuga )) -eq 4 \]  # dummy_testcase_compare_numerals")
  err_info=("dummy_testcase_compare_numerals" "dummy_testcase_compare_numerals" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ 3 -eq 4 ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_compare_string() {
  local string="hello world"

  [ "$string" == "Hello World" ]  # dummy_testcase_compare_string
}

testcase_formatter_summary_default_evaluate_compare_string() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[ \"\$string\" == \"Hello World\" \]  # dummy_testcase_compare_string")
  err_info=("dummy_testcase_compare_string" "dummy_testcase_compare_string" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ \"hello world\" == \"Hello World\" ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_compare_zero_string() {
  local string="hello world"

  [ -z "$string" ]  # dummy_testcase_compare_zero_string
}

testcase_formatter_summary_default_evaluate_compare_zero_string() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[ -z \"\$string\" \]  # dummy_testcase_compare_zero_string")
  err_info=("dummy_testcase_compare_zero_string" "dummy_testcase_compare_zero_string" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ -z \"hello world\" ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_check_exit_status() {
  local arg1="hoge"
  local arg2="fuga"

  false "$arg1" "$arg2"  # dummy_testcase_check_exit_status
}

testcase_formatter_summary_default_evaluate_check_exit_status() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "false \"\$arg1\" \"\$arg2\"  # dummy_testcase_check_exit_status")
  err_info=("dummy_testcase_check_exit_status" "dummy_testcase_check_exit_status" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="false \"hoge\" \"fuga\""
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_same_commands() {
  local _output
  local expected

  _output="hello"
  expected="hello"
  [ "$_output" == "$expected" ]

  _output="world"
  expected="world"
  [ "$_output" == "$expected" ]

  _output="hello"
  expected="world"
  [ "$_output" == "$expected" ]  # dummy_testcase_same_commands

  _output="!"
  expected="!"
  [ "$_output" == "$expected" ]
}

testcase_formatter_summary_default_evaluate_same_commands() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[ \"\$_output\" == \"\$expected\" \]  # dummy_testcase_same_commands")
  err_info=("dummy_testcase_same_commands" "dummy_testcase_same_commands" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ \"hello\" == \"world\" ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_spaces_between_args() {
  local hoge=1
  local fuga=2

  [   $((hoge+fuga))   -eq   11  ]  # dummy_testcase_spaces_between_args
}

testcase_formatter_summary_default_evaluate_spaces_between_args() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[   \$((hoge+fuga))   -eq   11  \]  # dummy_testcase_spaces_between_args")
  err_info=("dummy_testcase_spaces_between_args" "dummy_testcase_spaces_between_args" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ 3 -eq 11 ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_spaces_between_args2() {
  local hoge=1
  local fuga=2

  [   $((  hoge  +  fuga  ))   -eq   13   ]  # dummy_testcase_spaces_between_args2
}

testcase_formatter_summary_default_evaluate_spaces_between_args2() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[   \$((  hoge  +  fuga  ))   -eq   13   \]  # dummy_testcase_spaces_between_args2")
  err_info=("dummy_testcase_spaces_between_args2" "dummy_testcase_spaces_between_args2" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ 3 -eq 13 ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

dummy_testcase_command_substitution() {
  [ "$(printf "%s " "arg1" "arg2")" == "arg1 arg2" ]  # dummy_testcase_command_substitution
}

testcase_formatter_summary_default_evaluate_command_substitution() {
  local _output
  local expect
  local err_info=()
  local fifo=/tmp/bashufifo-$BASHPID
  local lineno

  rm -f "$fifo"
  mkfifo "$fifo"
  lineno=$(getlineno "$0" "\[ \"\$(printf \"%s \" \"arg1\" \"arg2\")\" == \"arg1 arg2\" \]  # dummy_testcase_command_substitution")
  err_info=("dummy_testcase_command_substitution" "dummy_testcase_command_substitution" "$0" "$lineno")
  _output=$(_bashu_formatter_summary_default_evaluate "${err_info[@]}" "$fifo")
  expect="[ arg1 arg2  == arg1 arg2 ]"
  [ "$_output" == "$expect" ]
  rm -f "$fifo"
}

DISABLED_testcase_formatter_summary_default_when_failure() {
  local r
  local _output
  local expected

  setup
  _bashu_initialize
  r=$(random_int 1 10)

  _bashu_errtrap "$r" 0
  bashu_postprocess "$r"

  bashu_is_running=0
  bashu_dump_summary "$fd"
  read -r -u "$fd" v; eval "$v"
  _output="$(_bashu_formatter_default "$fd")"

  local prefix="testcase_"
  expected=$(cat <<EOF

== FAILURES ==
__ ${bashu_current_test} __

    ${prefix}formatter_summary_default_when_failure() {

      local r
      local _output
      local expected

      setup
      _bashu_initialize
      r=\$(random_int 1 10)

>     _bashu_errtrap \"\$r\" 0
E     _bashu_errtrap $r 0
EOF
  )
  echo
  echo "-- output --"
  echo "$_output"
  echo "-- expected --"
  echo "$expected"
  [ "$_output" == "$expected" ]
  teardown
}

_testcase_formatter_summary_default_when_failure_nested2() {
  local r=$1

  true "this command should be shown"
  _bashu_errtrap "$r" 0  # _testcase_formatter_summary_default_when_failure_nested2
  this command should not be executed
}

_testcase_formatter_summary_default_when_failure_nested() {
  local r=$1

  true "this command should be shown"
  _testcase_formatter_summary_default_when_failure_nested2 "$r"
  this command should not be executed
}

DISABLED_testcase_formatter_summary_default_when_failure_nested() {
  local r
  local _output
  local expected

  setup
  _bashu_initialize
  r=$(random_int 1 10)

  _testcase_formatter_summary_default_when_failure_nested "$r"
  bashu_postprocess "$r"

  bashu_is_running=0
  bashu_dump_summary "$fd"
  read -r -u "$fd" v; eval "$v"
  _output="$(_bashu_formatter_default "$fd")"

  local prefix="testcase_"
  expected=$(cat <<EOF

== FAILURES ==
__ ${bashu_current_test} __

    ${prefix}formatter_summary_default_when_failure() {

      local r
      local _output
      local expected

      setup
      _bashu_initialize
      r=\$(random_int 1 10)

>     _testcase_formatter_summary_default_when_failure_nested \"\$r\"
E     _bashu_errtrap $r 0

$0:$ln: Exit with $r
1 failed
EOF
  )
  echo
  echo "-- output --"
  echo "$_output"
  echo "-- expected --"
  echo "$expected"
  [ "$_output" == "$expected" ]
  teardown
}

bashu_main "$@"