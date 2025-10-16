#!/bin/bash

# Nom de fichier basé sur date
NAME="test_auto_$(date +%Y-%m-%d_%H-%M-%S)"

generate_inputs() {
  for i in {1..21}; do
    echo $((RANDOM % 10 + 1))
  done
  echo $((RANDOM % 10 + 1))
  echo "Note automatique - test bash"
}

generate_inputs | python3 daily_check.py --name "$NAME"

