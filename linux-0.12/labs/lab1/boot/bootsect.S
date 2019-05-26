! bootsect.s 是由bios的启动例程加载到0x7c00地址处，然后将自己移动到
! 0x90000地址处并跳转过去继续执行
!
! 然后将 setup 直接加载到其后的内存中，即0x90200开始的内存，将system模块
! 加载到0x10000地址处，它们都是用BIOS中断完成

! NOTE! These had better be the same as in bootsect.s!
#include <linux/config.h>
SYSSIZE=DEF_SYSSIZE

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
	jmpi	0,SETUPSEG


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

msg1:
	.byte 13,10
	.ascii "IdleOs is Loading..."

.org 510
boot_flag:
	.word 0xAA55

.text
endtext:
.data
enddata:
.bss
endbss:

