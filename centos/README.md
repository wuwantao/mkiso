cat /anaconda-13.21.215/loader/kickstart.c
    while (rc != 0) {
        if (!strncmp(c, "ks", 2)) {
            rc = kickstartFromNfs(NULL, loaderData);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "http", 4) || !strncmp(c, "ftp://", 6)) {
            rc = kickstartFromUrl(c, loaderData);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "nfs:", 4)) {
            rc = kickstartFromNfs(c+4, loaderData);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "floppy", 6)) {
            rc = kickstartFromRemovable(c);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "hd:", 3)) {
            rc = kickstartFromHD(c);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "bd:", 3)) {
            rc = kickstartFromBD(c);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "cdrom", 5)) {           //文件在iso里面
            rc = kickstartFromCD(c);
            loaderData->ksFile = strdup("/tmp/ks.cfg");
        } else if (!strncmp(c, "file:", 5)) {           //文件在initd.img镜像内部
            loaderData->ksFile = c+5;
            break;
        }
anacoda编译出来的init 来分析isolinux.cfg中的传递给内核参数ks=file:/ks.cfg


使用光盘iso实现Linux操作系统的自动安装部署
前边写了一篇使用 PXE 的方式批量安装操作系统，不是任何时候任何地方都有环境来通过 PXE 方式来进行安装。如果此时需要通过光盘安装，默认的情况下是通过交互式方式进行安装，其实也可以通过 kickstart 的方式来实现自动化安装部署。光盘通过 ks.cfg 进行安装的实现方式比较简单，下边简单的进行总结。

一、实现原理

光盘通过读取 ks.cfg 文件来实现安装操作系统，ks.cfg 配置文件放在光盘的根目录即可，然后修改 isolinux/isolinux.cfg 文件，设置内核参数，指定 ks.cfg 文件的位置即可。由于原始 iso 镜像文件是只读的，不能直接在 iso 光盘目录文件内进行修改，需要拷贝到一个临时目录，修改完后在封装为 iso 镜像文件。

二、拷贝镜像临时目录

mkdir /mnt/cdrom
mount -o loop CentOS-6.8-x86_64-minimal.iso /mnt/cdrom
cp -ar /mnt/cdrom/ /root/iso    # 原来root下没有iso目录，拷贝过来重命名为iso
三、生成 ks.cfg 文件

生成 ks.cfg 文件的方式大概有2种，一是可以通过图形工具 system-config-kickstart 来定制生成指定的 ks.cfg 文件，二是对于熟悉 kickstart 语法的可以直接编写 ks.cfg 配置文件。本次实验用的 ks.cfg 配置比较简单，是通过工具生成的，下边给出本次的 ks.cfg 文件。

复制代码
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use CDROM installation media
cdrom
# Root password
rootpw --iscrypted $1$p6oEoqGo$UDHZdzw56Rl6Rt5oi1A0Q1
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use graphical install
graphical
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Do not configure the X Window System
skipx
# Installation logging level
logging --level=info
# Reboot after installation
#reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel 
# Disk partitioning information
part /boot --asprimary --fstype="ext4" --ondisk=sda --size=200
part swap --asprimary --fstype="swap" --ondisk=sda --size=4096
part / --asprimary --fstype="ext4" --grow --ondisk=sda --size=1
复制代码
拷贝到光盘镜像根目录：

/bin/cp ks.cfg /root/iso/
四、修改启动项菜单内核参数

修改菜单项配置文件 isolinux/isolinux.cfg：

default vesamenu.c32
#prompt 1
timeout 1    # 超时自动选择菜单时间设置，设置为1时，即一闪而过，设置3秒为好。
修改内核参数，指定 ks.cfg 位置：

label linux
  menu label ^Install CentOS 6.8 x64 System.    # 自定义了菜单
  menu default
  kernel vmlinuz
  append initrd=initrd.img ks=cdrom:/ks.cfg     # 添加了ks文件的位置：光盘的根目录
五、封装iso镜像文件

cd /root/iso/    # 进入镜像制作目录
如果没有 mkisofs 命令，执行安装：

yum install mkisofs -y
执行封装镜像的命令：











CentOS裁剪

裁剪都基于CentOS6.3 64位操作，以下是自己总结出的裁剪步骤：

最小化安装CentOS后，将最小化安装所使用RPM生成我们所需要的列表。
cat install.log |awk '{print $2}' | sed 's/^[0-9]\://g' | sed '$d' >> yy_install.list

创建我们需要挂载镜像的路径与生成镜像所需文件的路径
mkdir /mnt/iso/ /mnt/yyiso/

