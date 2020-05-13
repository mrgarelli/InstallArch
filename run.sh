#!/bin/bash

USAGE='''Commands:
	checkEFI
	checkInternet
	setWifi
	setupGit
	reset
	setClock
	partitionDisk <disk> <bootSize> <rootSize> <swapSize> <homeSize>
		defaults[GB]: 1 boot, 20 root, 12 swap, rest of filesystem home
	format <partitionIdentifier>
		example: for partition /dev/sda1, partitionIdentifier=sda
	mounting <partitionIdentifier>
		example: for partition /dev/sda1, partitionIdentifier=sda
	update
	install
	tab
	enterSys
	internalInstall
	sysSetup <hostname> <city>
		defaults: UA, Detroit
	bootOrder
	grubSetup
	prepareReboot
	createUser <username>'''

function checkEFI() {
if [[ $(ls '/sys/firmware/efi/efivars' &>/dev/null; echo $?) -eq 0 ]]; then
	echo 'This is an EFI system.'
else
	echo 'This is not an EFI system. This guide does not apply :('
fi
}

function checkInternet() {
ping -q -c 1 google.com &>/dev/null
if [[ $? -ne 0 ]]; then
	echo 'There is no internet.'
else
	echo 'There is internet! Skip setWifi command.'
fi
}

function setWifi() {
wifi-menu
echo "now run sudo netctl start <service>"
}

function setupGit() {
git config --global user.email "mrgarelli@gmail.com"
git config --global user.name "Matthew Garelli"
}

function reset() {
umount -R /mnt
swapoff -a

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk "${disk}"
	g # clear the in memory partition table
	w # write the partition table
	q # and we're done
EOF
}

function format() {
part="${1}"

# formatting
mkfs.fat -F32 /dev/${part}1
mkfs.ext4 /dev/${part}2
mkswap /dev/${part}3
mkfs.ext4 /dev/${part}4
}

function mounting() {
part="${1}"

# mounting
mount /dev/${part}2 /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/${part}1 /mnt/boot/efi
mkdir -p /mnt/home
mount /dev/${part}4 /mnt/home
swapon /dev/${part}3
}

function userSetup() {
HOSTNM="${1}"
CITY="${2}"
ln -sf /usr/share/zoneinfo/America/${CITY} /etc/localtime
hwclock --systohc
echo "LANG=en_US>UTF-8" > /etc/local.conf
locale-gen
echo "${HOSTNM}" > /etc/hostname
}

function hostSetup() {
hostname="${1}"
HOSTS=$(cat <<-END
127.0.0.1	localhost
::1		localhost
127.0.1.1	${hostname}.localdomain  ${hostname}
END
)
echo "${HOSTS}" >> /etc/hosts
}

function customGit() {
dir="${1}"
git --git-dir=$HOME/${dir}/ --work-tree=$HOME "${@:2}"
}

case "${1}" in

	"checkEFI")
		checkEFI
		;;
	"checkInternet")
		checkInternet
		;;
	"setWifi")
		reset
		;;
	"setupGit")
		setupGit
		;;
	"reset")
		setWifi
		;;
	"setClock")
		timedatectl set-ntp true
		timedatectl set-timezone America/Detroit
		;;
	"partitionDisk")
		./partitioning.sh "${2}" "${3}" "${4}" "${5}" "${6}"
		;;
	"format")
		format "${2}"
		;;
	"mounting")
		mounting "${2}"
		;;
	"update")
		pacman -Syy
		pacman -Sy archlinux-keyring
		;;
	"install")
		pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub networkmanager
		;;
	"tab")
		genfstab -U /mnt >> /mnt/etc/fstab
		;;
	"enterSys")
		arch-chroot /mnt # chroot into the system
		;;
	"internalInstall")
		pacman -Sy gvim git dhcpcd dhclient man-db man-pages sudo openssh netctl tree dialog python3 python-pip xonsh i3-gaps feh dmenu xorg-xinit xorg-server picom lxappearance pcmanfm code unclutter konsole firefox pulseaudio pulseaudio-bluetooth pulseaudio-alsa alsa-utils bluez bluez-utils paman iw
		systemctl enable bluetooth.service
		systemctl --user enable pulseaudio
		amixer sset Master unmute
		;;
	"sysSetup")
		hostname="${2}"
		city="${3}"
		userSetup "${hostname:=ua}" "${city:=Detroit}"
		hostSetup "${hostname:=ua}"

		systemctl enable NetworkManager
		passwd
		;;
	"grubSetup")
		grub-install --target=x86_64-efi --efi-directory=/boot/efi
		grub-mkconfig -o /boot/grub/grub.cfg
		;;
	"bootOrder")
		efibootmgr -v
		echo "To change the boot order use:"
		echo "efibootmgr -o 0002,0001,0003"
		;;
	"prepareReboot")
		umount -R /mnt
		swapoff -a
		;;
	"createUser")
		username="${2}"
		useradd -m -g users -G wheel "${username}"
		passwd "${username}"
		;;
	*)
		echo "${USAGE}"
		;;
esac
