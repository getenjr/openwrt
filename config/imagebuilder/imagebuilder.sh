#!/bin/bash
#================================================================================================
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the make OpenWrt for Amlogic s9xxx tv box
# https://github.com/ophub/amlogic-s9xxx-openwrt
#
# Description: Build OpenWrt with Image Builder
# Copyright (C) 2021~ https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021~ https://github.com/ophub/amlogic-s9xxx-openwrt
# Copyright (C) 2021~ https://downloads.openwrt.org/releases
# Copyright (C) 2023~ https://downloads.immortalwrt.org/releases
#
# Download from: https://downloads.openwrt.org/releases
#                https://downloads.immortalwrt.org/releases
#
# Documentation: https://openwrt.org/docs/guide-user/additional-software/imagebuilder
# Instructions:  Download OpenWrt firmware from the official OpenWrt,
#                Use Image Builder to add packages, lib, theme, app and i18n, etc.
#
# Command: ./config/imagebuilder/imagebuilder.sh <source:branch>
#          ./config/imagebuilder/imagebuilder.sh openwrt:21.02.3
#
#======================================== Functions list ========================================
#
# error_msg               : Output error message
# download_imagebuilder   : Downloading OpenWrt ImageBuilder
# adjust_settings         : Adjust related file settings
# custom_packages         : Add custom packages
# custom_config           : Add custom config
# custom_files            : Add custom files
# rebuild_firmware        : rebuild_firmware
#
#================================ Set make environment variables ================================
#
# Set default parameters
make_path="${PWD}"
openwrt_dir="openwrt"
imagebuilder_path="${make_path}/${openwrt_dir}"
custom_files_path="${make_path}/config/imagebuilder/files"
custom_config_file="${make_path}/config/imagebuilder/config"

# Set default parameters
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#================================================================================================

# Encountered a serious error, abort the script execution
error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# Downloading OpenWrt ImageBuilder
download_imagebuilder() {
    cd ${make_path}
    echo -e "${STEPS} Start downloading OpenWrt files..."

    # Determine the target system (Imagebuilder files naming has changed since 23.05.0)
    if [[ "${op_branch:0:2}" -ge "23" && "${op_branch:3:2}" -ge "05" ]]; then
        target_system="armsr/armv8"
        target_name="armsr-armv8"
        target_profile=""
    else
        target_system="armvirt/64"
        target_name="armvirt-64"
        target_profile="Default"
    fi

    # Downloading imagebuilder files
    download_file="https://downloads.${op_sourse}.org/releases/${op_branch}/targets/${target_system}/${op_sourse}-imagebuilder-${op_branch}-${target_name}.Linux-x86_64.tar.xz"
    wget -q ${download_file}
    [[ "${?}" -eq "0" ]] || error_msg "Wget download failed: [ ${download_file} ]"

    # Unzip and change the directory name
    tar -xJf *-imagebuilder-* && sync && rm -f *-imagebuilder-*.tar.xz
    mv -f *-imagebuilder-* ${openwrt_dir}

    sync && sleep 3
    echo -e "${INFO} [ ${make_path} ] directory status: $(ls . -l 2>/dev/null)"
}

# Adjust related files in the ImageBuilder directory
adjust_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adjusting .config file settings..."

    # For .config file
    if [[ -s ".config" ]]; then
        # Root filesystem archives
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        # Root filesystem images
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|# CONFIG_TARGET_ROOTFS_EXT4FS is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
    else
        error_msg "There is no .config file in the [ ${download_file} ]"
    fi

    # For other files
    # ......

    sync && sleep 3
    echo -e "${INFO} [ openwrt ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages
