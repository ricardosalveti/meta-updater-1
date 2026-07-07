DISTROOVERRIDES .= "${@bb.utils.contains('DISTRO_FEATURES', 'sota', ':sota', '', d)}"

SOTA_CLIENT_PROV ??= "aktualizr-shared-prov"
SOTA_DEPLOY_CREDENTIALS ?= "1"
SOTA_HARDWARE_ID ??= "${MACHINE}"

IMAGE_CLASSES += " image_types_ostree image_types_ota image_repo_manifest"
IMAGE_INSTALL:append:sota = " aktualizr aktualizr-info ${SOTA_CLIENT_PROV} \
                              ostree os-release ostree-kernel ostree-initramfs \
                              ${@'ostree-devicetrees' if oe.types.boolean('${OSTREE_DEPLOY_DEVICETREE}') else ''}"

IMAGE_FSTYPES += "${@bb.utils.contains('DISTRO_FEATURES', 'sota', 'ostreepush garagesign garagecheck ota-ext4', ' ', d)}"
IMAGE_FSTYPES += "${@bb.utils.contains('BUILD_OSTREE_TARBALL', '1', 'ostree.tar.bz2', ' ', d)}"
IMAGE_FSTYPES += "${@bb.utils.contains('BUILD_OSTREE_REPO_TARBALL', '1', 'ostreecommit.tar.xz', ' ', d)}"
IMAGE_FSTYPES += "${@bb.utils.contains('BUILD_OTA_TARBALL', '1', 'ota.tar.xz', ' ', d)}"

WKS_FILE:sota ?= "sdimage-sota.wks"

EXTRA_IMAGEDEPENDS:append:sota = " parted-native mtools-native dosfstools-native"

INITRAMFS_FSTYPES ?= "${@oe.utils.ifelse(d.getVar('OSTREE_BOOTLOADER') == 'u-boot', 'cpio.gz.u-boot', 'cpio.gz')}"

# Please redefine OSTREE_REPO in order to have a persistent OSTree repo
OSTREE_REPO ?= "${DEPLOY_DIR_IMAGE}/ostree_repo"
OSTREE_BRANCHNAME ?= "${SOTA_HARDWARE_ID}"
OSTREE_OSNAME ?= "nodistro"
OSTREE_BOOTLOADER ??= 'u-boot'
OSTREE_BOOT_PARTITION ??= "/boot"
OSTREE_KERNEL ??= "${KERNEL_IMAGETYPE}"
OSTREE_KERNEL_ARGS_COMMON ??= "root=LABEL=otaroot rootfstype=ext4"
OSTREE_KERNEL_ARGS ??= "${OSTREE_KERNEL_ARGS_COMMON}"

# When "1", seal the kernel command line inside the UKI so the whole boot
# artifact can be signed and verified by UEFI Secure Boot; the loader entry
# then carries no options line. The ostree deployment is selected by the
# fixed ostree=/ostree/root.BOOTID argument through a symlink ostree
# maintains at deploy time (see the sealed UKI ostree patch). When "0",
# kernel arguments stay in the loader entry, handled by ostree. Machine
# classes using an EFI/UKI boot flow opt in (e.g. sota_qcom.bbclass).
OSTREE_SEALED_UKI ??= "0"

# The boot id is baked (signed) into the UKI command line as the
# ostree=/ostree/root.BOOTID deployment selector, so it must be distinct for any
# two deployments that could coexist on a device. It cannot be derived from the
# boot artifact contents (the UKI cannot embed a hash of itself), and it must be
# stable across the do_uki/do_image_ostree tasks. Tie it to the release-unique
# BUILD_ID (in CI, the pipeline run id; locally, local-${DATETIME}): each OTA
# release then gets a distinct UKI, so a rootfs-only update — where the UKI
# inputs (kernel/initramfs/cmdline) are otherwise identical and would sstate-share
# a boot id — still yields a distinct, individually selectable deployment.
# Redeploying the byte-identical image (same BUILD_ID) is the only remaining
# collision and is caught by the ostree publisher with a clear error.
OSTREE_SEALED_BOOT_ID ?= "${BUILD_ID}"
# BUILD_ID falls back to local-${DATETIME}, which would otherwise leak the wall-clock
# time into do_uki's signature and make it non-deterministic. Exclude DATETIME from the
# signature (as os-release.bb does for its own BUILD_ID use): the unexpanded value is
# constant, so do_uki stays deterministic, while a changed release-unique BUILD_ID value
# still retriggers it.
BUILD_ID[vardepsexclude] = "DATETIME"

