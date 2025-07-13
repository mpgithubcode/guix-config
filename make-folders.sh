#!/bin/bash

mkdir -p /mnt/{gnu,var,etc,home,tmp}
chmod 0555 /mnt/gnu
chmod 0755 /mnt/var /mnt/etc /mnt/home
chmod 1777 /mnt/tmp
chown root:root /mnt/gnu /mnt/var /mnt/etc /mnt/home /mnt/tmp