# If there is a custom package or ipk you would prefer to use create a [ packages ] directory,
# If one does not exist and place your custom ipk within this directory.
custom_packages() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom packages..."

    # Create a [ packages ] directory
    [[ -d "packages" ]] || mkdir packages

    # Download luci-app-amlogic
    amlogic_api="https://api.github.com/repos/ophub/luci-app-amlogic/releases"
    #
    amlogic_file="luci-app-amlogic"
    amlogic_file_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_name}.*.ipk" | head -n 1)"
    wget ${amlogic_file_down} -q -P packages
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_file} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_file} ] is downloaded successfully."
    #
    amlogic_i18n="luci-i18n-amlogic"
    amlogic_i18n_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_i18n}.*.ipk" | head -n 1)"
    wget ${amlogic_i18n_down} -q -P packages
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_i18n} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_i18n} ] is downloaded successfully."

    sync && sleep 3
    echo -e "${INFO} [ packages ] directory status: $(ls packages -l 2>/dev/null)"
}

# Add custom packages, lib, theme, app and i18n, etc.
custom_config() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom config..."

    config_list=""
    if [[ -s "${custom_config_file}" ]]; then
        config_list="$(cat ${custom_config_file} 2>/dev/null | grep -E "^CONFIG_PACKAGE_.*=y" | sed -e 's/CONFIG_PACKAGE_//g' -e 's/=y//g' -e 's/[ ][ ]*//g' | tr '\n' ' ')"
        echo -e "${INFO} Custom config list: \n$(echo "${config_list}" | tr ' ' '\n')"
    else
        echo -e "${INFO} No custom config was added."
    fi
}