挂载CentOS镜像到/mnt/iso/后，将镜像文件夹里目录文件与结构都复制到/mnt/yyiso/下，除了Packages文件夹及其下的RPM

rsync -a --exclude “Packages” /mnt/iso /mnt/yyiso/

创建一个脚本，用于复制最小安装所需要的RPM，所需要的RPM参照第一步生成的yy_install.list文件。
#!/bin/sh
DEBUG=1
SOURCE_RPMS_DIR=/mnt/iso/Packages/
LOCAL_RPMS_DIR=/mnt/yyiso/Packages/
PACKAGES_LIST=/root/yy_install.list
NUMBER_RPMS=`cat $PACKAGES_LIST |wc -l`
while [ $DEBUG -le $NUMBER_RPMS ]
do
       NOW_LINE=`head -n $DEBUG $PACKAGES_LIST | tail -n -1`
       echo $NOW_LINE
       NOW_NAME=`echo $NOW_LINE |awk -F "-" '{print $1}'`
       echo $NOW_NAME
       NOW_VERSION=`echo $NOW_LINE |awk -F "-" '{print $2 "-" $3}'`
       echo $NOW_VERSION
       ls $SOURCE_RPMS_DIR/$NOW_NAME-$NOW_VERSION*
       if [ $? -eq 0 ]; then
               echo "Now copy the RPM $NOW_NAME"
               cp $SOURCE_RPMS_DIR/$NOW_NAME-$NOW_VERSION* $LOCAL_RPMS_DIR
       else
               echo "Now copy the RPMS $NOW_NAME"
               cp $SOURCE_RPMS_DIR/$NOW_NAME* $LOCAL_RPMS_DIR
       fi
       DEBUG=`expr $DEBUG + 1`
done
将本地源配置好，使用yum安装之后需要使用的命令（分别用于创建comps.xml文件、生成镜像、解压特定压缩包Img)
yum -y install createrepo mkisofs xz

自动文本安装CentOS过程中，提示CentOS与6.3版本的地方，可通过修改隐藏文件.buildstamp，第一行命令用于解压，第二行命令用于压缩，压缩时间可能较长。
xz -dc initrd.img | cpio -id
find . | cpio -c -o | xz -9 --format=lzma > initrd.img
创建自动安装脚本，首先复制一个基本文件然后将其修改。
cp /root/anaconda-ks.cfg /mnt/yyiso/isolinux/ks.cfg
文件大致为以下内容（install-全新安装、cdrom-指定安装源、text-文本安装、lang-语言、keyboard-键盘、skipx-不对系统的X进入设置、network-网络、rootpw-root密码、firewall-防火墙、authconfig-认证方式、selinux-设置其状态、timeout-时区、bootloader-设置安装选项，如指定内核，启动顺序、clearpart-在建立新分区前清空系统上原有的分区表、zerombr-清除mbr信息与分区表）
# Kickstart file automatically generated by anaconda.

#version=DEVEL
install
cdrom
text
lang zh_CN.UTF-8
keyboard us
skipx
network --onboot no --device eth0 --bootproto dhcp --noipv6
rootpw  --iscrypted $6$5Dr6AAjYpLJbGv5Q$HdWEtOdif6kcnc0ExLV6yqr/B46SrVvBbDHoS1a.TmRq6OtDvd5BacfIm5bZNCla243VMTb3CB4GPW.luYbXA0
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512
selinux --enforcing
timezone --utc Asia/Shanghai
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto rhgb quiet"
clearpart --all --initlabel
zerombr yes
# The following is the partition information you requested
# Note that any partitions you deleted are not expressed
# here so unless you clear all partitions first, this is
# not guaranteed to work

part /boot --fstype=ext4 --size=200
part swap --recommended
part / --fstype=ext4 --size=20000
part /var --fstype=ext4 --size=10000 --grow
#repo --name="CentOS"  --baseurl=cdrom:sr0 --cost=100

%packages
@chinese-support
@core
@server-policy
%end
修改开机选择菜单内容。需要先将isolinux.cfg文件添加上权限，修改后再将权限复原。其主要修改为以下内容，同样意义不作详解。
default linux
#prompt 1
timeout 600

display boot.msg

menu background splash.jpg
menu title Welcome to CentOS 6.3!
menu color border 0 #ffffffff #00000000
menu color sel 7 #ffffffff #ff000000
menu color title 0 #ffffffff #00000000
menu color tabmsg 0 #ffffffff #00000000
menu color unsel 0 #ffffffff #00000000
menu color hotsel 0 #ff000000 #ffffffff
menu color hotkey 7 #ffffffff #ff000000
menu color scrollbar 0 #ffffffff #00000000

