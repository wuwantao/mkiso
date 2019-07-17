mkisofs -R -J -T -v --no-emul-boot --boot-load-size 4 \
 --boot-info-table -V "CentOS 6.5 x86_64 AUTO Install" \
 -b isolinux.bin -c boot.cat \
 -o ./test.iso \
 ./auto_iso
