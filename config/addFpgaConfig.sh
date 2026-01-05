#!/bin/sh

AgentIP=$1
NegotiationPort=$2
NodePort=$3
DataPort=$4
ContactPort=$5
NodeID=$6

source ./safeExec.sh

if [[ ${AgentIP} == '' ]] || [[ ${NegotiationPort} == '' ]] || [[ ${NodePort} == '' ]] || [[ ${DataPort} == '' ]] || [[ ${ContactPort} == '' ]] || [[ ${NodeID} == '' ]] ; then
	echo "Parameters are invalid, format: <AgentIP>,<NegotiationPort>,<NodePort>,<DataPort>,<ContactPort>,<NodeID>"
	echo "please input like this addFpgaConfig.sh 192.168.1.66 16001 16002 16003 500 2"
	exit
fi

echo "add fpga config agent ip:${AgentIP}, negotiation port:${NegotiationPort}, node port:${NodePort}, data Port:${DataPort},contact port:${DataPort},Node ID:${NodeID}"

# 提示用户输入数据库密码
echo -n "Please enter database password: "
read -s DB_PASSWORD
echo
if [ -z "$DB_PASSWORD" ]; then
    echo "Error: Password cannot be empty"
    exit 1
fi

# 导出密码变量，供 safeExec.sh 中的函数使用
export DB_PASSWORD

service sie stop

safeExecsql $NodeID "delete from t_scm_agent_info where NODE_ID = '${NodeID}';"
safeExecsql $NodeID "insert into t_scm_agent_info(AGENT_IP, NEGOTIATTE_PORT, NODE_COMMUNICATION_PORT, DATA_PORT, CONTACT_PORT, NODE_ID,CONTAINER_ID) VALUES('${AgentIP}',${NegotiationPort},${NodePort},${DataPort},${ContactPort},${NodeID},1);"

echo "restart sie"
service sie restart

echo "done!"