label linux
 menu label ^Install or upgrade an existing system
 kernel vmlinuz
 append ks=cdrom:/isolinux/ks.cfg initrd=initrd.img
label local
 menu label Boot from ^local drive
 localboot 0xffff
更新软件仓库。需要当前在/mnt/yyiso/目录下。其中comps.xml包含组列表、组层次、组结构、RPM包，相当于将RPM按组分类。
createrepo -g repodata/*comps.xml .
生成 iso镜像包。生成路径为/opt下
mkisofs -o /opt/yy.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-<span style="background-color: rgb(255, 255, 255);">y </span><span style="font-family: Arial, Helvetica, sans-serif;">boot -boot-load-size 4 -boot-info-table -joliet-long -R -J -v -T .</span>





其它：
如果ks.cfg文件中没有添加zerombr属性，安装过程中提示以下错误。
Error processing drive:
pci-0000:00:10-scsi-0:0:0:0
20480MB
VMware,VMware Virtual S
This device may need to be reinitialized.
REINITIALIZING WILL CAUSE ALL DATA TO BE LOST!
This action may also be applied to all other disks
needing reinitialization.
Device details:
pci-0000:00:10.0-scsi-0:0:0:0
如果已经执行了createrepo命令后，又修改ks.cfg文件，此时直接mkisofs会提示以下错误。（再次执行一次createrepo命令即可）
I: -input-charset not specified, using utf-8 (detected in locale settings)
genisoimage 1.1.9 (Linux)
Scanning .
genisoimage: Uh oh, I cant find the boot catalog directory 'isolinux'!
umount某个目录下提示mount device is busy，可执行以下操作解决，大致为查找到使用这个device忙的进程并将其杀掉。
fuser -m -v /mnt/iso2
umount /mnt/iso2
查询某个命令所需要的RPM包。以giftopnm命令为例。
yum provides */bin/giftopnm
修改选择菜单时背景图片。将修改后的图片替换掉/mnt/yyiso/isolinux/下的splash.gif文件即可。
giftopnm < splash.gif | ppmtolss16 > splash.lss

裁剪后镜像自动安装流程
根据anaconda（安装管理程序）提供的文本模式或图形模式进行，交互或非交互安装（以上是根据启动参数ks.cfg文件配置来文本，非交互安装）




对于Kickstart，它是一个利用Anconda工具实现服务器自动化安装的方法。通过生成的kickstart配置文件ks.cfg，服务器安装可以实现从裸机到全功能服务的的非交互式（无人值守式）安装配置；ks.cfg是一个简单的文本文件，文件包含Anconda在安装系统及安装后配置服务时所需要获取的一些必要配置信息（如键盘设置，语言设置，分区设置等）。Anconda直接从该文件中读取必要的配置，只要该文件信息配置正确无误且满足所有系统需求，就不再需要同用户进行交互获取信息，从而实现安装的自动化。但是配置中如果忽略任何必需的项目，安装程序会提示用户输入相关的项目的选择，就象用户在典型的安装过程中所遇到的一样。一旦用户进行了选择，安装会以非交互的方式（unattended）继续。使用kickstart可以实现流线化自动化的安装、快速大量的裸机部署、强制建立的一致性（软件包，分区，配置，监控，安全性）、以及减少人为的部署失误。
（1）第一阶段：加载安装树的isolinux目录下的内核映像vmlinuz和初始RAM磁盘initrd.img，建立安装环境。initrd.img中的/init程序调用/sbin/loader程序，loader加载kickstart文件，最后运行/usr/bin/anaconda主程序，进入第二阶段。
（2）第二阶段：anaconda程序加载各python和bash模块，执行各个安装步骤
kernel->init->loader

loader程序
    |
    |
   \ /
parseCmdLineFlags(&loaderData, cmdLine);
    |
    |
   \ /
getKickstartFile(&loaderData);


压缩
find . | cpio -c -o | xz -9 --format=lzma > /tmp/initrd.img
解压
xz -dc ../initrd.img | cpio -id

mkisofs -o /root/CentOS6.8_x64.iso \
    -V centos6 -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 \
    -boot-info-table -R -J -T -v .
校验并写入 md5 值(可选)：

implantisomd5 /root/CentOS6.8_x64.iso
通过光盘实现自动化安装已经完成制作，接下来测试可以通过虚拟机，导入 iso 镜像来做测试。