;; Import necessary modules for system configuration
(use-modules (gnu)
             (nongnu packages linux))  ;; For custom kernel like linux-lts
(use-service-modules base cups networking ssh docker)

(operating-system
  ;; Use long-term support kernel with additional boot parameters
  (kernel linux-lts
          (kernel-parameters
           (list
            "quiet"                        ;; Minimal boot messages
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
     (comment "Admin User")
     (group "users")
     (home-directory "/home/alice")
     (supplementary-groups '("wheel" "netdev" "audio" "video" "docker")))
    %base-user-accounts))

  ;; System packages available for all users (base tools + Docker)
  (packages (append %base-packages
                    (list docker)))  ;; Add docker

  ;; System services
  (services
   (list
    (service docker-service-type)          ;; Enable Docker service
    (service openssh-service-type)        ;; Enable SSH server
    (service ntp-service-type)            ;; Clock sync via NTP

    ;; Static network configuration (replace "eno1" with your real interface)
    (service static-networking-service-type
     (list
      (static-networking
       (addresses
        (list (network-address
            (device "eth0")
            (value "192.168.1.100/24"))))
         (routes
          (list (network-route
            (destination "default")
            (gateway "192.168.1.1"))))
          (name-servers '("1.1.1.1" "8.8.8.8"))))


    (service cups-service-type)           ;; Printer server (optional)
    (service zram-device-service-type     ;; RAM-compressed swap device
             (zram-device-configuration
              (size "1G")))))              ;; Adjust to match available RAM

  ;; Bootloader configuration
  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)      ;; EFI-compatible bootloader
    (targets (list "/boot/efi"))          ;; EFI system partition
    (keyboard-layout keyboard-layout)))   ;; Use same layout in bootloader

  ;; Filesystem definitions
  (file-systems
   (append
    (list
     ;; Root partition (read-only, minimal system)
     (file-system
      (device (label "SYSTEM"))
      (mount-point "/")
      (type "ext4")
      (flags '(read-only)))

     ;; EFI partition for GRUB bootloader
     (file-system
      (device (label "EFI"))
      (mount-point "/boot/efi")
      (type "vfat"))

     ;; Persistent partition to store /var, /home, /etc
     (file-system
      (device (label "DATA"))
      (mount-point "/persist")
      (type "ext4"))

     ;; Bind-mount persistent paths into standard FHS locations
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
      (flags '(bind-mount))))
    
    ;; Add essential pseudo-filesystems like /proc, /sys, /dev
    %base-file-systems)))
