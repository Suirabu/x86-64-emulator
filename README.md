# x86-64 Emulator

## About

I began working on this as a way to explore the workings of Linux executables
and the x86-64 instruction set. The capabilities of this emulator are very 
limited and I currently have no intentions to expand them any further.

## Build

You will need a copy of the [Zig compiler](https://ziglang.org/download)
(version 0.11.0 or later) to build this project.

```sh
git clone https://github.com/Suirabu/x86-64-emulator
cd x86-64-emulator
zig build -Doptimize=ReleaseSafe
```

## Try It Yourself!

```txt
$ cat hello-world.asm
bits 64
global _start

section .data
    msg db "Hello, world!", 10, 0
    msg_len equ $-msg

section .text
_start:
    ; write(stdout, msg, msg_len)
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, msg_len
    syscall

    ; exit(0)
    mov rax, 60
    mov rdi, 0
    syscall
$ nasm -f elf64 -o hello-world.o hello-world.asm
$ ld -o hello-world hello-world.o
$ ./zig-out/bin/x86-64-emulator hello-world
Hello, world!
```

## License

See [LICENSE](LICENSE)
