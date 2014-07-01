#!/bin/bash
Version=4.0

# Tested on Ubuntu 12.04 & 14.04
sudo apt-get install flex bison libgmp3-dev libmpfr-dev libncurses5-dev libmpc-dev autoconf texinfo build-essential libftdi-dev libexpat1 libexpat1-dev zlib1g-dev automake libtool patch curl cvs subversion gawk python-dev gperf

########################### EDIT BELOW AS PER YOUR REQUIREMENT ################
echo "Cross build tool version : $Version"
TARGET=arm-none-eabi
#TARGET=arm-none-linux-gnueabi
#TARGET=arm-elf arm-unknown-elf  is obsolete, will be removed
#TARGET=arm-linux arm-unknown-linux  is obsolete, will be removed
TOP_DIR=$PWD
INSTALL_DIR=$TOP_DIR/package-${TARGET}
SOURCE_DIR=$TOP_DIR/src-${TARGET}
TAR_DIR=$TOP_DIR/tar
LOG_FILE=$TOP_DIR/build.log

BINUTILS_VERSION=2.24
GCC_VERSION=4.9.0
#NEWLIB_VERSION=2.1.0 # you get error: No rule to make target `../../../.././libgloss/arm/../config/default.mh', needed by `Makefile'.  Stop.
NEWLIB_VERSION=2.0.0
GDB_VERSION=7.7.1

FTP_BINUTILS="ftp://ftp.gnu.org/gnu/binutils"
FTP_NEWLIB="ftp://sourceware.org/pub/newlib"
FTP_GCC="ftp://mirrors.kernel.org/gnu/gcc"
FTP_GDB="ftp://ftp.gnu.org/gnu/gdb"

################################ DO NOT EDIT BELOW CODE ########################

my_echo() {
        echo "$1" | tee -a $LOG_FILE
}

is_cmd_failed_exit() {
        if [ "$?" != "0" ]
        then
                my_echo "Error: Command execution failed exiting..."
                exit 1
        fi
}

run_cmd() {
        my_echo "Executing CMD: $1"
        $1 &>> $LOG_FILE
        is_cmd_failed_exit
}

run_cmd "mkdir -p ${INSTALL_DIR}"
run_cmd "mkdir -p ${SOURCE_DIR}"
run_cmd "mkdir -p ${TAR_DIR}"
run_cmd "rm -f $LOG_FILE"

is_file_exits() {
	local file="$1"
	[[ -f "$file" ]] && return 0 || return 1
}

is_folder_exits() {
	local folder="$1"
	[[ -d "$folder" ]] && return 0 || return 1
}

untar_file() {
        local file=$1
        if ( is_file_exits "$file" )
        then
                folder=`echo $file | sed s/.tar.*//g`
                if ( is_folder_exits "$folder" )
                then
                        my_echo "File $file is already uncompressed"
                else
                        options=""
                        if [[ $file == *tar.bz2 ]]
                        then
                                options="jxvf"
                        elif [[ $file == *tar.gz ]]
                        then
                                options="zxvf"
                        else
                                my_echo "Error: Unknow file type to uncompress"
                                exit 1
                        fi
                        cmd="tar $options $file"
                        run_cmd "$cmd"
                fi

                if ( is_folder_exits "$SOURCE_DIR/$folder" )
                then
                        my_echo "Folder $folder is already copied"
                else
                        run_cmd "cp -rf $folder $SOURCE_DIR"
                fi
        else
                my_echo "Error: File $file does not exists skipping untar"
                exit 1
        fi
}

download_file() {
        local path="$1"
        local file="$2"
        if ( is_file_exits "$file" )
        then
                my_echo "File $file exists, skipping download"
        else
                #my_echo "File $path/$file downloading.."
                cmd="wget $path/$file"
                run_cmd "$cmd"

        fi
        untar_file "$file"
}

