

```shell
#!/bin/bash

read -p "请输入数据库目录，例如：/mysqldata /apply: " dir

if [ -z "$dir" ]; then
    echo "请输入正确数据库目录，例如：/mysqldata /apply"
    exit
elif [ ! -d "$dir" ]; then
    echo "您输入的目录为'$dir'，将为您创建目录：$dir"
    mkdir -p "$dir"
    echo "-----  目录创建完成  -----"
else
    echo "----- 您安装的数据库目录为: $dir   -----"
fi



# 查看自己的系统版本
cat  /etc/redhat-release

# 查看自己的ip 地址

ip add  | grep -oP 'inet \K[\d.]+' |sed -n 2p > /root/ip.txt

#判断系统本地域名解析信息

if grep -f /root/ip.txt /etc/hosts | grep -q "$(cat /etc/hostname)"; then
    echo "----- 已经在hosts中解析        -----"
else
    echo "-----   未在/hosts解析        -----"
    if ! grep -qF "$(grep -f /root/ip.txt /etc/hosts)" /etc/hosts; then
        sudo bash -c "grep -f /root/ip.txt /etc/hosts | grep $(cat /etc/hostname) >> /etc/hosts"
        echo "-----     已将输出追加到 /etc/hosts 中    -----"
    else
        echo "-----     输出已存在于 /etc/hosts 中      -----"

    fi
fi

# 判断防火墙是否关闭

if [ "$(systemctl is-active firewalld)" != "unknown" ]; then
    systemctl stop firewalld
        echo "-----     已关闭防火墙    -----"
    systemctl disable firewalld
        echo "-----     已关闭开机自启  -----"
        systemctl status firewalld
fi
# 清理系统自带的mariadb数据库服务相关的程序包

if  rpm -qa | grep mariadb; then
        echo "-----     MariaDB 已安装  -----"
        echo "-----     准备卸载 MariaDB        -----"
        yum remove -y mariadb-libs   >  /dev/null
        echo "-----     MariaDB 卸载7完毕        -----"
else
        echo "-----  没有安装 MariaDB    ------"
fi

# 安装数据库服务程序所需的依赖软件包

echo "-----  正在安装 mysql所需的依赖软件包 -----"
packages=("libaio-devel" "lrzsz" "tree"  "net-tools")

# 循环检查每个软件包是否已安装
for package in "${packages[@]}"; do
    if rpm -q "$package" >/dev/null 2>&1; then
        echo "-----   $package 已安装   -----"
    else
        echo "-----   没有安装 $package   ------"
    fi
done

# 创建mysql用户

if ! getent passwd mysql > /dev/null; then
    echo "-----  用户 mysql 不存在，正在创建   -----"
    groupadd mysql
    useradd -r -g mysql mysql
    echo "-----  用户 mysql 创建成功  -----"
else
    echo "-----  用户 mysql 已存在，跳过创建  -----"
fi
# 开始解压mysql安装包 ,并安装
echo  "-----   切换到安装包目录   -----"

cd    /root/mysql

echo "-----     解压安装包并安装        -----"
tar -xf mysql-5.7.40-1.el7.x86_64.rpm-bundle.tar  && yum -y localinstall mysql-community-{libs-compat,client,devel,libs,server,common}-5.7.40-1.el7.x86_64.rpm  > /dev/null

echo "-----     删除默认的配置文件      -----"
rm    -rf   /etc/my.cnf

echo "-----     移动初始化配置文件      -----"
cp   /root/mysql/my.cnf1    /etc/my.cnf


echo "-----     属主属组目录授权        -----"

chown  -R   mysql:mysql   $dir

echo "-----     启动数据库服务           -----"
systemctl start mysqld

# 查看初始化密码
grep password   $dir/error.log | awk '{print $NF}' > /etc/.dbpwd


#修改数据库密码

mysql -uroot -p`cat /etc/.dbpwd` -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'Mysteel@123'; create user wangke@'%' identified by 'Wangke@123'; grant all on *.* to wangke@'%'; flush privileges; "
if [ $? -eq 0 ];
then
     echo "-----     mysql密码重置成功  -----" 
else
     echo "-----     mysql密码重置报错  ------"
fi


# 关闭数据库服务

systemctl stop mysqld

exit_code=$?

if [ $exit_code  -eq 0 ]; then
     echo "-----      mysql服务已成功停止    -----"
else
     echo "-----      mysql服务停止失败      -----"
fi 

# 开始数据库初始化后

mv    /etc/my.cnf    /etc/my.cnf.bak
cp    /root/mysql/my.cnf2  /etc/my.cnf

# 根据初始化后的配置文件创建目录

mkdir -p  $dir/binlog
mkdir -p  $dir/slowlog
mkdir -p  $dir/relaylog

chown -R   mysql:mysql    $dir


# 启动服务
systemctl start mysqld

exit_code1=$?

if [ $exit_code1 -eq 0 ]; then
    echo "-----     MySQL安装配置成功，谢谢使用！  -----"
else
    echo "-----     MySQL服务重启失败,请检查'$dir/error.log' 下面   -----"
fi



```

