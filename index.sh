#!/bin/bash

# Disk seçimi
echo "Lütfen kurulumu yapmak istediğiniz diski belirtin (örneğin: /dev/sda):"
read DISK

# Disk onayı
echo "Seçilen disk: $DISK. Devam etmek istiyor musunuz? (evet/hayır):"
read ONAY
if [ "$ONAY" != "evet" ]; then
    echo "Kurulum iptal edildi."
    exit 1
fi

# Disk bölümlendirme ve formatlama
echo "Diski formatlıyorum..."
parted $DISK mklabel gpt
parted $DISK mkpart primary ext4 1MiB 100%
mkfs.ext4 ${DISK}1
mount ${DISK}1 /mnt

# Temel sistem kurulumu
echo "Temel sistem kurulumu başlatılıyor..."
pacstrap /mnt base linux linux-firmware

# Fstab oluşturma
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot içine geçiş
arch-chroot /mnt /bin/bash <<EOF

# Saat dilimi ve dil ayarları
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=trq" > /etc/vconsole.conf
locale-gen

# Ağ ayarları
echo "archlinux" > /etc/hostname
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
EOL

# Root şifresi
echo "Root şifresini belirleyin:"
passwd

# Bootloader kurulumu
pacman -Sy --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Kullanıcı oluşturma
useradd -m -G wheel -s /bin/bash eymen
echo "Kullanıcı şifresini belirleyin:"
passwd eymen

# Sudo yapılandırma
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Cutefish ve LightDM kurulumu
pacman -Sy --noconfirm xorg-server cutefish lightdm lightdm-slick-greeter
systemctl enable lightdm

# Yay kurulumu
pacman -Sy --noconfirm git
sudo -u eymen bash -c "cd /home/eymen && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"

EOF

echo "Kurulum tamamlandı! Sistemi yeniden başlatabilirsiniz."
umount -R /mnt
reboot
