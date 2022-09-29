#!/usr/bin/env bash

if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]
then
    echo "使用node节点的tcpdump命令对特定pod抓包，脚本在能使用kuberlet的主机"
    echo "./script/network/tcpdump-topod-node-script.sh namespace podName"
    exit 0
fi
set -euxo pipefail
NAMESPACE=${1}; shift
POD=${1}; shift

eval "$(kubectl get pod \
    --namespace "${NAMESPACE}" \
    "${POD}" \
    --output=jsonpath="{.status.containerStatuses[0].containerID}{\"\\000\"}{.status.hostIP}" \
    | xargs -0 bash -c 'printf "${@}"' -- 'CONTAINER_ID=%q\nHOST_IP=%q')"

if [[ ${CONTAINER_ID} == 'docker://'* ]]; then
    CONTAINER_ID=${CONTAINER_ID#'docker://'}
elif [[ ${CONTAINER_ID} == 'containerd://'* ]]; then
    CONTAINER_ID=${CONTAINER_ID#'containerd://'}
fi

if [[ -z $(ip address | sed -n "s/inet ${HOST_IP}\//found/p") ]]; then
    SHELL_COMMAND='eval ssh "${HOST_IP}" bash -euxo pipefail - '
else
    SHELL_COMMAND='source /dev/stdin'
fi
echo ${HOST_IP}
${SHELL_COMMAND} <<EOF
cd /tmp
echo \${PWD}
PATH=\${PATH}:/usr/local/bin
PID=\$(docker inspect --format '{{.State.Pid}}' ${CONTAINER_ID})

IF_NO=\$(docker exec ${CONTAINER_ID} /bin/bash -c 'cat /sys/class/net/eth0/iflink')

IF=\$(grep -Ril \$IF_NO /sys/class/net/*/ifindex | awk  -F '/' '{print \$5}')

tcpdump -i \${IF}  -w /tmp/result.cap
ll /tmp/result.cap
EOF