clean_build() {
        my_echo "Cleaning..."
        run_cmd "rm -rf $INSTALL_DIR"
        run_cmd "rm -rf ${SOURCE_DIR}/binutils-${BINUTILS_VERSION}"
        run_cmd "rm -rf ${SOURCE_DIR}/gcc-${GCC_VERSION}"
        run_cmd "rm -rf ${SOURCE_DIR}/newlib-${NEWLIB_VERSION}"
        run_cmd "rm -rf ${SOURCE_DIR}/gdb-${GDB_VERSION}"
}

if [ "$1" == "clean_build" ]
then
        clean_build
fi

run_cmd "cd ${TAR_DIR}"

download_file "${FTP_BINUTILS}/" "binutils-${BINUTILS_VERSION}.tar.bz2"
download_file "${FTP_NEWLIB}/" "newlib-${NEWLIB_VERSION}.tar.gz"
download_file "${FTP_GCC}/gcc-${GCC_VERSION}/" "gcc-${GCC_VERSION}.tar.bz2"
download_file "${FTP_GDB}/" "gdb-${GDB_VERSION}.tar.bz2"

run_cmd "cd ${SOURCE_DIR}"
my_echo "Building and installing binutils..."
run_cmd "cd binutils-${BINUTILS_VERSION}/"
run_cmd "./configure  --target=${TARGET} --prefix=${INSTALL_DIR} --enable-interwork --enable-multilib --disable-nls --disable-libssp --enable-plugins"
run_cmd "make all install"
run_cmd "cd .."

my_echo "Building gcc..."
run_cmd "cd gcc-${GCC_VERSION}/"
run_cmd "mkdir -p objdir"
run_cmd "cd objdir/"
run_cmd "../configure --target=${TARGET} --prefix=${INSTALL_DIR}/ --enable-interwork --enable-multilib --enable-languages="c" --with-newlib --with-headers=${SOURCE_DIR}/newlib-${NEWLIB_VERSION}/newlib/libc/include/ --disable-libssp --disable-nls --with-system-zlib --enable-threads"
run_cmd "make all-gcc install-gcc"
run_cmd "make install-lto-plugin" # To Fix - gcc: fatal error: -fuse-linker-plugin, but liblto_plugin.so not found
run_cmd "cd ../.."

run_cmd "cd ${INSTALL_DIR}/bin"
run_cmd "ln -f -s ${TARGET}-gcc ${TARGET}-cc"
run_cmd "cd -"

run_cmd "export PATH=${PATH}:${INSTALL_DIR}/bin"

my_echo "Building and installing newlib..."
run_cmd "cd newlib-${NEWLIB_VERSION}/"
run_cmd "./configure --target=${TARGET} --prefix=${INSTALL_DIR} --enable-interwork --enable-multilib --disable-libssp --disable-nls"
run_cmd "make all install"
run_cmd "cd .."

my_echo "Installing gcc..."
run_cmd "cd gcc-${GCC_VERSION}/objdir/"
run_cmd "make all install"
run_cmd "cd ../.."

my_echo "Building and installing gdb..."
run_cmd "cd gdb-${GDB_VERSION}/"
run_cmd "./configure --target=${TARGET} --prefix=${INSTALL_DIR}/ --enable-interwork --enable-multilib --disable-libssp --disable-nls"
run_cmd "make all install"

# Notes:
#-------
# –enable-interwork: Allows ARM and Thumb code to be used
# –enable-multilib: Build multible versions of some libs. E.g. one with soft float and one with hard
# –disable-nls: Tells gcc to only support American English output messages
# –disable-libssp: Don’t include stack smashing protection
# –with-system-zlib: Fixes the error: configure: error: Link tests are not allowed after
# Explanations:
#-------------
# arm-elf and arm-none-eabi just use two versions of the Arm ABI. The eabi toolchain uses a newer revision, but could also be called arm-elf-eabi, as it generates elf too.

# Thanks:
# -------
# FEW CMDS COPIED FROM: http://cu.rious.org/make/compiling-the-arm-cortex-m4-toolchain-yourself/
