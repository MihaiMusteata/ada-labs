#!/bin/bash
set -e

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <difficulty> [processes]"
    exit 1
fi

difficulty=$1
requested_processes=${2:-}
process_counts=(1 2 4 8 16 32)

if ! [[ "${difficulty}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Difficulty must be a positive integer."
    exit 1
fi

if [ -n "${requested_processes}" ]; then
    case "${requested_processes}" in
        1|2|4|8|16|32)
            process_counts=("${requested_processes}")
            ;;
        *)
            echo "Processes must be one of: 1, 2, 4, 8, 16, 32."
            exit 1
            ;;
    esac
fi

for processes in "${process_counts[@]}"
do
    echo "============================================================"
    echo "MPI processes: ${processes}; difficulty: ${difficulty}"
    echo "============================================================"
    mpirun --hostfile available_hosts_file -np "${processes}" lab1_openmpi "${difficulty}"
    echo
done
