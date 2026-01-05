#!/bin/sh

NodeID=$1
EncryptType=$2
UserID=$3
DomainCode=$4

source ./safeExec.sh

if [[ ${NodeID} == '' ]] || [[ ${EncryptType} == '' ]] || [[ ${UserID} == '' ]] || [[ ${DomainCode} == '' ]] ; then
	echo "Parameters are invalid, format: <NodeID>,<EncryptType>-- 加密类型,-1:未加密,3:黑区加密, 4: 红区加密,<UserID> --网关用户ID,<DomainCode>"
	echo "please input like this addGwUserConfig.sh 2 3 86674655 sdfasf"
	exit
fi

echo "add gateway user config, node id:${NodeID}, encrypt type :${EncryptType}, user id:${UserID},domain code:${DomainCode}"

# 提示用户输入数据库密码
echo -n "Please enter database password: "
read -s DB_PASSWORD
echo
if [ -z "$DB_PASSWORD" ]; then
    echo "Error: Password cannot be empty"
    exit 1
fi

service sie stop

# 导出密码变量，供 safeExec.sh 中的函数使用
export DB_PASSWORD

safeExecsql $NodeID "delete from t_sip_encrypt where NODE_ID = '${NodeID}';"

safeExecsql $NodeID "replace into t_sip_encrypt(NODE_ID, CONTAINER_ID, KEY_FILE, DEV_PATH, ENCRYPT_TYPE, KEY_PASS,DEV_ID,USER_ID) VALUES(${NodeID},1,'','',${EncryptType},'','','${UserID}');"

safeExecsql $NodeID "update t_domain_info set DOMAIN_CODE= '${DomainCode}',PARENT_DOMAIN_CODE='${DomainCode}' where IS_LOCAL_DOMAIN=1;"

cp watchdog.ini /home/hy_media_server/conf/
sed -i "s/-n [0-9]\+/ -n ${NodeID}/g" /home/hy_media_server/conf/watchdog.ini

echo "restart sie"
service sie restart


echo "done!"