# Only consumed on machines that enable the uki image class; for the
# non-sealed SOTA UKI flow the command line must stay empty (ostree owns the
# loader entry options).
UKI_CMDLINE = "${@oe.utils.conditional('OSTREE_SEALED_UKI', '1', '${OSTREE_KERNEL_ARGS} ostree=/ostree/root.${OSTREE_SEALED_BOOT_ID}', '', d)}"

# Ship the boot id next to the deployed UKI so image_types_ostree.bbclass
# commits it into the tree as usr/lib/modules/KVER/ostree-boot-id.
python do_uki:append() {
    if d.getVar('OSTREE_SEALED_UKI') == '1':
        path = os.path.join(d.getVar('DEPLOY_DIR_IMAGE'), d.getVar('UKI_FILENAME') + '.boot-id')
        with open(path, 'w') as f:
            f.write(d.getVar('OSTREE_SEALED_BOOT_ID') + '\n')
}
OSTREE_DEPLOY_DEVICETREE ??= "0"
OSTREE_DEVICETREE ??= "${KERNEL_DEVICETREE}"
OSTREE_MULTI_DEVICETREE_SUPPORT ??= "0"
OSTREE_SYSROOT_READONLY ??= "0"
OSTREE_REPO_CONFIG ?= ""
OSTREE_OTA_REPO_CONFIG ?= ""
OSTREE_EFI_SIZE ?= "524288"
OSTREE_WKS_EFI_SIZE ?= "--size ${OSTREE_EFI_SIZE}K"

INITRAMFS_IMAGE ?= "initramfs-ostree-image"

GARAGE_SIGN_TOOL ?= "garage-sign"
GARAGE_SIGN_REPO ?= "${DEPLOY_DIR_IMAGE}/garage_sign_repo"
GARAGE_SIGN_KEYNAME ?= "garage-key"
GARAGE_TARGET_NAME ?= "${OSTREE_BRANCHNAME}"
GARAGE_TARGET_VERSION ?= ""
GARAGE_TARGET_URL ?= ""
GARAGE_TARGET_EXPIRES ?= ""
GARAGE_TARGET_EXPIRE_AFTER ?= ""
GARAGE_CUSTOMIZE_TARGET ?= ""

SOTA_MACHINE ??= "none"
SOTA_MACHINE:rpi ?= "raspberrypi"
SOTA_MACHINE:qcom ?= "qcom"
SOTA_MACHINE:porter ?= "porter"
SOTA_MACHINE:m3ulcb = "m3ulcb"
SOTA_MACHINE:intel-corei7-64 ?= "intel"
SOTA_MACHINE:qemux86-64 ?= "qemux86-64"
SOTA_MACHINE:am335x-evm ?= "am335x-evm-wifi"
SOTA_MACHINE:freedom-u540 ?= "freedom-u540"

SOTA_OVERRIDES_BLACKLIST = "ostree ota"
SOTA_REQUIRED_VARIABLES = "OSTREE_REPO OSTREE_BRANCHNAME OSTREE_OSNAME OSTREE_BOOTLOADER OSTREE_BOOT_PARTITION GARAGE_SIGN_REPO GARAGE_TARGET_NAME"

# Postinst script in fontcache class will create cache
# at this path during do_rootfs
FONTCONFIG_CACHE_DIR:sota = "${libdir}/fontconfig/cache"

inherit sota_sanity sota_${SOTA_MACHINE}

# required by ostree-kernel-initramfs
kernel_do_deploy:append() {
    install -m 0644 ${STAGING_KERNEL_BUILDDIR}/kernel-abiversion $deployDir
}
