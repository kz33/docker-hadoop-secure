#!/bin/bash

: ${HADOOP_PREFIX:=/usr/local/hadoop}

#$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
#echo "export HADOOP_OPTS=\"$HADOOP_OPTS -Djavax.net.debug=ssl -Dsun.security.krb5.debug=true\"" >> $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

rm /tmp/*.pid

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

# kerberos client
sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" /etc/krb5.conf
sed -i "s/example.com/${DOMAIN_REALM}/g" /etc/krb5.conf

# altering the core-site configuration
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_PREFIX/etc/hadoop/core-site.xml
sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/core-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/core-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/mapred-site.xml

# create namenode kerberos principal and keytab
touch /var/log/kerberos/kadmind.log
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -pw password root@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey nn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey dn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey HTTP/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey jhs/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey yarn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey rm/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey nm/$(hostname -f)@${KRB_REALM}"

kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k nn.service.keytab nn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k dn.service.keytab dn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k spnego.service.keytab HTTP/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k jhs.service.keytab jhs/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k yarn.service.keytab yarn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k rm.service.keytab rm/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k nm.service.keytab nm/$(hostname -f)"

mkdir -p ${KEYTAB_DIR}
mv nn.service.keytab ${KEYTAB_DIR}
mv dn.service.keytab ${KEYTAB_DIR}
mv spnego.service.keytab ${KEYTAB_DIR}
mv jhs.service.keytab ${KEYTAB_DIR}
mv yarn.service.keytab ${KEYTAB_DIR}
mv rm.service.keytab ${KEYTAB_DIR}
mv nm.service.keytab ${KEYTAB_DIR}
chmod 400 ${KEYTAB_DIR}/nn.service.keytab
chmod 400 ${KEYTAB_DIR}/dn.service.keytab
chmod 400 ${KEYTAB_DIR}/spnego.service.keytab
chmod 400 ${KEYTAB_DIR}/jhs.service.keytab
chmod 400 ${KEYTAB_DIR}/yarn.service.keytab
chmod 400 ${KEYTAB_DIR}/rm.service.keytab
chmod 400 ${KEYTAB_DIR}/nm.service.keytab

# create Java Keystore
#keytool -genkey -keyalg RSA -alias c6401 -keystore $HADOOP_PREFIX/lib/keystore.jks -storepass bigdata -validity 360 -keysize 2048 -keypass bigdata -dname CN=$(hostname -f)

$HADOOP_PREFIX/bin/hdfs namenode -format
service sshd start
$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
$HADOOP_PREFIX/sbin/start-dfs.sh
$HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root
$HADOOP_PREFIX/bin/hdfs dfs -put $HADOOP_PREFIX/etc/hadoop/ input

#service sshd start
#$HADOOP_PREFIX/sbin/start-dfs.sh
$HADOOP_PREFIX/sbin/start-yarn.sh
$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh start historyserver

if [[ $1 == "-d" ]]; then
  while true; do sleep 1000; done
fi

if [[ $1 == "-bash" ]]; then
  /bin/bash
fi
