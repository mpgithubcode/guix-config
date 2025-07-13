;; Import necessary modules for system configuration
(use-modules (gnu)
             (gnu packages docker)
             (gnu system uuid)
             (nongnu packages linux))  ;; For custom kernel like linux-lts
(use-service-modules base cups networking ssh linux docker dbus desktop)

(operating-system
  ;; Use long-term support kernel with additional boot arguments
  (kernel linux)
          (kernel-arguments
           (list "quiet"                        ;; Minimal boot messages
                 "noatime"                      ;; Don't update access time on file reads
                 "transparent_hugepage=never"  ;; Disable THP for better latency
                 "cgroup_enable=memory"        ;; Required for Docker memory control
                 "swapaccount=1"               ;; Enable cgroup swap accounting
                 "intel_iommu=on"              ;; Enable Intel IOMMU for device isolation
                 "iommu=pt"))                 ;; Use passthrough mode for direct device access

  ;; Nonfree firmware blobs (Wi-Fi, graphics, etc.)
  (firmware (list linux-firmware))

  ;; Localization
  (locale "en_US.utf8")
  (timezone "America/New_York")
  (keyboard-layout (keyboard-layout "us"))

  ;; Hostname for networking
  (host-name "guixserver")

  ;; Define users with sudo/wheel and other groups
  (users
   (cons*
    (user-account
     (name "alice")
     (group "users")
     (home-directory "/home/alice")
     (supplementary-groups '("wheel" "netdev" "audio" "video" "docker")))
    %base-user-accounts))

  ;; System packages available for all users (base tools + Docker)
  (packages
   (append %base-packages
           (list docker docker-compose)))  ;; Add Docker

  ;; System services
  (services
   (cons*
    (service dbus-root-service-type)
    (service elogind-service-type)
    (service containerd-service-type)
    (service docker-service-type)
    (service openssh-service-type)
    (service ntp-service-type)

    ;; Static network configuration (replace "eth0" with your real interface)
    (service static-networking-service-type
             (list
              (static-networking
               (addresses
                (list (network-address
                       (device "enp0s31f6")
                       (value "192.168.1.100/24"))))
               (routes
                (list (network-route
                       (destination "default")
                       (gateway "192.168.1.1"))))
               (name-servers '("1.1.1.1" "8.8.8.8")))))

    (service cups-service-type)
    (service zram-device-service-type
             (zram-device-configuration
              (size "1G")))

    %base-services))  ;; Add core system services

  ;; Bootloader configuration
  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets (list "/boot/efi"))
    (keyboard-layout keyboard-layout)))

  ;; Filesystem definitions
  (file-systems
   (cons*
    ;; Root partition (read-only)
    (file-system
     (device (file-system-label "SYSTEM"))
     (mount-point "/")
     (type "ext4")
     (flags '(read-only)))
  
    ;; EFI system partition for GRUB
    (file-system
     (device (file-system-label "EFI"))
     (mount-point "/boot/efi")
     (type "vfat"))
  
    ;; Persistent storage partition
    (file-system
     (device (file-system-label "DATA"))
     (mount-point "/persist")
     (type "ext4"))
  
    ;; Bind-mount persistent directories into standard locations
    (file-system
     (device "/persist/etc")
     (mount-point "/etc")
     (type "none")
     (flags '(bind-mount no-auto)))
  
    (file-system
     (device "/persist/var")
     (mount-point "/var")
     (type "none")
     (flags '(bind-mount no-auto)))
  
    (file-system
     (device "/persist/home")
     (mount-point "/home")
     (type "none")
     (flags '(bind-mount no-auto)))
  
    ;; Bind-mount /gnu for package store
    (file-system
     (device "/persist/gnu")
     (mount-point "/gnu")
     (type "none")
     (flags '(bind-mount no-auto)))
  
    ;; Bind-mount /tmp to disk-based directory
    (file-system
     (device "/persist/tmp")
     (mount-point "/tmp")
     (type "none")
     (flags '(bind-mount no-auto)))

    ;; Add essential pseudo-filesystems like /proc, /sys, /dev
    %base-file-systems)))
