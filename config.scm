(use-modules (gnu)
             (gnu packages docker)
             (gnu system uuid)
             (nongnu packages linux)             ;; For custom kernel like linux-lts
             (nongnu packages firmware)          ;; Added for linux-firmware
             (nonguix packages nvidia)           ;; NVIDIA driver & graft helper
             (nonguix services nvidia)           ;; NVIDIA system service
             (nongnu system linux-initrd))       ;; Enables microcode-initrd convenience
(use-service-modules base cups networking ssh linux docker dbus desktop)

(operating-system

  ;; Use kernel with parameters
  (kernel linux)
  (kernel-arguments
   (list "quiet"
         "noatime"
         "transparent_hugepage=never"
         "cgroup_enable=memory"
         "swapaccount=1"
         "intel_iommu=on"
         "iommu=pt"
         "modprobe.blacklist=nouveau"     ;; Disable open-source Nouveau driver
         "nvidia_drm.modeset=1"))         ;; Enable modesetting for NVIDIA DRM

  ;; Nonfree firmware blobs
  (firmware (list linux-firmware))

  ;; Add Intel microcode to the initrd
  (initrd microcode-initrd)

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
           (list docker
                 docker-compose
                 intel-microcode                   ;; CPU microcode for Intel i7
                 nvidia-driver)))                  ;; Proprietary NVIDIA driver from NonGuix

  ;; Services
  (services
   (cons*
    (service dbus-root-service-type)
    (service elogind-service-type)
    (service containerd-service-type)
    (service docker-service-type)
    (service openssh-service-type)
    (service ntp-service-type)
    (service nvidia-service-type)
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
     (type "ext4"))

    ;; EFI partition
    (file-system
     (device (file-system-label "EFI"))
     (mount-point "/boot/efi")
     (type "vfat"))

    %base-file-systems)))
