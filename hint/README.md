isolinux.cfg是干什么的?
1.首先光盘镜像也就是iso文件采用的是“ISO 9660 ”文件系统 。
cd上的文件都存在这个简单的iso文件系统里，linux可以用mount  -o loop 直接把*.iso文件mount到一个目录查看。

2.CD ROM 另支持一个叫做“El Torito Bootable CD Specification”     的标准允许用户在cd上指定启动的引导程序。
电脑开机启动时候，BIOS就会去检查cd/dvd上是否有这个启动标志，然后加载引导程序。
在Linux系统，使用mkisofs命令一个iso文件时，可以指定引导程序，例如
mkisofs -o <isoimage> -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
<root-of-iso-tree> 
更多的iso文件相关选项可以参考mkisofs的help  

3.Linux的光盘安装的话，使用的一般是ISOLINUX 引导程序，也就是用这个ISOLINUX是被写到上面那个EI Torito扩展里面去的。 系统启动时就自动加载ISOLINUX引导程序了。
ISOLINUX是  SYSLINUX项目的一系列引导程序中的一个，简单的说就是类似GRUB的一个东西，就是启动然后引导内核。ISOLINUX的特点如其名，区别于 GRUB LILO等的地方，
就是他可以认出iso9660文件系统，所以可以读出cd上的内核镜像和inird 镜像，然后引导。
ISOLINUX启动后，默认会去读出cd光盘根目录的一个isolinux.cfg 文件，isolinux.cfg 类似grub的menu.lst，
指定的内核镜像位置等。这个isolinux.cfg的语法可以参考syslinux的文档。
SYSLINUX不知道是被封了还是怎么样，主页打不开，这里有个源码目录
可以在里面找到些简单的文档和看看代码什么的，SYSLINUX包括了用于网络引导PXELINUX等程序，可以自己去看一下。
4.isolinux引导加载Linux内核遵循一个叫做 “Multiboot Specification ” 的标准
这个Multiboot 定义了isoLinux如何去按照指定格式被内核文件加载到内存里面来，还有可以指定模块怎么加载等。
isolinux先去加载自己的mboot.c32模块 以支持multiboot模式，然后mboot32.c32在去根据配置加载内核和模块。
比如一个 isolinux.cfg 是这样的
LABEL Xen
    KERNEL mboot.c32
    APPEND xen.gz dom0_mem=15000 nosmp noacpi --- linux.gz console=tty0 root=/dev/hda1 --- initrd.img

mboot的代码

在get_modules 函数中就会解析各个模块和参数，然后加载。APPEND 后面的字符串传给mboot.c32  后
mboot.c32 以 “---” 作为分界线， xen.gz dom0_mem=15000 nosmp noacpi   就是把 “dom0_mem=15000 
nosmp noacpi   ” 传给 xen.gz模块作为参数。 “console=tty0 root=/dev/hda1 ”传给 linux.gz 模块作为参数.
linux.gz这些就是位于 cd 镜像里面的位置了，一般跟目录下吧。
linux.gz这些加载运行后，自然可以根据multiboo格式，读到 console=tty0 这些参数了。
至此系统引导成功，切换到linux环境，比如指定inird.img 文件系统的某个python程序，然后开始显示界面，提示用户安装。



hint是
append initrd=initrd.img    install
cat /proc/cmdline |grep install 
initd.img
/etc/init.d/rcS
/bin/grep -q install /proc/cmdline && /bin/setup
之后执行安装grup-install