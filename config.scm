(use-modules (gnu)
             (gnu packages docker)
             (gnu system uuid)
             (nongnu packages linux))  ;; For custom kernel like linux-lts
(use-service-modules base cups networking ssh linux docker dbus desktop)

(operating-system
  ;; Custom initrd with overlayfs and tmpfs support
  (initrd
   (lambda (file-systems . rest)
     (apply base-initrd
            file-systems
            #:volatile-root? #t
            rest)))

  (initrd-modules
   (append '("overlay" "tmpfs" "ext4" "usbhid" "hid" "ehci-pci" "atkbd")
           %base-initrd-modules))

  ;; Use LTS Linux kernel with parameters
  (kernel linux)
  (kernel-arguments
   (list "quiet"
         "noatime"
         "transparent_hugepage=never"
         "cgroup_enable=memory"
         "swapaccount=1"
         "intel_iommu=on"
         "iommu=pt"))

  ;; Nonfree firmware blobs
  (firmware (list linux-firmware))

  ;; Locale, time, keyboard, hostname
  (locale "en_US.utf8")
  (timezone "America/New_York")
  (keyboard-layout (keyboard-layout "us"))
  (host-name "guixserver")

  ;; User accounts
  (users
   (cons*
    (user-account
     (name "alice")
     (group "users")
     (home-directory "/home/alice")
     (supplementary-groups '("wheel" "netdev" "audio" "video" "docker")))
    %base-user-accounts))

  ;; Global packages
  (packages
   (append %base-packages
           (list docker docker-compose)))

  ;; Services
  (services
   (cons*
    (service dbus-root-service-type)
    (service elogind-service-type)
    (service containerd-service-type)
    (service docker-service-type)
    (service openssh-service-type)
    (service ntp-service-type)
    (service static-networking-service-type
             (list
              (static-networking
               (addresses (list (network-address
                                 (device "enp0s31f6")
                                 (value "192.168.1.100/24"))))
               (routes (list (network-route
                              (destination "default")
                              (gateway "192.168.1.1"))))
               (name-servers '("1.1.1.1" "8.8.8.8")))))
    (service cups-service-type)
    (service zram-device-service-type
             (zram-device-configuration
              (size "1G")))
    %base-services))

  ;; Bootloader
  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets (list "/boot/efi"))
    (keyboard-layout keyboard-layout)))

  ;; Filesystems
  (file-systems
   (cons*
    ;; Root (read-only)
    (file-system
     (device (file-system-label "SYSTEM"))
     (mount-point "/")
     (type "ext4")
     (flags '(read-only)))

    ;; EFI partition
    (file-system
     (device (file-system-label "EFI"))
     (mount-point "/boot/efi")
     (type "vfat"))

    ;; Persistent storage
    (file-system
     (device (file-system-label "DATA"))
     (mount-point "/persist")
     (type "ext4"))

    ;; Bind-mount persistent dirs
    (file-system
     (device "/persist/etc")
     (mount-point "/etc")
     (type "none")
     (flags '(bind-mount)))

    (file-system
     (device "/persist/var")
     (mount-point "/var")
     (type "none")
     (flags '(bind-mount)))

    (file-system
     (device "/persist/home")
     (mount-point "/home")
     (type "none")
     (flags '(bind-mount)))

    (file-system
     (device "/persist/gnu")
     (mount-point "/gnu")
     (type "none")
     (flags '(bind-mount)))

    ;; tmpfs for /run
    (file-system
     (device "none")
     (mount-point "/run")
     (type "tmpfs")
     (options "mode=0755,size=250M"))

    ;; tmpfs for /tmp
    (file-system
     (device "none")
     (mount-point "/tmp")
     (type "tmpfs")
     (options "mode=1777,size=250M"))

    ;; Pseudo filesystems
    %base-file-systems)))