# Add custom files
# The FILES variable allows custom configuration files to be included in images built with Image Builder.
# The [ files ] directory should be placed in the Image Builder root directory where you issue the make command.
custom_files() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom files..."

    if [[ -d "${custom_files_path}" ]]; then
        # Copy custom files
        [[ -d "files" ]] || mkdir -p files
        cp -rf ${custom_files_path}/* files
        
        sync && sleep 3
        echo -e "${INFO} [ files ] directory status: $(ls files -l 2>/dev/null)"
    else
        echo -e "${INFO} No customized files were added."
    fi
}

# Rebuild OpenWrt firmware
rebuild_firmware() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start building OpenWrt with Image Builder..."

    # Selecting default packages, lib, theme, app and i18n, etc.
    # sorting by https://build.moz.one
    my_packages="\
        acpid attr base-files bash bc blkid block-mount blockd bsdtar \
        btrfs-progs busybox bzip2 cgi-io chattr comgt comgt-ncm containerd coremark \
        coreutils coreutils-base64 coreutils-nohup coreutils-truncate curl docker \
        docker-compose dockerd dosfstools dumpe2fs e2freefrag e2fsprogs exfat-mkfs \
        f2fs-tools f2fsck fdisk gawk getopt gzip hostapd-common iconv iw iwinfo jq jshn \
        kmod-brcmfmac kmod-brcmutil kmod-cfg80211 kmod-mac80211 libjson-script \
        liblucihttp liblucihttp-lua libnetwork losetup lsattr lsblk lscpu mkf2fs \
        mount-utils openssl-util parted perl-http-date perlbase-file perlbase-getopt \
        perlbase-time perlbase-unicode perlbase-utf8 pigz ppp ppp-mod-pppoe \
        proto-bonding pv rename resize2fs runc subversion-client subversion-libs tar \
        tini ttyd tune2fs uclient-fetch uhttpd uhttpd-mod-ubus unzip uqmi usb-modeswitch \
        uuidgen wget-ssl whereis which wpad-basic wwan xfs-fsck xfs-mkfs xz \
        xz-utils ziptool zoneinfo-asia zoneinfo-core zstd \
        \
        luci luci-base luci-compat luci-i18n-base-en luci-i18n-base-zh-cn luci-lib-base  \
        luci-lib-docker luci-lib-ip luci-lib-ipkg luci-lib-jsonc luci-lib-nixio  \
        luci-mod-admin-full luci-mod-network luci-mod-status luci-mod-system  \
        luci-proto-3g luci-proto-bonding luci-proto-ipip luci-proto-ipv6 luci-proto-ncm  \
        luci-proto-openconnect luci-proto-ppp luci-proto-qmi luci-proto-relay  \
        \
        luci-app-amlogic luci-i18n-amlogic-zh-cn \
        \
        ${config_list} \
        "

    # Rebuild firmware
    make image PROFILE="${target_profile}" PACKAGES="${my_packages}" FILES="files"

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='KarnadiWrt'" >>package/base-files/files/etc/openwrt_release

# Modify default theme（FROM uci-theme-bootstrap CHANGE TO luci-theme-argon）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i '27 i\uci uci set luci.main.mediaurlbase="/luci-static-argon/"\nuci commit luci\n' package/emortal/default-settings/files/99-default-settings

# Modify default IP（FROM 192.168.1.1 CHANGE TO 192.168.31.4）
sed -i 's/192.168.1.1/11.11.1.1/g' package/base-files/files/bin/config_generate

# Set banner
rm -rf ./package/emortal/default-settings/files/openwrt_banner
svn export https://github.com/karnadii/KarnadiWrt/trunk/amlogic-s9xxx/common-files/rootfs/etc/banner package/emortal/default-settings/files/openwrt_banner

# Add the default password for the 'root' user（Change the empty password to 'password'）
sed -i 's/root::0:0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

# Set ssid
sed -i "s/ImmortalWrt/KarnadiWrt/g" package/kernel/mac80211/files/lib/wifi/mac80211.sh

# Set timezone
sed -i -e "s/CST-8/WIB-7/g" -e "s/Shanghai/Jakarta/g" package/emortal/default-settings/files/99-default-settings-chinese

# Set hostname
sed -i "s/ImmortalWrt/KarnadiWrt/g" package/base-files/files/bin/config_generate

# Set Interface
sed -i "9 i\uci set network.wana=interface\nuci set network.wana.proto='3g'\nuci set network.wana.device='/dev/ttyUSB1'\nuci set network.wana.service='LTE'\nuci set network.wana.apn='internet'\nuci set network.wana.ipv6='auto'\nuci set network.wanb=interface\nuci set network.wanb.proto='dhcp'\nuci set network.wanb.device='eth0.10'\nuci set network.wanc=interface\nuci set network.wanc.proto='dhcp'\nuci set network.wanc.device='usb0'\nuci set network.@device[0].ports='eth0' 'eth0.100' 'eth0.200' 'eth0.300'\nuci commit network" package/emortal/default-settings/files/99-default-settings
sed -i "23 i\uci add_list firewall.@zone[1].network='wana'\nuci add_list firewall.@zone[1].network='wanb'\nuci add_list firewall.@zone[1].network='wanc'\nuci commit firewall\n" package/emortal/default-settings/files/99-default-settings


# Set shell zsh
sed -i "s/\/bin\/ash/\/usr\/bin\/zsh/g" package/base-files/files/etc/passwd

# Set php7 max_size
# sed -i -e "s/upload_max_filesize = 2M/upload_max_filesize = 1024M/g" -e "s/post_max_size = 8M/post_max_size = 1024M/g" feeds/packages/lang/php7/files/php.ini

#=================================
# Utility App
#=================================
# Add luci-app-amlogic
svn co https://github.com/ophub/luci-app-amlogic/trunk/luci-app-amlogic package/luci-app-amlogic

# Add p7zip
svn co https://github.com/hubutui/p7zip-lede/trunk package/p7zip

# Add luci-app-tinyfilemanager
# svn co https://github.com/lynxnexy/luci-app-tinyfilemanager/trunk package/luci-app-tinyfilemanager
svn co https://github.com/helmiau/helmiwrt-packages/trunk/luci-app-tinyfm package/luci-app-tinyfm
svn co https://github.com/helmiau/helmiwrt-packages/trunk/luci-app-netmon package/luci-app-netmon
svn co https://github.com/helmiau/helmiwrt-packages/trunk/luci-app-openspeedtest package/luci-app-openspeedtest
svn co https://github.com/helmiau/helmiwrt-packages/trunk/badvpn package/badvpn
svn co https://github.com/helmiau/helmiwrt-packages/trunk/corkscrew package/corkscrew

rm -rf feeds/luci/applications/luci-app-filebrowser
svn co https://github.com/happy902/luci-app-filebrowser/trunk package/luci-app-filebrowser

# Set speedtest
mkdir -p files/bin
wget -qO- https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz | tar xOvz > files/bin/speedtest
chmod +x files/bin/speedtest

#================================
# Injek/Vpn/Bypass App
#================================
# Add luci-app-openclash
rm -rf feeds/luci/applications/luci-app-openclash
svn co https://github.com/vernesong/OpenClash/trunk/luci-app-openclash package/luci-app-openclash
pushd package/luci-app-openclash/tools/po2lmo
make && sudo make install
popd

# Set clash-core
mkdir -p files/etc/openclash/core
# VERNESONG_CORE=$(curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/Clash | grep /clash-linux-armv8 | awk -F '"' '{print $4}')
# VERNESONG_TUN=$(curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/TUN-Premium | grep /clash-linux-armv8 | awk -F '"' '{print $4}')
# VERNESONG_GAME=$(curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/TUN | grep /clash-linux-armv8 | awk -F '"' '{print $4}')
DREAMACRO_CORE=$(curl -sL https://api.github.com/repos/Dreamacro/clash/releases | grep /clash-linux-armv8 | awk -F '"' '{print $4}' | sed -n '1p')
DREAMACRO_TUN=$(curl -sL https://api.github.com/repos/Dreamacro/clash/releases/tags/premium | grep /clash-linux-armv8 | awk -F '"' '{print $4}')
META_CORE=$(curl -sL https://api.github.com/repos/MetaCubeX/Clash.Meta/releases | grep /Clash.Meta-linux-arm64-v | awk -F '"' '{print $4}' | sed -n '1p')
# wget -qO- $VERNESONG_CORE | tar xOvz > files/etc/openclash/core/clash_vernesong
# wget -qO- $VERNESONG_TUN | gunzip -c > files/etc/openclash/core/clash_tun_vernesong
# wget -qO- $VERNESONG_GAME | tar xOvz > files/etc/openclash/core/clash_game_vernesong
wget -qO- $DREAMACRO_CORE | gunzip -c > files/etc/openclash/core/clash
wget -qO- $DREAMACRO_TUN | gunzip -c > files/etc/openclash/core/clash_tun
wget -qO- $META_CORE | gunzip -c > files/etc/openclash/core/clash_meta
chmod +x files/etc/openclash/core/clash*

# Set v2ray-rules-dat
mkdir -p files/etc/openclash
curl -sL https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -o files/etc/openclash/GeoSite.dat
curl -sL https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -o files/etc/openclash/GeoIP.dat

#================================
# Monitoring
#================================
# User online cek

svn co https://github.com/haiibo/openwrt-packages/trunk/luci-app-onliner package/luci-app-onliner
svn co https://github.com/brvphoenix/luci-app-wrtbwmon/trunk/luci-app-wrtbwmon package/luci-app-wrtbwmon
svn co https://github.com/brvphoenix/wrtbwmon/trunk/wrtbwmon package/wrtbwmon
#cat
# rm -rf feeds/luci/applications/luci-app-netdata
sed -i 's/10.*/10.* 11.* 192.168.* 172.16.* 172.17.* 172.18.* 172.19.* 172.20.* 172.21.* 172.22.* 172.23.* 172.24.* 172.25.* 172.26.* 172.27.* 172.28.* 172.29.* 172.30.* 172.31.*/g' package/feeds/packages/netdata/files/netdata.conf
# git clone --depth 1 https://github.com/karnadii/luci-app-netdata feeds/luci/applications/luci-app-netdata

