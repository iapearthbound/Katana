#!/bin/bash
#
# ncBuildHelper.sh
#
#
# 2011 nubecoder
# http://www.nubecoder.com/
#

# define envvars
TARGET=$TARGET
KBUILD_BUILD_VERSION="SAMURAI.RYU"
LOCALVERSION=".SAMURAI.RYU"
CODENAME="RYU"
INSTALL_MOD_PATH="../stand-alone\ modules"
CROSS_COMPILE="/home/earthbound/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
UPDATE_SCRIPT="META-INF/com/google/android"

KERNEL_BUILD_DIR=$PWD/Kernel
MODULES_DIR=$PWD/modules
ANDROID_OUT_DIR=$PWD/Android/out/target/product/SPH-D700
ZIP_BUILD_DIR=$PWD/9.CM

KERNEL_PATH="$PWD/9.CM/zImage"
RECOVERY_INITRD="$PWD/recovery"
KERNEL_INITRD=$INITRAM

#prebuilt aosp from cm
#CROSS_COMPILE="/home/nubecoder/cm_android/system/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
#sammy recommended below
#CROSS_COMPILE="/home/nubecoder/android/kernel_dev/toolchains/arm-2009q3-68/bin/arm-none-eabi-"

# define defaults
BUILD_KERNEL=y
BUILD_MODULES=n
MODULE_ARGS=
CLEAN=n
DEFCONFIG=n
DISTCLEAN=n
PRODUCE_TAR=n
PRODUCE_ZIP=n
VERBOSE=n
WIFI_FLASH=n
WIRED_FLASH=n
USE_KEXEC=n
USE_MTD=n

# define vars
MKZIP='7z -mx9 -mmt=1 a "$OUTFILE" .'
THREADS=$(expr 1 + $(grep processor /proc/cpuinfo | wc -l))
VERSION=$(date +%m-%d-%Y)
DATE=$(date +%m.%d.%H.%M)
COMPDATE=$(date +%a.%b.%d.%Y.%I:%M:%S.%p)
ERROR_MSG=
TIME_START=
TIME_END=

# exports
export KBUILD_BUILD_VERSION

#source functions
source $PWD/functions

# main
while getopts ":bcCd:hj:km:Mtuvwz" flag
do
	case "$flag" in
	b)
		BUILD_KERNEL=y
		;;
	c)
		CLEAN=y
		;;
	d)
		DEFCONFIG=y
		TARGET="$OPTARG"
		;;
	h)
		SHOW_HELP
		;;
	j)
		THREADS=$OPTARG
		;;
	k)
		USE_KEXEC=y
		;;
	m)
		BUILD_MODULES=y
		MODULE_ARGS="$OPTARG"
		;;
	t)
		PRODUCE_TAR=y
		;;
	u)
		WIRED_FLASH=y
		;;
	v)
		VERBOSE=y
		;;
	w)
		WIFI_FLASH=y
		;;
	z)
		PRODUCE_ZIP=y
		;;
	C)
		TARGET="cyanogenmod_epicmtd"
		INITRAM="$PWD/initramfs_cm7"
		;;
	M)
		TARGET="victory_samuraimtd"
		;;
	B)
		TARGET="victory_samurai"
		;;
	*)
		ERROR_MSG="Error:: problem with option '$OPTARG'"
		SHOW_ERROR
		SHOW_HELP
		;;
	esac
done

# show current settings
SHOW_SETTINGS

# force MAKE_DEFCONFIG below
REMOVE_DOTCONFIG

if [ "$CLEAN" = "y" ] ; then
	MAKE_CLEAN
fi
if [ "$DISTCLEAN" = "y" ] ; then
	MAKE_DISTCLEAN
fi
if [ "$DEFCONFIG" = "y" -o ! -f "Kernel/.config" ] ; then
	MAKE_DEFCONFIG
fi
if [ "$BUILD_MODULES" = "y" ] ; then
	BUILD_MODULES
	if [ "$MODULE_ARGS" != "${MODULE_ARGS/c/}" ] ; then
		INSTALL_MODULES
		COPY_ARG="samurai"
		if [ $TARGET = "victory_samurai" ]; then
			COPY_ARG="samurai"
		elif [ $TARGET = "victory_modules" ]; then
			COPY_ARG="stand-alone"
		elif [ $TARGET = "victory_samuraicm" ]; then
			COPY_ARG="cyanogenmod"
		fi
		COPY_MODULES $COPY_ARG
	fi
	if [ "$MODULE_ARGS" != "${MODULE_ARGS/s/}" ] ; then
		STRIP_ARG="samurai"
		if [ $TARGET = "victory_samurai" ]; then
			STRIP_ARG="samurai"
		elif [ $TARGET = "victory_modules" ]; then
			STRIP_ARG="stand-alone"
		elif [ $TARGET = "victory_samuraicm" ]; then
			STRIP_ARG="cyanogenmod"
		fi
		STRIP_MODULES $STRIP_ARG
	fi
