.intel_syntax noprefix

.data

wrong_num_args_error: .ascii "Expected one argument\n"
.set wrong_num_args_error_len, 22

read_fail_error: .ascii "Could not read file\n"
.set read_fail_error_len, 21

mmap_fail_error: .ascii "Could not allocate memory\n"
.set mmap_fail_error_len, 26

.set read_buffer_size, 1024
.set max_executable_len, 1048576
.set process_mem_amount, 1048576

.text

.globl _start
.p2align	4
_start:

    cmp QWORD PTR [rsp], 2
    jne wrong_num_args

    mov rax, 2 # open file
    mov rdi, [rsp + 16] # from argv[1]
    mov rsi, 0 # no flags, readonly
    mov rdx, 0 # no mode
    syscall

    mov r12, rax # the file

    sub rsp, read_buffer_size # alloc a buffer for file reads
    mov rbx, rsp # store the buffer

    mov rax, 9 # mmap
    mov rdi, 0 # anywhere
    mov rsi, max_executable_len
    mov rdx, 7 # PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 34 # MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1 # no file
    mov r9, 0 # no offset
    syscall

    cmp rax, -1 # mmap returns -1 on fail
    je mmap_fail

    mov r14, rax # store the executable
    mov r13, rax # current location in executable

    jmp loop_read

    # in the executable:
    # * rbx is the current position in memory
    # * rax is temporary storage

lt_char:

    # dec rbx
    # 0x48 0xff 0xcb
    mov BYTE PTR [r13], 0x48
    mov BYTE PTR [r13 + 1], 0xff
    mov BYTE PTR [r13 + 2], 0xcb
    add r13, 3

    jmp subloop_check

gt_char:

    # inc rbx
    # 0x48 0xff 0xc3
    mov BYTE PTR [r13], 0x48
    mov BYTE PTR [r13 + 1], 0xff
    mov BYTE PTR [r13 + 2], 0xc3
    add r13, 3

    jmp subloop_check

plus_char:

    # inc BYTE PTR [rbx]
    # 0xfe 0x03
    mov BYTE PTR [r13], 0xfe
    mov BYTE PTR [r13 + 1], 0x03
    add r13, 2

    jmp subloop_check

minus_char:

    # dec BYTE PTR [rbx]
    # 0xfe 0x0b
    mov BYTE PTR [r13], 0xfe
    mov BYTE PTR [r13 + 1], 0x0b
    add r13, 2

    jmp subloop_check

square_open_char:

    push r13
    # mov rax, <ADDRESS>
    mov BYTE PTR [r13], 0x48
    mov BYTE PTR [r13 + 1], 0xb8
    # address remains temporarily unfilled
    # jmp rax
    mov BYTE PTR [r13 + 10], 0xff
    mov BYTE PTR [r13 + 11], 0xe0
    add r13, 12

    jmp subloop_check

square_close_char:

    pop rdx # the start of the loop

    # first, set the jump address at the loops start
    mov [rdx + 2], r13

    # mov al, BYTE PTR [rbx]
    mov BYTE PTR [r13], 0x8a
    mov BYTE PTR [r13 + 1], 0x03
    # test al, al
    mov BYTE PTR [r13 + 2], 0x84
    mov BYTE PTR [r13 + 3], 0xc0
    # jz rel8 12
    mov BYTE PTR [r13 + 4], 0x74
    mov BYTE PTR [r13 + 5], 12
    # mov rax, <ADDRESS>
    # the address we jump to is rdx+12
    add rdx, 12
    mov BYTE PTR [r13 + 6], 0x48
    mov BYTE PTR [r13 + 7], 0xb8
    mov [r13 + 8], rdx
    # jmp rax
    mov BYTE PTR [r13 + 16], 0xff
    mov BYTE PTR [r13 + 17], 0xe0
    add r13, 18

    jmp subloop_check

comma_char:

    mov BYTE PTR [r13], 0x48
    mov BYTE PTR [r13 + 1], 0xb8
    lea rdx, do_input
    mov [r13 + 2], rdx
    mov BYTE PTR [r13 + 10], 0xff
    mov BYTE PTR [r13 + 11], 0xd0
    add r13, 12

    jmp subloop_check

period_char:

    mov BYTE PTR [r13], 0x48
    mov BYTE PTR [r13 + 1], 0xb8
    lea rdx, do_output
    mov [r13 + 2], rdx
    mov BYTE PTR [r13 + 10], 0xff
    mov BYTE PTR [r13 + 11], 0xd0
    add r13, 12

    jmp subloop_check

loop_process:

    mov rdi, 0 # position in the buffer

    jmp subloop_check

subloop_char:

    mov dl, [rbx + rdi] # load the char
    inc rdi # move to the next

    cmp dl, 60
    je lt_char

    cmp dl, 62
    je gt_char

    cmp dl, 43
    je plus_char

    cmp dl, 45
    je minus_char

    cmp dl, 91
    je square_open_char

    cmp dl, 93
    je square_close_char

    cmp dl, 44
    je comma_char

    cmp dl, 46
    je period_char 

    # if we got here, this is a comment char

subloop_check:

    cmp rdi, rax # are we at the end of the buffer
    jl subloop_char # if not, continue looping

loop_read:

    mov rax, 0 # read
    mov rdi, r12 # from the file
    mov rsi, rbx # into the buffer
    mov rdx, read_buffer_size
    syscall

    cmp rax, 0
    jg loop_process
    jl read_fail

    mov rax, 3 # close
    mov rdi, r12 # the file we opened
    syscall

    # add a ret to the end of executable
    # ret
    mov BYTE PTR [r13], 0xc3

    mov rax, 10 # protect
    mov rdi, r14 # the executable's memory
    mov rsi, max_executable_len # of the executable's length
    mov rdx, 5 # PROT_READ | PROT_EXEC
    syscall
    
    add rsp, read_buffer_size # dealloc the file buffer

    mov rax, 9 # mmap
    mov rdi, 0 # anywhere
    mov rsi, process_mem_amount
    mov rdx, 3 # PROT_READ | PROT_WRITE
    mov r10, 34 # MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1 # no file
    mov r9, 0 # no offset
    syscall

    cmp rax, -1 # mmap returns -1 on fail
    je mmap_fail

    # the executable expects the memory in rbx
    mov rbx, rax
    
    # the start of the executable is in r14
    call r14

    mov rax, 60 # exit program
    mov rdi, 0 # with status code zero
    syscall

wrong_num_args:

    mov rax, 1 # write
    mov rdi, 2 # to stderr
    lea rsi, wrong_num_args_error
    mov rdx, wrong_num_args_error_len
    syscall

    mov rax, 60 # exit program
    mov rdi, 1 # with status code one
    syscall

read_fail:

    mov rax, 1 # write
    mov rdi, 2 # to stderr
    lea rsi, read_fail_error
    mov rdx, read_fail_error_len
    syscall

    mov rax, 60 # exit program
    mov rdi, 1 # with status code one
    syscall

mmap_fail:

    mov rax, 1 # write
    mov rdi, 2 # to stderr
    lea rsi, mmap_fail_error
    mov rdx, mmap_fail_error_len
    syscall

    mov rax, 60 # exit program
    mov rdi, 1 # with status code one
    syscall

do_input:

    mov rax, 0 # read
    mov rdi, 0 # from stdin
    mov rsi, rbx # into the position from the callee
    mov rdx, 1 # one byte
    syscall

    # on EOF we leave the cell unchanged

    ret

do_output:

    mov rax, 1 # write
    mov rdi, 1 # to stdout
    mov rsi, rbx # from the position from the callee
    mov rdx, 1 # one byte
    syscall

    ret
