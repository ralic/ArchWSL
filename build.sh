#!/bin/bash -x

# Warning: this script is not supposed to be run on real system,
# as it will clean up after itself.
# Use it only in ephemeral environments, such as Travis CI.

source ./env.sh

curl -L ${ISO_URL} -o ${ISO_FN}
curl -L ${FRTCP_URL} -o ${FRTCP_FN}
curl -L ${LNCR_URL} -o ${LNCR_ZIP}

unzip ${LNCR_ZIP} ${LNCR_FN}

mkdir isofs
mount -t iso9660 -o loop,ro ${ISO_FN} isofs
unsquashfs -f -d livefs ./isofs/artix/${ARCH}/rootfs.sfs
unsquashfs -f -d livefs ./isofs/artix/${ARCH}/livefs.sfs

mount --bind livefs livefs
mount -t proc none livefs/proc
mount -t sysfs none livefs/sys
mount -t devtmpfs none livefs/dev
mount -t devpts none livefs/dev/pts
mount -t tmpfs none livefs/dev/shm
mount -t tmpfs none livefs/run
mount -t tmpfs none livefs/tmp
mount --bind /etc/resolv.conf livefs/etc/resolv.conf
mkdir livefs/run/shm

mkdir rootfs
mount --bind rootfs rootfs
mount --bind rootfs livefs/mnt

cat <<EOF | chroot livefs /bin/bash -x -
basestrap -G -M -c /mnt ${PAC_PKGS}
EOF

echo "LANG=en_US.UTF-8" >> rootfs/etc/locale.conf
sed -i -e "s/#en_US.UTF-8/en_US.UTF-8/" rootfs/etc/locale.gen
sed -i -e "s/#IgnorePkg   =/IgnorePkg   = fakeroot/" rootfs/etc/pacman.conf
cp ${FRTCP_FN} rootfs/root/

cat <<EOF | chroot livefs artools-chroot /mnt /bin/bash -x -
locale-gen
pacman -U /root/${FRTCP_FN} --noconfirm
EOF

echo "# This file was automatically generated by WSL. \
To stop automatic generation of this file, remove this line." > rootfs/etc/resolv.conf
rm -f rootfs/root/${FRTCP_FN}

tar zcpf rootfs.tar.gz -C rootfs .
zip Artix.zip ${LNCR_FN} rootfs.tar.gz runsvdir.ps1
