import pexpect
import sys
import os
import subprocess
import time

def run(cmd):
    print("Running:", cmd)
    subprocess.check_call(cmd, shell=True)

# 1. Download OpenBSD arm64 install image
if not os.path.exists("install75.img"):
    run("curl -sO https://cdn.openbsd.org/pub/OpenBSD/7.5/arm64/install75.img")

if not os.path.exists("obsd.qcow2"):
    run("qemu-img create -f qcow2 obsd.qcow2 10G")
    run("cp /usr/share/qemu-efi-aarch64/QEMU_EFI.fd efi.fd")
    run("dd if=/dev/zero of=vars.fd bs=1M count=64")

    print("--- STARTING INSTALLATION ---")
    qemu_cmd = (
        "qemu-system-aarch64 -M virt -cpu cortex-a57 -m 2G -smp 4 "
        "-drive if=pflash,format=raw,file=efi.fd,readonly=on "
        "-drive if=pflash,format=raw,file=vars.fd "
        "-drive file=install75.img,format=raw,if=virtio "
        "-drive file=obsd.qcow2,format=qcow2,if=virtio "
        "-netdev user,id=net0 -device virtio-net-device,netdev=net0 "
        "-nographic"
    )
    
    child = pexpect.spawn(qemu_cmd, encoding='utf-8')
    child.logfile = sys.stdout

    child.expect(r'\(I\)nstall, \(U\)pgrade, \(A\)utoinstall or \(S\)hell\?', timeout=120)
    child.sendline('I')
    child.expect(r'Choose your keyboard layout', timeout=10)
    child.sendline('default')
    child.expect(r'System hostname\?', timeout=10)
    child.sendline('obsd')
    child.expect(r'Network interfaces.*', timeout=10)
    child.sendline('vio0')
    child.expect(r'IPv4 address for vio0.*', timeout=10)
    child.sendline('dhcp')
    child.expect(r'IPv6 address for vio0.*', timeout=10)
    child.sendline('none')
    child.expect(r'Which network interface do you wish to configure\?.*', timeout=10)
    child.sendline('done')
    child.expect(r'Password for root account\?', timeout=10)
    child.sendline('root')
    child.expect(r'Password for root account.*', timeout=10)
    child.sendline('root')
    child.expect(r'Start sshd\(8\) by default\?.*', timeout=10)
    child.sendline('yes')
    child.expect(r'Do you expect to run the X Window System\?', timeout=10)
    child.sendline('no')
    child.expect(r'Setup a user.*', timeout=10)
    child.sendline('no')
    child.expect(r'Allow root ssh login.*', timeout=10)
    child.sendline('yes')
    child.expect(r'What timezone are you in\?.*', timeout=10)
    child.sendline('UTC')
    child.expect(r'Which disk is the root disk\?', timeout=10)
    child.sendline('sd1') # sd1 is obsd.qcow2
    child.expect(r'Use \(W\)hole disk MBR, whole disk \(G\)PT or \(E\)dit\?', timeout=10)
    child.sendline('W')
    child.expect(r'Use \(A\)uto layout, \(E\)dit auto layout, or create \(C\)ustom layout\?', timeout=10)
    child.sendline('A')
    child.expect(r'Location of sets\?', timeout=60)
    child.sendline('disk')
    child.expect(r'Is the disk partition already mounted\?', timeout=10)
    child.sendline('no')
    child.expect(r'Which disk contains the install media\?', timeout=10)
    child.sendline('sd0')
    child.expect(r'Which sd0 partition has the install sets\?', timeout=10)
    child.sendline('a')
    child.expect(r'Pathname to the sets\?', timeout=10)
    child.sendline('')
    child.expect(r'Set name\(s\)\?', timeout=10)
    child.sendline('-x*')
    child.expect(r'Set name\(s\)\?', timeout=10)
    child.sendline('-game*')
    child.expect(r'Set name\(s\)\?', timeout=10)
    child.sendline('done')
    child.expect(r'Directory does not contain SHA256.sig.*Continue without verification\?', timeout=10)
    child.sendline('yes')
    child.expect(r'Location of sets\?', timeout=600)
    child.sendline('done')
    child.expect(r'Time appears wrong.*', timeout=10)
    child.sendline('yes')
    child.expect(r'CONGRATULATIONS', timeout=120)
    child.sendline('halt')
    child.expect(r'System halted', timeout=60)
    child.close()
    print("--- INSTALLATION COMPLETE ---")

# 2. Package source code into an ISO
print("--- PACKAGING SOURCE ---")
run("genisoimage -R -o /tmp/src.iso /src")

# 3. Create a FAT32 output image
print("--- CREATING OUTPUT IMAGE ---")
run("dd if=/dev/zero of=/tmp/output.img bs=1M count=100")
run("mkfs.vfat /tmp/output.img")

# 4. Boot into OpenBSD and compile
print("--- COMPILING KERNEL ---")
qemu_cmd = (
    "qemu-system-aarch64 -M virt -cpu cortex-a57 -m 2G -smp 4 "
    "-drive if=pflash,format=raw,file=efi.fd,readonly=on "
    "-drive if=pflash,format=raw,file=vars.fd "
    "-drive file=obsd.qcow2,format=qcow2,if=virtio "
    "-drive file=/tmp/src.iso,format=raw,if=virtio,media=cdrom "
    "-drive file=/tmp/output.img,format=raw,if=virtio "
    "-netdev user,id=net0 -device virtio-net-device,netdev=net0 "
    "-nographic"
)

child = pexpect.spawn(qemu_cmd, encoding='utf-8')
child.logfile = sys.stdout

child.expect(r'login:', timeout=120)
child.sendline('root')
child.expect(r'Password:', timeout=10)
child.sendline('root')

child.expect(r'# ', timeout=10)
child.sendline('mount -t cd9660 /dev/cd0a /mnt')
child.expect(r'# ', timeout=10)
child.sendline('cp -R /mnt /usr/src/sys')
child.expect(r'# ', timeout=60)
child.sendline('cd /usr/src/sys/arch/arm64/conf')
child.expect(r'# ', timeout=10)
child.sendline('config GLMT3000')
child.expect(r'# ', timeout=10)
child.sendline('cd ../compile/GLMT3000')
child.expect(r'# ', timeout=10)
child.sendline('make -j4')
child.expect(r'# ', timeout=1800) # Give it 30 mins to compile!

child.sendline('mount -t msdos /dev/sd1i /mnt2 || mount -t msdos /dev/sd1c /mnt2 || mount -t msdos /dev/sd1a /mnt2')
child.expect(r'# ', timeout=10)
child.sendline('cp bsd /mnt2/')
child.expect(r'# ', timeout=10)
child.sendline('umount /mnt2')
child.expect(r'# ', timeout=10)
child.sendline('halt')
child.expect(r'System halted', timeout=60)
child.close()

# 5. Extract output
print("--- EXTRACTING KERNEL ---")
run("mcopy -i /tmp/output.img ::bsd /out/bsd")
print("SUCCESS: Kernel is available at /out/bsd")