fi
if [ "$BUILD_KERNEL" = "y" ] ; then
	ZIMAGE_ARG="$LOCALVERSION"
	if [ $TARGET = "cyanogenmod_epicmtd" ]; then
		ZIMAGE_ARG="$LOCALVERSION.CM9.$DATE"
		echo "Building for Cyanogen Mod 7"
	elif [ $TARGET = "victory_samuraimtd" ]; then
		ZIMAGE_ARG="$LOCALVERSION.MTD.$DATE"
		echo "Building for TouchWiz MTD"
	elif [ $TARGET = "victory_samurai" ]; then
		ZIMAGE_ARG="$LOCALVERSION.BML.$DATE"
		echo "Building for TouchWiz BML"
	fi
	BUILD_ZIMAGE $ZIMAGE_ARG
	GENERATE_WARNINGS_FILE
	ZIMAGE_UPDATE
	if [ $TARGET = "cyanogenmod_epicmtd" ]; then
		pushd $ZIP_BUILD_DIR
			echo "Moving: modules"
			mkdir -p system/lib/modules
			find $MODULES_DIR -name '*.ko' -exec cp '{}' system/lib/modules/ \;
			$CROSS_COMPILE'strip' --strip-debug system/lib/modules/*
		popd
		if [ -f ./9.CM/zImage ] ; then
			echo "Removing: old zImage"
			rm -f ./9.CM/zImage
		fi
			cp ./Kernel/arch/arm/boot/zImage ./9.CM/zImage
		if [ -f ./1.MTD/boot.img ] ; then
			echo "Removing: old boot.img"
			rm -f ./9.CM/boot.img
		fi
			echo "Creating: Boot.img for Cyanogen Mod"
		./mkshbootimg.py $PWD/9.CM/boot.img $PWD/9.CM/zImage $PWD/9.CM/boot.cpio.gz $PWD/9.CM/recovery.cpio.gz
			echo "Updating: Updater-Script"
		sed -i '75 c\        ui_print("COMPILED ON: '$COMPDATE'");' $PWD/9.CM/$UPDATE_SCRIPT/updater-script
			echo "Creating: CWM Flashable .zip"
		pushd $PWD/9.CM
			test -e $CODENAME || mkdir $CODENAME
			zip -r $PWD/$CODENAME/$KBUILD_BUILD_VERSION.CM9.$DATE.zip META-INF system tools boot.img
		popd
	elif [ $TARGET = "victory_samuraimtd" ]; then
		if [ -f ./1.MTD/zImage ] ; then
			echo "Removing: old zImage"
			rm -f ./1.MTD/zImage
		fi
			cp ./Kernel/arch/arm/boot/zImage ./1.MTD/zImage
		if [ -f ./1.MTD/boot.img ] ; then
			echo "Removing: old boot.img"
			rm -f ./1.MTD/boot.img
		fi
			echo "Creating: Boot.img for TouchWiz.MTD"
		./mkshbootimg.py $PWD/1.MTD/boot.img $PWD/1.MTD/zImage $PWD/1.MTD/boot.cpio.gz $PWD/1.MTD/recovery.cpio.gz
			echo "Updating: Updater-Script"
		sed -i '73 c\        ui_print("COMPILED ON: '$DATE'");' $PWD/1.MTD/$UPDATE_SCRIPT/updater-script
			echo "Creating: CWM Flashable .zip"
		pushd $PWD/1.MTD
			zip -r $KBUILD_BUILD_VERSION.MTD.$DATE.zip data META-INF system tools boot.img
		popd
	fi

fi
if [ "$USE_MTD" = y ] ; then
	if [ -f ./1.MTD/zImage ] ; then
			echo "removing old zImage"
			rm -f ./1.MTD/zImage
	fi
	cp ./Kernel/arch/arm/boot/zImage ./1.MTD/zImage
	./create_boot.img_tw.sh tw
fi
if [ "$PRODUCE_TAR" = y ] ; then
	CREATE_TAR
fi
if [ "$PRODUCE_ZIP" = y ] ; then
	CREATE_ZIP
fi
if [ "$WIFI_FLASH" = y ] ; then
	if [ "$USE_KEXEC" = y ] ; then
		WIFI_KERNEL_LOAD_SCRIPT
	else
		WIFI_FLASH_SCRIPT
	fi
fi
if [ "$WIRED_FLASH" = y ] ; then
	if [ "$USE_KEXEC" = y ] ; then
		WIRED_KERNEL_LOAD_SCRIPT
	else
		WIRED_FLASH_SCRIPT
	fi
fi

# fix for module changing every build.
if [ "$DEFCONFIG" != "victory_modules" ] && [ "$BUILD_MODULES" = "y" ]; then
	git co -- initramfs_tw/lib/modules/dhd.ko
	git co -- initramfs_cm7/lib/modules/dhd.ko
fi

# show completed message
SHOW_COMPLETED

