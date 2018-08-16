
bochs -q -f bochsrc

gdb ./Image
target remote localhost:1234
