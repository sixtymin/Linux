!
! SYS_SIZE is the number of clicks (16 bytes) to be loaded.
! 0x3000 is 0x30000 bytes = 196kB, more than enough for current
! versions of linux
!
! SYS_SIZE是要加载的内核的大小，单位是16字节，即0x3000=0x30000bytes 196KB
!
#include <linux/config.h>
SYSSIZE = DEF_SYSSIZE
!
!	bootsect.s		(C) 1991 Linus Torvalds
!	modified by Drew Eckhardt
!
! bootsect.s is loaded at 0x7c00 by the bios-startup routines, and moves
! iself out of the way to address 0x90000, and jumps there.
!
! It then loads 'setup' directly after itself (0x90200), and the system
! at 0x10000, using BIOS interrupts. 
!
! NOTE! currently system is at most 8*65536 bytes long. This should be no
! problem, even in the future. I want to keep it simple. This 512 kB
! kernel size should be enough, especially as this doesn't contain the
! buffer cache as in minix
!
! The loader has been made as simple as possible, and continuos
! read errors will result in a unbreakable loop. Reboot by hand. It
! loads pretty fast by getting whole sectors at a time whenever possible.
!
! bootsect.s 是由bios的启动例程加载到0x7c00地址处，然后将自己移动到
! 0x90000地址处并跳转过去继续执行
!
! 然后将 setup 直接加载到其后的内存中，即0x90200开始的内存，将system模块
! 加载到0x10000地址处，它们都是用BIOS中断完成
! 注意：当前的system有最长限制，即0x8000KB，这在当前和可见的未来都应该
! 没什么问题，512KB的内核大小应该足够
!
! 加载器已经做的尽可能简单了，持续的读取错误将会进入无限循环中，这时需要手动
! 重启。

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

SETUPLEN = 4			! nr of setup-sectors setup的长度
BOOTSEG  = 0x07c0		! original address of boot-sector 引导扇区加载的段地址
INITSEG  = DEF_INITSEG	! we move boot here - out of the way 引导扇区移动到这个段 0x9000
SETUPSEG = DEF_SETUPSEG	! setup starts here setup模块从这个段开始 0x9020
SYSSEG   = DEF_SYSSEG	! system loaded at 0x10000 (65536).
ENDSEG   = SYSSEG + SYSSIZE	! where to stop loading 停止加载的地方

! ROOT_DEV & SWAP_DEV are now written by "build".
ROOT_DEV = 0
SWAP_DEV = 0

entry start
start:
	mov	ax,#BOOTSEG  !0x07c0
	mov	ds,ax
	mov	ax,#INITSEG  !0x9000
	mov	es,ax
	mov	cx,#256
	sub	si,si
	sub	di,di
	rep
	movw
	jmpi	go,INITSEG

go:	mov	ax,cs		
	mov	dx,#0xfef4	! arbitrary value >>512 - disk parm size

	mov	ds,ax
	mov	es,ax
	;push	ax

	mov	ss,ax		! put stack at 0x9ff00 - 12.
	mov	sp,dx
/*
 *	Many BIOS's default disk parameter tables will not 
 *	recognize multi-sector reads beyond the maximum sector number
 *	specified in the default diskette parameter tables - this may
 *	mean 7 sectors in some cases.
 *
 *	Since single sector reads are slow and out of the question,
 *	we must take care of this by creating new parameter tables
 *	(for the first disk) in RAM.  We will set the maximum sector
 *	count to 18 - the most we will encounter on an HD 1.44.  
 *
 *	High doesn't hurt.  Low does.
 *
 *	Segments are as follows: ds=es=ss=cs - INITSEG,
 *		fs = 0, gs = parameter table segment
 *  许多BIOS默认的磁盘参数表不识别超过默认磁盘参数表中指定的多扇区读取
 *  在有些情况下这个默认值可能是7
 *  由于单扇区读取慢且容易出问题，因此这里创建新的参数表（第一块磁盘）
 *  将最大扇区数设置为 18，在HD 1.44上遇到最多的情况。
 */
	push #0
	pop	fs
	mov	bx,#0x78		! fs:bx is parameter table address
	seg fs
	lgs	si,(bx)			! gs:si is source

	mov	di,dx			! es:di is destination
	mov	cx,#6			! copy 12 bytes
	cld

	rep
	seg gs
	movw

	mov	di,dx
	movb 4(di),*18		! patch sector count

	seg fs
	mov	(bx),di
	seg fs
	mov	2(bx),es

	mov ax,cs ;pop	ax
	mov	fs,ax
	mov	gs,ax
	
	xor	ah,ah			! reset FDC 
	xor	dl,dl
	int 0x13	

! load the setup-sectors directly after the bootblock.
! Note that 'es' is already set up.
! 加载 setup 的四个扇区到引导块之后
load_setup:
	xor	dx, dx			! drive 0, head 0
	mov	cx,#0x0002		! sector 2, track 0
	mov	bx,#0x0200		! address = 512, in INITSEG
	mov	ax,#0x0200+SETUPLEN	! service 2, nr of sectors
	int	0x13			! int0x13-0x2 BIOS中断服务
	jnc	ok_load_setup	! ok - continue

	push	ax			! dump error code
	call	print_nl
	mov	bp, sp
	call	print_hex
	pop	ax	
	
	xor	dl, dl			! reset FDC
	xor	ah, ah
	int	0x13
	j	load_setup

ok_load_setup:
! Print some inane message
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov	cx,#22
	mov	bx,#0x0007		! page 0, attribute 7 (normal)
	mov	bp,#msg1
	mov	ax,#0x1301		! write string, move cursor
	int	0x10

! after that (everyting loaded), we jump to
! the setup-routine loaded directly after
! the bootblock:
idle:
	jmp idle
	#jmpi	0,SETUPSEG


print_nl:
	mov	ax, #0xe0d	! CR
	int	0x10
	mov	al, #0xa	! LF
	int	0x10
	ret

/*
 *	print_hex is for debugging purposes, and prints the word
 *	pointed to by ss:bp in hexadecmial.
*/

print_hex:
	mov	cx, #4		! 4 hex digits
	mov	dx, (bp)	! load word into dx
print_digit:
	rol	dx, #4		! rotate so that lowest 4 bits are used
	mov	ah, #0xe	
	mov	al, dl		! mask off so we have only next nibble
	and	al, #0xf
	add	al, #0x30	! convert to 0 based digit, '0'
	cmp	al, #0x39	! check for overflow
	jbe	good_digit
	add	al, #0x41 - 0x30 - 0xa 	! 'A' - '0' - 0xa

good_digit:
	int	0x10
	loop	print_digit
	ret


/*
 * This procedure turns off the floppy drive motor, so
 * that we enter the kernel in a known state, and
 * don't have to worry about it later.
 */
kill_motor:
	push dx
	mov dx,#0x3f2
	xor al, al
	outb
	pop dx
	ret

sectors:
	.word 0

msg1:
	.byte 13,10
	.ascii "IdleOs is Loading..."

.org 506
swap_dev:
	.word SWAP_DEV
root_dev:
	.word ROOT_DEV
boot_flag:
	.word 0xAA55

.text
endtext:
.data
enddata:
.bss
endbss:

