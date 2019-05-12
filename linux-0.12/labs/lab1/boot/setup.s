!
!	setup.s		(C) 1991 Linus Torvalds
!
! setup.s is responsible for getting the system data from the BIOS,
! and putting them into the appropriate places in system memory.
! both setup.s and system has been loaded by the bootblock.
!
! This code asks the bios for memory/disk/other parameters, and
! puts them in a "safe" place: 0x90000-0x901FF, ie where the
! boot-block used to be. It is then up to the protected mode
! system to read them from there before the area is overwritten
! for buffer-blocks.
!

! NOTE! These had better be the same as in bootsect.s!

INITSEG  = 0x9000	! we move boot here - out of the way
SYSSEG   = 0x1000	! system loaded at 0x10000 (65536).
SETUPSEG = 0x9020	! this is the current segment

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
	mov	ah,#0x03	! read cursor pos
	xor	bh,bh
	int	0x10		! save it in known place, con_init fetches
	mov	[0],dx		! it from 0x90000.

! Get memory size (extended mem, kB)
	mov	ah,#0x88
	int	0x15
	mov	[2],ax

! Get video-card data:

	mov	ah,#0x0f
	int	0x10
	mov	[4],bx		! bh = display page
	mov	[6],ax		! al = video mode, ah = window width

! check for EGA/VGA and some config parameters

	mov	ah,#0x12
	mov	bl,#0x10
	int	0x10
	mov	[8],ax
	mov	[10],bx
	mov	[12],cx

! Get hd0 data
	mov	ax,#0x0000
	mov	ds,ax
	lds	si,[4*0x41]
	mov	ax,#INITSEG
	mov	es,ax
	mov	di,#0x0080
	mov	cx,#0x10
	rep
	movsb

	mov ax, #SETUPSEG
	mov ds, ax
	mov es, ax

	mov cx,#22
	mov bp,#msg_hello
	call print_str
	call print_ln 
	call print_ln 
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	
	mov cx,#14
	mov bp,#mem
	call print_str
	push dx
	mov bp, #2
	call print_hex
	pop dx
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	mov cx, #2
	mov bp,#mem_unit
	call print_str
	call print_ln
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10

	mov cx, #15
	mov bp, #disk_head
	call print_str
	push dx
	mov bp, #0x0082
	call print_hex
	pop dx
	call print_ln
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	mov cx, #14
	mov bp, #disk_cider
	call print_str
	push dx
	mov bp, #0x0080
	call print_hex
	pop dx
	call print_ln
	mov	ah,#0x03		! read cursor pos
	xor	bh,bh
	int	0x10
	mov cx, #23
	mov bp, #disk_sect
	call print_str
	mov bp, #0x008E
	call print_hex
	
	hlt

! cx output char
! bp straddr
print_str:
	mov	bx,#0x0007		! page 0, attribute 7 (normal)
	mov	ax,#0x1301		! write string, move cursor
	int	0x10
	ret

! bp word to print
print_hex:
	mov bl, #0x07
	mov cx, #4
	mov dx, (bp)
print_char:
	rol dx, 4
	mov ax, #0x0E0F
	and al, dl
	add al, #0x30
	cmp al, #0x3A
	jl out_char
	add al, #0x7
   out_char:
   	int 0x10
	loop print_char
	ret
	
print_ln:
	mov	ax,#0x0e0d
	int	0x10
	mov     al,#0xa
	int	0x10
	ret

msg_hello:
	.ascii "Now we are in Setup!!!"

mem:
	.ascii "Extern Mem: 0x"
mem_unit:
	.ascii "Kb"

disk_head:
	.ascii "disk header: 0x"
disk_cider:
	.ascii "disk cider: 0x"
disk_sect:
	.ascii "disk sect per cider: 0x"

.text
endtext:
.data
enddata:
.bss
endbss:
