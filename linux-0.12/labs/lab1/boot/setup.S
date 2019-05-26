! setup 负责从BIOS中获取系统数据，将它们放到适当的内存位置
! setup和system都已经被引导扇区加载到内存中了
! 这段代码查询bios中关于内存，磁盘和其他的一些系统参数，将它们放到安全位置
! 0x90000-0x901FF，也即曾经引导扇区所在位置。在后面进入保护模式后会被系统
! 读取，再之后会被缓存块所复写。

! NOTE! These had better be the same as in bootsect.s!
#include <linux/config.h>

INITSEG  = DEF_INITSEG	! we move boot here - out of the way
SYSSEG   = DEF_SYSSEG	! system loaded at 0x10000 (65536).
SETUPSEG = DEF_SETUPSEG	! this is the current segment

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

entry start
start:

! ok, the read went well so we get current cursor position and save it for
! posterity. 
	mov	ax,#INITSEG	! this is done in bootsect already, but...
	mov	ds,ax

	mov ax,#SETUPSEG ! int 10h-13h 功能使用 es:bp 指向的字符串
	mov es,ax

	call print_nl
	call print_nl
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov bp, #msg1 
	mov cx, #19
	call print_str
	call print_nl

! Get memory size (extended mem, kB) 获取扩展内存，不包括低1M
	mov	ah,#0x88
	int	0x15
	mov	[2],ax

! Get cursor pos
	mov	[14],ax
	mov	ah,#0x03	! read cursor pos 读取屏幕光标位置
	xor	bh,bh
	int	0x10		! save it in known place, con_init fetches
	mov	[0],dx		! it from 0x90000.

! Get hd0 data      ! 获取磁盘参数，磁盘0和磁盘1，如果磁盘1不存在
	mov	ax,#0x0000  ! 则将获取的磁盘1的参数清空掉
	mov	ds,ax
	lds	si,[4*0x41]
	mov	ax,#INITSEG
	mov	es,ax
	mov	di,#0x0080
	mov	cx,#0x10
	rep
	movsb
	
! show infomations
	mov ax,#SETUPSEG ! int 10h-13h 功能使用 es:bp 指向的字符串
	mov es,ax

	mov bp, #posx
	mov cx, #5
	call print_str
	mov bp, #0
	call print_byte
	call print_nl

	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov bp, #posy
	mov cx, #5
	call print_str
	mov bp, #1
	call print_byte
	call print_nl

	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov bp, #memsize
	mov cx, #9
	call print_str
	mov bp, #2
	call print_hex
	call print_nl

	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov bp, #heads
	mov cx, #9
	call print_str
	mov bp, #0x82
	call print_hex
	call print_nl
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov bp, #cyls
	mov cx, #10
	call print_str
	mov bp, #0x80
	call print_hex
	call print_nl
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov bp, #sects
	mov cx, #11
	call print_str
	mov bp, #0x8e
	call print_hex
	call print_nl

die:
	jmp die


! ss:bp - the string pointer
! cx - str len
print_str:
	mov	bx,#0x0007		! page 0, attribute 7 (normal)
	mov	ax,#0x1301		! write string, move cursor
	int	0x10
	ret

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
print_byte:
	mov cx, #2
	mov dx, (bp)
	jmp print_digit

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

msg1:		.ascii	"Now we are in SETUP"

posx:        .ascii "x: 0x"
posy:        .ascii "y: 0x"

memsize:     .ascii "memsz: 0x"

heads:       .ascii "heads: 0x"
cyls:        .ascii "Cycles: 0x"
sects:       .ascii "Sectors: 0x"

.text
endtext:
.data
enddata:
.bss
endbss:
