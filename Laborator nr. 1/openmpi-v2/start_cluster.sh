#!/bin/bash
difficulty=${1:-}
processes=${2:-}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <difficulty> [processes]"
    echo "Examples:"
    echo "  $0 6"
    echo "  $0 6 16"
    exit 1
fi

if ! [[ "${difficulty}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Difficulty must be a positive integer."
    exit 1
fi

if [ -n "${processes}" ]; then
    case "${processes}" in
        1|2|4|8|16|32)
            ;;
        *)
            echo "Processes must be one of: 1, 2, 4, 8, 16, 32."
            exit 1
            ;;
    esac
fi

docker compose up -d --remove-orphans --build --scale lab1-openmpi=2

docker compose exec lab1-openmpi /bin/bash -c "/home/student/lab1/openmpi-v2/compile.sh"
docker compose exec lab1-openmpi /bin/bash -c "rm -f /home/student/.ssh/known_hosts"
docker compose exec lab1-openmpi /bin/bash -c "rm -f /home/student/lab1/openmpi-v2/available_hosts_file"

for host_name in $(docker network inspect openmpi-v2_main | grep '"Name": "openmpi-v2-lab1-openmpi' | sed -E 's/.*"Name": "([^"]+)".*/\1/')
do
    docker compose exec lab1-openmpi /bin/bash -c "ssh-keyscan -t rsa ${host_name} >> /home/student/.ssh/known_hosts"
    docker compose exec lab1-openmpi /bin/bash -c "echo \"${host_name} slots=16\" >> /home/student/lab1/openmpi-v2/available_hosts_file"
done

command="/home/student/lab1/openmpi-v2/run_computations_on_cluster.sh ${difficulty}"

if [ -n "${processes}" ]; then
    command="${command} ${processes}"
fi

docker compose exec lab1-openmpi /bin/bash -c "${command}"
docker compose exec lab1-openmpi /bin/bash
