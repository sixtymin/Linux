!
! SYS_SIZE is the number of clicks (16 bytes) to be loaded.
! 0x3000 is 0x30000 bytes = 196kB, more than enough for current
! versions of linux
! SYSSIZE是要夹在的数据的长度,单位是16字节,即加载0x30000bytes=196KB
! 这对于当前版本的Linux足够
SYSSIZE = 0x3000
!
!	bootsect.s		(C) 1991 Linus Torvalds
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
! bootsect.s 被BIOS中的启动函数加载到0x7c00处,然后将自己移动到0x90000处,
! 并且跳转过去继续执行。它然后将 setup 直接记载到它之后的内存中，即0x90200
! 然后将 system模块加载到0x10000处，其实这里system模块最大可为0x80000,比上面规定
! 的0x30000要小
.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

SETUPLEN = 4				! nr of setup-sectors
BOOTSEG  = 0x07c0			! original address of boot-sector 引导扇区的原始地址
INITSEG  = 0x9000			! we move boot here - out of the way 引导扇区被移动的位置
SETUPSEG = 0x9020			! setup starts here setup模块从这个地址开始
SYSSEG   = 0x1000			! system loaded at 0x10000 (65536). system加载起始位置
ENDSEG   = SYSSEG + SYSSIZE		! where to stop loading 暂停加载的地址

! ROOT_DEV:	0x000 - same type of floppy as boot. 这个值在build模块中会重置，这里可以不设置
!		0x301 - first partition on first drive etc 第一个磁盘设备的第一个分区中
ROOT_DEV = 0x306

entry _start
_start:
	mov	ax,#BOOTSEG
	mov	ds,ax
	mov	ax,#INITSEG
	mov	es,ax
	mov	cx,#256
	sub	si,si
	sub	di,di
	rep
	movw               ! 移动引导扇区到 0x90000地址出
	jmpi	go,INITSEG ! 跳转到新的地址处继续执行
go:	mov	ax,cs
	mov	ds,ax
	mov	es,ax      ! put stack at 0x9ff00.
	mov	ss,ax                   ! 设置栈段和栈指针
	mov	sp,#0xFF00		! arbitrary value >>512

! load the setup-sectors directly after the bootblock.
! Note that 'es' is already set up.
! 加载 setup 扇区到 0x90200地址开始的内存中
! es 寄存器已经设置为 0x9020
load_setup:
	mov	dx,#0x0000		! drive 0, head 0   dh 驱动器编号，dl 为磁头编号
	mov	cx,#0x0002		! sector 2, track 0 ch 为柱面号，cl 为扇区号
	mov	bx,#0x0200		! address = 512, in INITSEG  bx为内存中的加载地址
	mov	ax,#0x0200+SETUPLEN	! service 2, nr of sectors   al 为加载扇区数
	int	0x13			! read it   int 0x13-0x2 从磁盘上读取扇区到内存
	jnc	ok_load_setup		! ok - continue
	mov	dx,#0x0000
	mov	ax,#0x0000		! reset the diskette 复位磁盘，重读
	int	0x13
	j	load_setup

ok_load_setup:

! Get disk drive parameters, specifically nr of sectors/track

	mov	dl,#0x00                ! 0x13-0x08 获取驱动器参数
	mov	ax,#0x0800		! AH=8 is get drive parameters
	int	0x13
	mov	ch,#0x00
	seg cs
	mov	sectors,cx              ! cl 中为每个磁道的扇区数，放到 sectors 变量中
	mov	ax,#INITSEG
	mov	es,ax

! Print some inane message

	mov	ah,#0x03		! read cursor pos 读取光标位置
	xor	bh,bh
	int	0x10
	
	mov	cx,#24                  ! 在屏幕上输出一段文字，System is loading ...
	mov	bx,#0x0007		! page 0, attribute 7 (normal)
	mov	bp,#msg1
	mov	ax,#0x1301		! write string, move cursor
	int	0x10                    ! int 0x10 - 0x13

! ok, we've written the message, now
! we want to load the system (at 0x10000)

	mov	ax,#SYSSEG      ! 调用 read_it 函数，将system模块加载到0x10000 地址处
	mov	es,ax		! segment of 0x010000
	call	read_it
	call	kill_motor      ! 关闭马达

! After that we check which root-device to use. If the device is
! defined (!= 0), nothing is done and the given device is used.
! Otherwise, either /dev/PS0 (2,28) or /dev/at0 (2,8), depending
! on the number of sectors that the BIOS reports currently.
! 如果 root_dev 变量定义了，则不做处理，否则根据sectors的大小
! 判断是1.2Mb的软盘还是 1.44Mb的软盘（即根目录默认使用软盘）
	seg cs
	mov	ax,root_dev
	cmp	ax,#0
	jne	root_defined
	seg cs
	mov	bx,sectors
	mov	ax,#0x0208		! /dev/ps0 - 1.2Mb
	cmp	bx,#15
	je	root_defined
	mov	ax,#0x021c		! /dev/PS0 - 1.44Mb
	cmp	bx,#18
	je	root_defined
undef_root:
	jmp undef_root
root_defined:
	seg cs
	mov	root_dev,ax

! after that (everyting loaded), we jump to
! the setup-routine loaded directly after
! the bootblock: 设置完毕后，则跳转到 setup模块执行，即 0x90200地址处

	jmpi	0,SETUPSEG

! This routine loads the system at address 0x10000, making sure
! no 64kB boundaries are crossed. We try to load it as fast as
! possible, loading whole tracks whenever we can.
! 这个函数用于加载system模块到0x10000地址处，以64K 为边界进行加载
! 要尽快加载，如果可以则一次加载一条磁道
! in:	es - starting address segment (normally 0x1000)
!
! 定义三个变量，当前磁道 在读取的扇区号，磁头号，磁道号
! system 模块从 bootsect 和 setup 两个模块之后开始放置,所以在 1+SETUPLEN处
sread:	.word 1+SETUPLEN	! sectors read of current track 编号从1 开始
head:	.word 0			! current head
track:	.word 0			! current track

read_it:
	mov ax,es
	test ax,#0x0fff         ! 判断 es 必须是 64KB 边界对齐
die:	jne die			! es must be at 64kB boundary
	xor bx,bx		! bx is starting address within segment
rp_read:
	mov ax,es
	cmp ax,#ENDSEG		! have we loaded all yet? 判断是否已经全部加载
	jb ok1_read
	ret
ok1_read:
	seg cs
	mov ax,sectors          ! 首先读取第一条磁道中剩余扇区
	sub ax,sread            !
	mov cx,ax
	shl cx,#9               ! 乘以 每个扇区字节数
	add cx,bx               ! bx 保存了当前要写入地址值，ES：BX
	jnc ok2_read            ! 没有进位，即小于64K，则直接开始读
	je ok2_read
	xor ax,ax               ! 否则只读取当前64K中从BX开始到64K边界这部分内容
	sub ax,bx
	shr ax,#9
ok2_read:
	call read_track         ! 读取多个扇区，al 为读取的扇区数,ax为读取的扇区数
	mov cx,ax               ! 其他的变量位于read_it 开始的三个变量中
	add ax,sread            
	seg cs
	cmp ax,sectors          ! 判断是否已经读取完当前磁道
	jne ok3_read
	mov ax,#1               ! 一个磁道读完要调整磁头
	sub ax,head
	jne ok4_read
	inc track
ok4_read:
	mov head,ax             ! 将调整后的磁头写回变量
	xor ax,ax
ok3_read:
	mov sread,ax            ! 将当前磁道读取的扇区号写回
	shl cx,#9               ! 判断当前读取内容加上 bx是否超过64K,超过则需要进行处理
	add bx,cx
	jnc rp_read
	mov ax,es               ! 读取数据填满64K,则将 es 加 0x1000
	add ax,#0x1000
	mov es,ax
	xor bx,bx               ! 64K 从头开始计算
	jmp rp_read

read_track:
	push ax
	push bx
	push cx
	push dx
	mov dx,track            !ax是要读取的扇区数,其他数据源自起始处的三个变量
	mov cx,sread
	inc cx
	mov ch,dl
	mov dx,head
	mov dh,dl
	mov dl,#0
	and dx,#0x0100
	mov ah,#2
	int 0x13
	jc bad_rt
	pop dx
	pop cx
	pop bx
	pop ax
	ret
bad_rt:	mov ax,#0
	mov dx,#0
	int 0x13
	pop dx
	pop cx
	pop bx
	pop ax
	jmp read_track

!/*
! * This procedure turns off the floppy drive motor, so
! * that we enter the kernel in a known state, and
! * don't have to worry about it later.
! */
kill_motor:
	push dx
	mov dx,#0x3f2
	mov al,#0
	outb
	pop dx
	ret

sectors:
	.word 0

msg1:
	.byte 13,10
	.ascii "Loading system ..."
	.byte 13,10,13,10

.org 508
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