#================================
## Modem Tool
#================================
# Rooter Support untuk modem rakitan
svn co https://github.com/karnadii/rooter/trunk/package/rooter-builds/0protocols/luci-proto-3x package/luci-proto-3x
svn co https://github.com/karnadii/rooter/trunk/package/rooter-builds/0protocols/luci-proto-mbim package/luci-proto-mbim
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0drivers/rmbim package/rmbim
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0drivers/rqmi package/rqmi
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0basicsupport/ext-sms package/ext-sms
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0basicsupport/ext-buttons package/ext-buttons
svn co https://github.com/karnadii/rooter/trunk/package/rooter/ext-rooter-basic package/ext-rooter-basic
# Rooter splash
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0splash/status package/status
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0splash/splash package/splash
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0splash/ext-splashconfig package/ext-splashconfig
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0splash/ext-splash package/ext-splash
# Rooter Bandwith monitor
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0optionalapps/bwallocate package/bwallocate
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0optionalapps/bwmon package/bwmon
svn co https://github.com/karnadii/rooter/trunk/package/rooter/0optionalapps/ext-throttle package/ext-throttle

# disable banner from rooter
sudo chmod -x package/ext-rooter-basic/files/etc/init.d/bannerset
sed -i 's/luci-theme-openwrt-2020/luci-theme-argon/g' package/ext-rooter-basic/Makefile
# Add luci-app-3ginfo
# svn co https://github.com/lynxnexy/luci-app-3ginfo/trunk package/luci-app-3ginfo
# Add luci-app-atinout-mod
svn co https://github.com/lynxnexy/luci-app-atinout-mod/trunk package/luci-app-atinout-mod

# internet detector
svn co https://github.com/gSpotx2f/luci-app-internet-detector/trunk/luci-app-internet-detector package/luci-app-internet-detector
svn co https://github.com/gSpotx2f/luci-app-internet-detector/trunk/internet-detector package/internet-detector

# git clone https://github.com/tmn505/openwrt-dvb package/openwrt-dvb

# iStore
svn co https://github.com/linkease/istore-ui/trunk/app-store-ui package/app-store-ui
svn co https://github.com/linkease/istore/trunk/luci package/istore

#================================
## MISC
#================================
# Set oh-my-zsh
mkdir -p files/root
pushd files/root
git clone https://github.com/robbyrussell/oh-my-zsh ./.oh-my-zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ./.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ./.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ./.oh-my-zsh/custom/plugins/zsh-completions
cp ${GITHUB_WORKSPACE}/amlogic-s9xxx/common-files/patches/zsh/.zshrc .
cp ${GITHUB_WORKSPACE}/amlogic-s9xxx/common-files/patches/zsh/example.zsh ./.oh-my-zsh/custom/example.zsh
popd

    sync && sleep 3
    echo -e "${INFO} [ openwrt/bin/targets/*/* ] directory status: $(ls bin/targets/*/* -l 2>/dev/null)"
    echo -e "${SUCCESS} The rebuild is successful, the current path: [ ${PWD} ]"
}

# Show welcome message
echo -e "${STEPS} Welcome to Rebuild OpenWrt Using the Image Builder."
[[ -x "${0}" ]] || error_msg "Please give the script permission to run: [ chmod +x ${0} ]"
[[ -z "${1}" ]] && error_msg "Please specify the OpenWrt Branch, such as [ ${0} openwrt:22.03.3 ]"
[[ "${1}" =~ ^[a-z]{3,}:[0-9]+ ]] || error_msg "Incoming parameter format <source:branch>: openwrt:22.03.3"
op_sourse="${1%:*}"
op_branch="${1#*:}"
echo -e "${INFO} Rebuild path: [ ${PWD} ]"
echo -e "${INFO} Rebuild Source: [ ${op_sourse} ], Branch: [ ${op_branch} ]"
echo -e "${INFO} Server space usage before starting to compile: \n$(df -hT ${make_path}) \n"
#
# Perform related operations
download_imagebuilder
adjust_settings
custom_packages
custom_config
custom_files
rebuild_firmware
#
# Show server end information
echo -e "Server space usage after compilation: \n$(df -hT ${make_path}) \n"
# All process completed
wait
