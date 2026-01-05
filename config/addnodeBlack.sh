#!/bin/sh

LocalIP=$1
NatIP=$2
NodeID=$3
MainIP=$4
PhoneNode=1
DomainCode=$5
source ./safeExec.sh

if [[ ${LocalIP} == '' ]] || [[ ${NatIP} == '' ]] || [[ ${NodeID} == '' ]] || [[ ${MainIP} == '' ]] || [[ ${DomainCode} == '' ]] ; then
	echo "Parameters are LocalIP NatIP NodeID MainIP DomainCode, please input like this addnode.sh 192.168.1.66 192.168.1.66 2 192.168.2.26 a4bf014bb884"
	exit
fi

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

safeRmNodeDb $NodeID
safeAddNodeDb $NodeID

echo "add node local ip:${LocalIP}, nat ip:${NatIP}, node id:${NodeID}, 5G node:${PhoneNode},domain code:${DomainCode}"

safeExecsql $NodeID "update t_domain_info set DOMAIN_CODE= '${DomainCode}',PARENT_DOMAIN_CODE='${DomainCode}' ,DOMAIN_IP='${NatIP}', DOMAIN_NAT_IP='${NatIP}' where IS_LOCAL_DOMAIN=1;"

safeExecsql $NodeID "insert into t_cmg_listen(NODE_ID, CONTAINER_ID, CMG_LISTEN_IPADDR, CMG_LISTEN_PORT, CMG_NAT_IPADDR, CMG_NAT_PORT) VALUES('1',"1",'0.0.0.0',"1554",'${MainIP}',"1554");"

safeExecsql $NodeID "delete from t_cmg_listen where NODE_ID ='${NodeID}';"
safeExecsql $NodeID "insert into t_cmg_listen(NODE_ID, CONTAINER_ID, CMG_LISTEN_IPADDR, CMG_LISTEN_PORT, CMG_NAT_IPADDR, CMG_NAT_PORT) VALUES('${NodeID}',"1",'${LocalIP}',"1554",'${NatIP}',"1554");"
safeExecsql $NodeID "insert into t_cmg_listen(NODE_ID, CONTAINER_ID, CMG_LISTEN_IPADDR, CMG_LISTEN_PORT, CMG_NAT_IPADDR, CMG_NAT_PORT) VALUES('${NodeID}',"1",'0.0.0.0',"5060",'${NatIP}',"5060");"
safeExecsql $NodeID "delete from t_connect where NODE_ID ='${NodeID}';"
safeExecsql $NodeID "insert into t_connect(NODE_TYPE,NODE_ID,CONNECT_NODE_TYPE,CONNECT_NODE_ID,LOCAL_IP_ADDR,LOCAL_PORT) values (888,${NodeID},666,1,'127.0.0.1',-1) ;"
safeExecsql $NodeID "insert into t_connect(NODE_TYPE,NODE_ID,CONNECT_NODE_TYPE,CONNECT_NODE_ID,LOCAL_IP_ADDR,LOCAL_PORT) values (888,${NodeID},999,${NodeID},'127.0.0.1',-1) ;"
safeExecsql $NodeID "insert into t_connect(NODE_TYPE,NODE_ID,CONNECT_NODE_TYPE,CONNECT_NODE_ID,LOCAL_IP_ADDR,LOCAL_PORT) values (999,${NodeID},666,1,'127.0.0.1',-1) ;"

safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(999, 0, 'lkdc_https_agent',0,'加密LKDC代理网关',1);"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(999, 0, 'scm_service',0,'软件加密插件',1);"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(888, 0, 'sipex_source',1,'sip UDP媒体接入',1)"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(999, 0, 'service_sip_gateway',0,'SIP服务网关',1)"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(999, 0, 'hyp_gateway',0,'hyp信令协议服务网关',0);"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(999, 0, 'mbe_client_http_gateway',0,'HTTP客户端网关',0);"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(999, 0, 'ws_gateway',0,'websocket网关',0);"
safeExecsql $NodeID "replace INTO T_PLUGIN(NODE_TYPE, NODE_ID, PLUGIN_NAME,PRI,REMARK,INUSE) VALUES(888, 0, 'rtsp_udp_source',1,'RTSP UDP媒体接入',0);"

safeExecsql $NodeID "delete from t_listen where NODE_ID ='1';"
safeExecsql $NodeID "insert into t_listen(NODE_TYPE,NODE_ID,IP_ADDR,PORT) values (666,1,'${MainIP}',6660) ;"
safeExecsql $NodeID "insert into t_listen(NODE_TYPE,NODE_ID,IP_ADDR,PORT) values (999,${NodeID},'${LocalIP}',9990) ;"

safeExecsql $NodeID "delete from T_FORWARDING_CONFIG where NODE_ID ='${NodeID}';"
safeExecsql $NodeID "INSERT INTO T_FORWARDING_CONFIG(NODE_ID,MTN_ID,MTN_IP,MTN_PORT,MTN_NAT_IP,MTN_NAT_PORT,MTN_VIDEO_PORT,MTN_VIDEO_NAT_PORT,MTN_AUDIO_PORT,MTN_AUDIO_NAT_PORT,NODE_NAME) VALUES (${NodeID}, '1', '${LocalIP}', '9012', '${NatIP}', '9012', '9500', '9500', '9501', '9501', '${NatIP}_${NodeID}');"

safeExecsql $NodeID "delete from T_MTN_NAT_CONFIG where NODE_ID ='${NodeID}';"
safeExecsql $NodeID "INSERT INTO T_MTN_NAT_CONFIG(NODE_ID,MTN_ID,MTN_IP,MTN_PORT,MTN_NAT_IP,MTN_NAT_PORT) VALUES (${NodeID}, '1', '${LocalIP}', '9042', '${NatIP}', '9042');"

safeExecsql $NodeID "UPDATE t_sdp_param_config SET CONFIG_VALUE='0.0.0.0' WHERE CONFIG_NAME = 'CIG_LISTEN_IPADDR';"

safeExecsql $NodeID "delete from T_MTN_LOAD_CONFIG where NODE_ID = '${NodeID}';"
if [[ ${PhoneNode} == '0' ]]; then
	safeExecsql $NodeID "INSERT INTO T_MTN_LOAD_CONFIG VALUES ('${NodeID}', '1000', '1000', '90');" 
fi

safeExecsql $NodeID "delete from t_sip_rfc_local_info;"
safeExecsql $NodeID "INSERT INTO t_sip_rfc_local_info VALUES ('${NodeID}', '1', '0.0.0.0', '5060', '123456');"

echo "restart sie"
service sie restart

echo "done!"
