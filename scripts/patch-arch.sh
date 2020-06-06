#!/bin/bash -e
#Modified version of patch-arch.sh in librealsense by Usaid Malik
SRC_VERSION_NAME=linux

## from
## http://stackoverflow.com/questions/9293887/in-bash-how-do-i-convert-a-space-delimited-string-into-an-array

FULL_NAME=$( uname -r | tr "-" "\n")
read -a VERSION <<< $FULL_NAME

SRC_VERSION_ID=${VERSION[0]}  ## e.g. : 4.5.6
SRC_VERSION_REL=${VERSION[1]} ## e.g. : 1
LINUX_TYPE=${VERSION[2]}      ## e.g. : ARCH

LINUX_BRANCH=archlinux-$SRC_VERSION_ID
KERNEL_NAME=linux-$SRC_VERSION_ID
PATCH_NAME=patch-$SRC_VERSION_ID

# ARCH Linux --  KERNEL_NAME=linux-$SRC_VERSION_ID-$SRC_VERSION_REL-$ARCH.pkg.tar.xz

mkdir kernel
cd kernel

## Get the kernel
wget -q https://www.kernel.org/pub/linux/kernel/v5.x/$KERNEL_NAME.tar.xz
wget -q https://www.kernel.org/pub/linux/kernel/v5.x/$PATCH_NAME.xz
#wget https://www.kernel.org/pub/linux/kernel/v5.x/$KERNEL_NAME.sign # <-- .sign no longer is applied to $PATCH_NAME anymore
#Removed since it doesn't seem to be used anyway
echo "Extract the kernel"
tar xf $KERNEL_NAME.tar.xz

cd $KERNEL_NAME

## Get the patch

echo "RealSense patch..."

# Apply our RealSense specific patch
patch -p1 < ../../realsense-camera-formats.patch

# Prepare to compile modules

## Get the config
# zcat /proc/config.gz > .config  ## Not the good one ?

cp /usr/lib/modules/`uname -r`/build/.config .
cp /usr/lib/modules/`uname -r`/build/Module.symvers .

echo "Prepare the build"

make scripts oldconfig modules_prepare

# Compile UVC modules
echo "Beginning compilation of uvc..."
#make modules
KBASE=`pwd`
cd drivers/media/usb/uvc
cp $KBASE/Module.symvers .
make -C $KBASE M=$KBASE/drivers/media/usb/uvc/ modules

# Copy to sane location
#sudo cp $KBASE/drivers/media/usb/uvc/uvcvideo.ko ~/$LINUX_BRANCH-uvcvideo.ko
cd ../../../../../

cp $KBASE/drivers/media/usb/uvc/uvcvideo.ko ../uvcvideo.ko

# Unload existing module if installed
echo "Unloading existing uvcvideo driver..."
sudo modprobe -r uvcvideo
echo "Unloaded existing driver"

cd ..

## Not sure yet about deleting and copying...

# save the existing module
echo "Save existing module"
MODULE_NAME=/lib/modules/`uname -r`/kernel/drivers/media/usb/uvc/uvcvideo.ko

#Saving backup of the module. To restore it, just do mv uvcvideo.ko.xz.backup uvcvideo.ko.xz
if [ -e $MODULE_NAME ]; then
    echo "Saving backup of .ko"
    sudo cp $MODULE_NAME $MODULE_NAME.backup
    sudo rm $MODULE_NAME

    sudo cp uvcvideo.ko $MODULE_NAME
fi

if [ -e $MODULE_NAME.xz ]; then
    echo "Saving backup of .ko.xz"
    sudo cp $MODULE_NAME.xz $MODULE_NAME.xz.backup
    sudo rm $MODULE_NAME.xz

    # compress
    xz uvcvideo.ko
    sudo cp uvcvideo.ko.xz $MODULE_NAME
fi

if [ -e $MODULE_NAME.gz ]; then
    echo "Saving backup of .gz"
    sudo cp $MODULE_NAME.gz $MODULE_NAME.gz.backup
    sudo rm $MODULE_NAME.gz

    # compress
    gzip uvcvideo.ko
    sudo cp uvcvideo.ko.gz $MODULE_NAME.gz
fi

# Copy out to module directory

echo "Copy out to module directory"
#If an error happens on this line, your uvcvideo module is currently corrupted (you can check by running Cheese)
#Restore the uvcvideo module from the backup if you can't figure out patching and just want to return things back to how it was
sudo modprobe uvcvideo

rm -rf kernel

echo "Script has completed. Please consult the installation guide for further instruction."