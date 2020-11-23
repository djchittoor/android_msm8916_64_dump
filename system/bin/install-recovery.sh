#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/bootdevice/by-name/recovery:20716844:56b7675bd5bd06951edcdea214140583933dc299; then
  applypatch -b /system/etc/recovery-resource.dat EMMC:/dev/block/bootdevice/by-name/boot:18179368:32dadcfeea475999fdab38942f5bf7fda9cceb79 EMMC:/dev/block/bootdevice/by-name/recovery 56b7675bd5bd06951edcdea214140583933dc299 20716844 32dadcfeea475999fdab38942f5bf7fda9cceb79:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
