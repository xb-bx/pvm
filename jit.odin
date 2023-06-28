package pvm
import "core:fmt"
import "core:mem/virtual"
import "core:strings"
import "core:os"
import "core:mem"
import "core:runtime"
import "x86asm"
import "core:sys/unix"
jit :: proc(using vm: ^VM) -> Maybe(JitError) {
    using x86asm  
    asmm := initasm()
    fn := &fnpointer
    fnaddr := transmute(u64)(fn)
    mov(&asmm, Reg64.Rax, fnaddr)
    jmp_reg(&asmm, Reg64.Rax)
    for _, module in modules {
        for func in module.functions {
            func.jmp_body = alloc_executable(16)                
            for b, index in asmm.bytes {
                func.jmp_body.base[index] = b
            }
        }
    }
    for _, module in modules {
        for func in module.functions {

            err := jit_function(func, vm) 
            if err != nil {
                return err
            }
        }
    }
    return nil
}
TypeStack :: struct {
    types: [dynamic]^Type,
    count: int,    
}
stack_push :: proc(using stack: ^TypeStack, type: ^Type) {
    append(&types, type)
    count += 1
}
stack_pop :: proc(using stack: ^TypeStack) -> ^Type {
    res := types[count - 1]
    remove_range(&types, count-1, count)
    count -= 1
    return res
}
CodeBlock :: struct {
    start: int,
    instructions: []Instruction,
    stack: TypeStack,
    visited: bool,
}
stack_equals :: proc(t1: TypeStack, t2: TypeStack) -> bool {
    if t1.count != t2.count {
        return false
    }
    for i in 0..<t1.count {
        if !type_equals(t1.types[i], t2.types[i]) {
            return false
        }
    }
    return true
}

jit_prepare_locals_systemv_abi :: proc(using function: ^Function, asmm: ^x86asm.Assembler) -> ([]int, i64) {
    using x86asm  
    res := make([]int, len(args) + len(locals))
    args_classes := make([]bool, len(args)) // false -> register, true -> stack
    avail_regs := 6
    if get_type_size(retType) > 16 {
        avail_regs = 5
    }
    stack_offsets := make([]int, len(args))
    for arg, i in args {
        if get_type_size(arg) > 16 || avail_regs == 0 {
            args_classes[i] = true
        }
        else {
            if get_type_size(arg) <= 8 {
                args_classes[i] = false 
                avail_regs -= 1
            }
            else if avail_regs >= 2 {
                args_classes[i] = false
                avail_regs -= 2
            }
            else {
                args_classes[i] = true
            }
        }
    }
    i := len(args) - 1
    stack_offset := 16
    for i >= 0 {
        if !args_classes[i] {
            i -= 1 
            continue
        }
        arg := args[i]
        stack_offsets[i] = stack_offset
        if get_type_size(arg) <= 8 {
            stack_offset += 8
        }
        else {
            stack_offset += get_type_size(arg)
        }
        i -= 1 
    }
    offset := 0
    if get_type_size(retType) > 16 {
        offset = -16
    }
    for arg, index in args {
        typesize := get_type_size(arg)

        if typesize > 16 || args_classes[index] {
            res[index] = stack_offsets[index]    
        }
        else if typesize <= 8 {
            typesize = 8
            offset -= typesize
            res[index] = offset 
        }
        else if typesize > 8 && typesize <= 16 {
            typesize += 8 - (typesize % 8);
            offset -= typesize
            res[index] = offset 
        }

    }
    for local, index in locals {
        typesize := get_type_size(local)
        if typesize < 8 {
            typesize = 8
        }
        if typesize > 8 {
            typesize += 8 - (typesize % 8) // allign by 8 byte boundary
        }
        offset -= typesize
        res[len(args) + index] = offset 
    }
    offset -= 16 + (offset % 16) // allign by 16 byte boundary
    mov(asmm, Reg64.R10, Reg64.Rsp)
    mov(asmm, Reg64.Rax, 8)
    sub(asmm, Reg64.R10, Reg64.Rax)
    mov(asmm, Reg64.Rax, transmute(u64)offset)
    add(asmm, Reg64.Rsp, Reg64.Rax)
    cond := create_label(asmm)
    body := create_label(asmm)
    jmp(asmm, cond)
    set_label(asmm, body)
    
    mov(asmm, Reg64.Rax, 0)
    mov_to(asmm, Reg64.R10, Reg64.Rax)
    mov(asmm, Reg64.Rax, 8)
    sub(asmm, Reg64.R10, Reg64.Rax)
    set_label(asmm, cond)
    cmp(asmm, Reg64.R10, Reg64.Rsp)
    jge(asmm, body)

    regindex := 0
    registers := (&[]Reg64{Reg64.Rdi, Reg64.Rsi, Reg64.Rdx, Reg64.Rcx, Reg64.R8, Reg64.R9 });
    if get_type_size(retType) > 16 {
        registers = (&[]Reg64{Reg64.Rsi, Reg64.Rdx, Reg64.Rcx, Reg64.R8, Reg64.R9 });
    }
    for arg, index in args {
        if args_classes[index] {
            continue
        }
        append(&asmm.bytes, 0x90)
        append(&asmm.bytes, 0x90)
        if get_type_size(arg) > 8 && get_type_size(arg) <= 16 {
            mov_to(asmm, Reg64.Rbp, registers[regindex], cast(i32)res[index])
            mov_to(asmm, Reg64.Rbp, registers[regindex+1], cast(i32)res[index] + 8)
            regindex+=2
        }
        else if get_type_size(arg) <= 8 && regindex < len(registers) {
            mov_to(asmm, Reg64.Rbp, registers[regindex], cast(i32)res[index])
            regindex += 1
        }

    }
    return res, cast(i64)offset
}
jit_prepare_locals_win_abi :: proc(using function: ^Function, asmm: ^x86asm.Assembler) -> ([]int, i64) {
    using x86asm  
    res := make([]int, len(args) + len(locals))
    offset := 0
    for arg, index in args {
        typesize := get_type_size(arg)
        if typesize < 8 {
            typesize = 8
        }
        if typesize > 8 {
            typesize += 8 - (typesize % 8);
        }
        offset -= typesize
        res[index] = offset 
    }
    for local, index in locals {
        typesize := get_type_size(local)
        if typesize < 8 {
            typesize = 8
        }
        if typesize > 8 {
            typesize += 8 - (typesize % 8) // allign by 8 byte boundary
        }
        offset -= typesize
        res[len(args) + index] = offset 
    }
    offset -= 16 + (offset % 16) // allign by 16 byte boundary
    mov(asmm, Reg64.R10, Reg64.Rsp)
    mov(asmm, Reg64.Rax, 8)
    sub(asmm, Reg64.R10, Reg64.Rax)
    mov(asmm, Reg64.Rax, transmute(u64)offset)
    add(asmm, Reg64.Rsp, Reg64.Rax)
    cond := create_label(asmm)
    body := create_label(asmm)
    jmp(asmm, cond)
    set_label(asmm, body)
    
    mov(asmm, Reg64.Rax, 0)
    mov_to(asmm, Reg64.R10, Reg64.Rax)
    mov(asmm, Reg64.Rax, 8)
    sub(asmm, Reg64.R10, Reg64.Rax)
    set_label(asmm, cond)
    cmp(asmm, Reg64.R10, Reg64.Rsp)
    jge(asmm, body)

    registers := (&[4]Reg64{Reg64.Rcx, Reg64.Rdx, Reg64.R8, Reg64.R9})[:]
    for arg, index in args {
        if get_type_size(function.retType) > 8 {
            registers = (&[3]Reg64{Reg64.Rdx, Reg64.R8, Reg64.R9})[:]
        }
        append(&asmm.bytes, 0x90)
        append(&asmm.bytes, 0x90)
        if (index > 3) || (index > 2 && len(registers) == 3) {
            stack_index := (index > 2 && len(registers) == 3) ? index - 3: index -4 
            mov_from(asmm, Reg64.Rdx, Reg64.Rbp, cast(i32)(48 + stack_index * 8))
            if get_type_size(arg) > 8 {
                jit_memcpy(asmm, get_type_size(arg), Reg64.Rdx, Reg64.Rbp, 0, cast(i32)res[index])
            }
            else {
                mov_to(asmm, Reg64.Rbp, Reg64.Rdx, cast(i32)res[index])
            }
        }  
        else {
            mov_to(asmm, Reg64.Rbp, registers[index], cast(i32)res[index])
        }
    }
    return res, cast(i64)offset
}
jit_prepare_locals :: proc(using function: ^Function, asmm: ^x86asm.Assembler) -> ([]int, i64) {
    when os.OS == runtime.Odin_OS_Type.Windows {
        return jit_prepare_locals_win_abi(function, asmm)
    }
    else when os.OS == runtime.Odin_OS_Type.Linux {
        return jit_prepare_locals_systemv_abi(function, asmm)
    }
    panic("UNSUPORTED ABI")
}
get_stack_size :: proc(stack: ^TypeStack) -> i32 {
    size := 0
    for t in stack.types {
        tsize := get_type_size(t)

        if tsize % 8 != 0 {
            size += 8 - (tsize % 8) + tsize
        }
        else {
            size += tsize
        }
    }
    return cast(i32)size
}
jit_compile_conv :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack, convtype: ^Type) {
    using x86asm
    mov_from(asmm, Reg64.Rax, Reg64.R10, -get_stack_size(stack))    
    from := stack_pop(stack)
    stack_push(stack, convtype)
    switch get_type_size(from) {
        case 1:
            switch get_type_size(convtype) {
                case 1:
                    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
                case 2:
                    if type_is_signedint(convtype) && type_is_signedint(from) {
                        movsx(asmm, Reg16.Ax, Reg8.Al)
                    }
                    else {
                        movzx(asmm, Reg16.Ax, Reg8.Al)
                    }
                    mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack))
                case 4:
                    if type_is_signedint(convtype) && type_is_signedint(from) {
                        movsx(asmm, Reg32.Eax, Reg8.Al)
                    }
                    else {
                        movzx(asmm, Reg32.Eax, Reg8.Al)
                    }
                    mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack))
                case 8:
                    if type_is_signedint(convtype) && type_is_signedint(from) {
                        movsx(asmm, Reg64.Rax, Reg8.Al)
                    }
                    else {
                        movzx(asmm, Reg32.Eax, Reg8.Al)
                    }
                    mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
                    
            }
        case 2:
            switch get_type_size(convtype) {
                case 1:
                    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
                case 2:
                    mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack))
                case 4:
                    if type_is_signedint(convtype) && type_is_signedint(from) {
                        movsx(asmm, Reg32.Eax, Reg16.Ax)
                    }
                    else {
                        movzx(asmm, Reg32.Eax, Reg16.Ax)
                    }
                    mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack))
                case 8:
                    if type_is_signedint(convtype) && type_is_signedint(from) {
                        movsx(asmm, Reg64.Rax, Reg16.Ax)
                    }
                    else {
                        movzx(asmm, Reg32.Eax, Reg16.Ax)
                    }
                    mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
        }
        case 4:
            switch get_type_size(convtype) {
                case 1:
                    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
                case 2:
                    mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack))
                case 4:
                    mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack))
                case 8:
                    if type_is_signedint(convtype) && type_is_signedint(from) {
                        movsx(asmm, Reg64.Rcx, Reg32.Eax)
                    }
                    else {
                        mov(asmm, Reg32.Ecx, Reg32.Eax)
                    }
                    mov_to(asmm, Reg64.R10, Reg64.Rcx, -get_stack_size(stack))
        }
        case 8:
            switch get_type_size(convtype) {
                case 1:
                    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
                case 2:
                    mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack))
                case 4:
                    mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack))
                case 8:
                    mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
        }
    }
        
}
jit_compile_sub :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack) {
    using x86asm  
    size := get_stack_size(stack)
    stack_pop(stack) 
    t := stack_pop(stack) 
    switch t.(PrimitiveType) {
        case .I64, .U64:
            stack_push(stack, t)
            mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -size + 8)
            sub(asmm, Reg64.Rax, Reg64.Rcx)
            mov_to(asmm, Reg64.R10, Reg64.Rax, -size + 8)
        case .I32, .U32:
            stack_push(stack, t)
            mov_from(asmm, Reg32.Eax, Reg64.R10, -size)
            mov_from(asmm, Reg32.Ecx, Reg64.R10, -size + 8)
            sub(asmm, Reg32.Eax, Reg32.Ecx)
            mov_to(asmm, Reg64.R10, Reg32.Eax, -size + 8)
        case .I16, .U16:
            stack_push(stack, t)
            mov_from(asmm, Reg16.Ax, Reg64.R10, -size)
            mov_from(asmm, Reg16.Cx, Reg64.R10, -size + 8)
            sub(asmm, Reg16.Ax, Reg16.Cx)
            mov_to(asmm, Reg64.R10, Reg16.Ax, -size + 8)
        case .I8, .U8:
            stack_push(stack, t)
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            mov_from(asmm, Reg8.Cl, Reg64.R10, -size + 8)
            sub(asmm, Reg8.Al, Reg8.Cl)
            mov_to(asmm, Reg64.R10, Reg8.Al, -size + 8)
        case .F64, .F32, .Boolean, .Void, .Any, .Char, .String:
            panic("UNIMPLEMENTED")
    }
}
jit_compile_add :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack) {
    using x86asm  
    size := get_stack_size(stack)
    stack_pop(stack) 
    t := stack_pop(stack) 
    switch t.(PrimitiveType) {
        case .I64, .U64:
            stack_push(stack, t)
            mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -size + 8)
            add(asmm, Reg64.Rax, Reg64.Rcx)
            mov_to(asmm, Reg64.R10, Reg64.Rax, -size + 8)
        case .I32, .U32:
            stack_push(stack, t)
            mov_from(asmm, Reg32.Eax, Reg64.R10, -size)
            mov_from(asmm, Reg32.Ecx, Reg64.R10, -size + 8)
            add(asmm, Reg32.Eax, Reg32.Ecx)
            mov_to(asmm, Reg64.R10, Reg32.Eax, -size + 8)
        case .I16, .U16:
            stack_push(stack, t)
            mov_from(asmm, Reg16.Ax, Reg64.R10, -size)
            mov_from(asmm, Reg16.Cx, Reg64.R10, -size + 8)
            add(asmm, Reg16.Ax, Reg16.Cx)
            mov_to(asmm, Reg64.R10, Reg16.Ax, -size + 8)
        case .I8, .U8:
            stack_push(stack, t)
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            mov_from(asmm, Reg8.Cl, Reg64.R10, -size + 8)
            add(asmm, Reg8.Al, Reg8.Cl)
            mov_to(asmm, Reg64.R10, Reg8.Al, -size + 8)
        case .F64, .F32, .Boolean, .Void, .Any, .Char, .String:
            panic("UNIMPLEMENTED")
    }
}
jit_null_check :: proc(asmm: ^x86asm.Assembler, ptr: x86asm.Reg64, t1: x86asm.Reg64 = x86asm.Reg64.Rax) {
    using x86asm
    mov(asmm, Reg64.Rax, 0)
    cmp(asmm, ptr, Reg64.Rax)
    notnull := create_label(asmm)
    jne(asmm, notnull)
    mov(asmm, Reg64.Rax, transmute(u64)nullref) 
    call_reg(asmm, Reg64.Rax)
    set_label(asmm, notnull)
}
out_of_bounds :: proc "c" (i: i64) {
    context = ctx
    for len(stacktrace) > 0 {
        frame :StackFrame= {}
        stack_trace_pop(&frame)
        fmt.printf("at %v.%v\n", frame.fn.module.name, frame.fn.name)
    }
    panic(fmt.aprint("INDEX", i, "OUT OF BOUNDS\n"))
}
jit_memcpy :: proc(asmm: ^x86asm.Assembler, memsize: int, from: x86asm.Reg64, to: x86asm.Reg64, from_offset: i32, to_offset: i32) {
    using x86asm  
    size := memsize
    switch size {
        case 8:
            mov_from(asmm, Reg64.Rax, from, from_offset) 
            mov_to(asmm, to, Reg64.Rax, to_offset) 
        case 4:
            mov_from(asmm, Reg32.Eax, from, from_offset) 
            mov_to(asmm, to, Reg32.Eax, to_offset) 
        case 2:
            mov_from(asmm, Reg16.Ax, from, from_offset) 
            mov_to(asmm, to, Reg16.Ax, to_offset) 
        case 1:
            mov_from(asmm, Reg8.Al, from, from_offset) 
            mov_to(asmm, to, Reg8.Al, to_offset) 
        case:
            qwords := size / 8
            off := from_offset 
            stackoff := to_offset 
            for i in 0..<qwords {
                mov_from(asmm, Reg64.Rax, from, off) 
                mov_to(asmm, to, Reg64.Rax, stackoff) 
                off += 8
                stackoff += 8
            }
            size -= qwords * 8
            if size >= 4 {
                mov_from(asmm, Reg32.Eax, from, off) 
                mov_to(asmm, to, Reg32.Eax, stackoff) 
                off += 4
                stackoff += 4
                size -= 4
            }
            if size >= 2 {
                mov_from(asmm, Reg16.Ax, from, off) 
                mov_to(asmm, to, Reg16.Ax, stackoff) 
                off += 2
                stackoff += 2
                size -= 2
            }
            if size >= 1 {
                mov_from(asmm, Reg8.Al, from, off) 
                mov_to(asmm, to, Reg8.Al, stackoff) 
                off += 1
                stackoff += 1
                size -= 1
            }
    }
} 
jit_compile_pushlocal :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack, offset: i32, type: ^Type) {
    using x86asm  
    stack_push(stack, type)
    size := get_type_size(type)
    jit_memcpy(asmm, size, Reg64.Rbp, Reg64.R10, offset, -get_stack_size(stack))
//     switch size {
//         case 8:
//             mov_from(asmm, Reg64.Rax, Reg64.Rbp, offset) 
//             mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack)) 
//         case 4:
//             mov_from(asmm, Reg32.Eax, Reg64.Rbp, offset) 
//             mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack)) 
//         case 2:
//             mov_from(asmm, Reg16.Ax, Reg64.Rbp, offset) 
//             mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack)) 
//         case 1:
//             mov_from(asmm, Reg8.Al, Reg64.Rbp, offset) 
//             mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack)) 
//         case:
//             qwords := size / 8
//             off := offset
//             stackoff := -get_stack_size(stack)
//             for i in 0..<qwords {
//                 mov_from(asmm, Reg64.Rax, Reg64.Rbp, off) 
//                 mov_to(asmm, Reg64.R10, Reg64.Rax, stackoff) 
//                 off += 8
//                 stackoff += 8
//             }
//             size -= qwords * 8
//             if size >= 4 {
//                 mov_from(asmm, Reg32.Eax, Reg64.Rbp, off) 
//                 mov_to(asmm, Reg64.R10, Reg32.Eax, stackoff) 
//                 off += 4
//                 stackoff += 4
//                 size -= 4
//             }
//             if size >= 2 {
//                 mov_from(asmm, Reg16.Ax, Reg64.Rbp, off) 
//                 mov_to(asmm, Reg64.R10, Reg16.Ax, stackoff) 
//                 off += 2
//                 stackoff += 2
//                 size -= 2
//             }
//             if size >= 1 {
//                 mov_from(asmm, Reg8.Al, Reg64.Rbp, off) 
//                 mov_to(asmm, Reg64.R10, Reg8.Al, stackoff) 
//                 off += 1
//                 stackoff += 1
//                 size -= 1
//             }
//     }
}
jit_compile_setlocal :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack, offset: i32, type: ^Type) {
    using x86asm
//     if get_type_size(type) == 8 {
//         mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
//         mov_to(asmm, Reg64.Rbp, Reg64.Rax, offset)
//     }
//     else {
//         panic("UNIMPLEMENTED")
//     }
    size := get_type_size(type)
    jit_memcpy(asmm, size, Reg64.R10, Reg64.Rbp, -get_stack_size(stack), offset)
//     switch size {
//         case 8:
//             mov_from(asmm, Reg64.Rax, Reg64.R10, -get_stack_size(stack)) 
//             mov_to(asmm, Reg64.Rbp, Reg64.Rax, offset) 
//         case 4:
//             mov_from(asmm, Reg32.Eax, Reg64.R10, -get_stack_size(stack)) 
//             mov_to(asmm, Reg64.Rbp, Reg32.Eax, offset) 
//         case 2:
//             mov_from(asmm, Reg16.Ax, Reg64.R10, -get_stack_size(stack)) 
//             mov_to(asmm, Reg64.Rbp, Reg16.Ax, offset) 
//         case 1:
//             mov_from(asmm, Reg8.Al, Reg64.R10, -get_stack_size(stack)) 
//             mov_to(asmm, Reg64.Rbp, Reg8.Al, offset) 
//         case:
//             qwords := size / 8
//             off := offset
//             stackoff := -get_stack_size(stack)
//             for i in 0..<qwords {
//                 mov_from(asmm, Reg64.Rax, Reg64.R10, stackoff) 
//                 mov_to(asmm, Reg64.Rbp, Reg64.Rax, off) 
//                 off += 8
//                 stackoff += 8
//             }
//             size -= qwords * 8
//             if size >= 4 {
//                 mov_from(asmm, Reg32.Eax, Reg64.R10, stackoff) 
//                 mov_to(asmm, Reg64.Rbp, Reg32.Eax, off) 
//                 off += 4
//                 stackoff += 4
//                 size -= 4
//             }
//             if size >= 2 {
//                 mov_from(asmm, Reg16.Ax, Reg64.R10, stackoff) 
//                 mov_to(asmm, Reg64.Rbp, Reg16.Ax, off) 
//                 off += 2
//                 stackoff += 2
//                 size -= 2
//             }
//             if size >= 1 {
//                 mov_from(asmm, Reg8.Al, Reg64.R10, stackoff) 
//                 mov_to(asmm, Reg64.Rbp, Reg8.Al, off) 
//                 off += 1
//                 stackoff += 1
//                 size -= 1
//             }
//     }
    stack_pop(stack)
}
get_local :: proc(using function: ^Function, index: u64) -> ^Type {
    type: ^Type = nil
    if cast(int)index < len(function.args) {
        type = function.args[index]
    }
    else {
        type = function.locals[cast(int)index - len(function.args)]
    }
    return type
}
jit_compile_eq :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack, vm: ^VM) {
    using x86asm
    size := get_stack_size(stack)
    type := stack_pop(stack)
    stack_pop(stack)
    stack_push(stack, vm.primitiveTypes[PrimitiveType.Boolean])
    typesize := get_type_size(type)
    switch typesize {
        case 8:
            mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -size + 8)
            cmp(asmm, Reg64.Rax, Reg64.Rcx)
        case 4:
            mov_from(asmm, Reg32.Eax, Reg64.R10, -size)
            mov_from(asmm, Reg32.Ecx, Reg64.R10, -size + 8)
            cmp(asmm, Reg32.Eax, Reg32.Ecx)
        case 2:
            mov_from(asmm, Reg16.Ax, Reg64.R10, -size)
            mov_from(asmm, Reg16.Cx, Reg64.R10, -size + 8)
            cmp(asmm, Reg16.Ax, Reg16.Cx)
        case 1:
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            mov_from(asmm, Reg8.Cl, Reg64.R10, -size + 8)
            cmp(asmm, Reg8.Al, Reg8.Cl)
    }
    eq := create_label(asmm)
    end := create_label(asmm)
    je(asmm, eq)
    mov(asmm, Reg8.Al, 0)
    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
    jmp(asmm,end)
    set_label(asmm, eq)
    mov(asmm, Reg8.Al, 1)
    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
    set_label(asmm, end)
}
jit_compile_gt :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack, vm: ^VM) {
    using x86asm
    size := get_stack_size(stack)
    type := stack_pop(stack)
    stack_pop(stack)
    stack_push(stack, vm.primitiveTypes[PrimitiveType.Boolean])
    typesize := get_type_size(type)
    switch typesize {
        case 8:
            mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -size + 8)
            cmp(asmm, Reg64.Rax, Reg64.Rcx)
        case 4:
            mov_from(asmm, Reg32.Eax, Reg64.R10, -size)
            mov_from(asmm, Reg32.Ecx, Reg64.R10, -size + 8)
            cmp(asmm, Reg32.Eax, Reg32.Ecx)
        case 2:
            mov_from(asmm, Reg16.Ax, Reg64.R10, -size)
            mov_from(asmm, Reg16.Cx, Reg64.R10, -size + 8)
            cmp(asmm, Reg16.Ax, Reg16.Cx)
        case 1:
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            mov_from(asmm, Reg8.Cl, Reg64.R10, -size + 8)
            cmp(asmm, Reg8.Al, Reg8.Cl)
    }
    eq := create_label(asmm)
    end := create_label(asmm)
    jgt(asmm, eq)
    mov(asmm, Reg8.Al, 0)
    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
    jmp(asmm,end)
    set_label(asmm, eq)
    mov(asmm, Reg8.Al, 1)
    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
    set_label(asmm, end)
}
jit_compile_lt :: proc(asmm: ^x86asm.Assembler, stack: ^TypeStack, vm: ^VM) {
    using x86asm
    size := get_stack_size(stack)
    type := stack_pop(stack)
    stack_pop(stack)
    stack_push(stack, vm.primitiveTypes[PrimitiveType.Boolean])
    typesize := get_type_size(type)
    switch typesize {
        case 8:
            mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -size + 8)
            cmp(asmm, Reg64.Rax, Reg64.Rcx)
        case 4:
            mov_from(asmm, Reg32.Eax, Reg64.R10, -size)
            mov_from(asmm, Reg32.Ecx, Reg64.R10, -size + 8)
            cmp(asmm, Reg32.Eax, Reg32.Ecx)
        case 2:
            mov_from(asmm, Reg16.Ax, Reg64.R10, -size)
            mov_from(asmm, Reg16.Cx, Reg64.R10, -size + 8)
            cmp(asmm, Reg16.Ax, Reg16.Cx)
        case 1:
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            mov_from(asmm, Reg8.Cl, Reg64.R10, -size + 8)
            cmp(asmm, Reg8.Al, Reg8.Cl)
    }
    eq := create_label(asmm)
    end := create_label(asmm)
    jlt(asmm, eq)
    mov(asmm, Reg8.Al, 0)
    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
    jmp(asmm,end)
    set_label(asmm, eq)
    mov(asmm, Reg8.Al, 1)
    mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
    set_label(asmm, end)
}
nullref :: proc "c" (module: string) {
    context = ctx
    for len(stacktrace) > 0 {
        frame :StackFrame= {}
        stack_trace_pop(&frame)
        fmt.printf("at %v.%v\n", frame.fn.module.name, frame.fn.name)
    }
    panic("NULL REF")
}
ObjectHeader :: struct {
    type: ^Type,
    visited: i32,
    size: i32,
}
ArrayHeader :: struct {
    header: ObjectHeader,
    length: i64,
}
new_array :: proc "c" (vm: ^VM, type: ^Type, count: i64) -> rawptr {
    context = ctx
    elemType := type.(ArrayType).underlaying
    obj := cast(^ArrayHeader)gc_alloc(&vm.gc, size_of(ArrayHeader) + get_type_size(elemType) * cast(int)count)
//     obj := cast(^ArrayHeader)mem.alloc(size_of(ArrayHeader) + get_type_size(elemType) * cast(int)count)
    obj.header.type = type
    obj.header.size = cast(i32)get_type_size(elemType) * cast(i32)count + size_of(ArrayHeader)
    obj.length = count
    return obj
}
box_obj :: proc "c" (vm: ^VM, type: ^Type) -> rawptr {
    context = ctx
    obj := cast(^ObjectHeader)gc_alloc(&vm.gc, size_of(ObjectHeader) + get_type_size(type))
    if obj == nil {
        panic("Allocation failed")
    }
    obj.size = cast(i32)get_type_size(type) + size_of(ObjectHeader)
    obj.type = type
    return obj
}
jit_compile_instruction :: proc(using function: ^Function, vm: ^VM, instruction: Instruction, local: []int, asmm: ^x86asm.Assembler, stack: ^TypeStack, labels: map[int]x86asm.Label) {
        using x86asm
#partial switch instruction.opcode {
        case .PushNull:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.Any])
            mov(asmm, Reg32.Eax, 0)
            mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
        case .PushI64:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.I64])         
            size := get_stack_size(stack)
            mov(asmm, Reg64.Rax, instruction.operand)
            mov_to(asmm, Reg64.R10, Reg64.Rax, cast(i32)(-size))
        case .PushU64:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.U64])         
            size := get_stack_size(stack)
            mov(asmm, Reg64.Rax, instruction.operand)
            mov_to(asmm, Reg64.R10, Reg64.Rax, cast(i32)(-size))
        case .PushI32:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.I32])
            size := get_stack_size(stack)
            mov(asmm, Reg32.Eax, cast(u32)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg32.Eax, cast(i32)(-size))
        case .PushU32:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.U32])
            size := get_stack_size(stack)
            mov(asmm, Reg32.Eax, cast(u32)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg32.Eax, cast(i32)(-size))
        case .PushI16:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.I16])
            size := get_stack_size(stack)
            mov(asmm, Reg16.Ax, cast(u16)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg16.Ax, cast(i32)(-size))
        case .PushU16:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.U16])
            size := get_stack_size(stack)
            mov(asmm, Reg16.Ax, cast(u16)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg16.Ax, cast(i32)(-size))
        case .PushU8:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.U8])
            size := get_stack_size(stack)
            mov(asmm, Reg8.Al, cast(u8)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg8.Al, cast(i32)(-size))
        case .PushI8:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.I8])
            size := get_stack_size(stack)
            mov(asmm, Reg8.Al, cast(u8)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg8.Al, cast(i32)(-size))
        case .PushTrue:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.Boolean])
            size := get_stack_size(stack)
            mov(asmm, Reg8.Al, 1)
            mov_to(asmm, Reg64.R10, Reg8.Al, cast(i32)(-size))
        case .PushFalse:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.Boolean])
            size := get_stack_size(stack)
            mov(asmm, Reg8.Al, 0)
            mov_to(asmm, Reg64.R10, Reg8.Al, cast(i32)(-size))
        case .PushChar:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.Char])
            size := get_stack_size(stack)
            mov(asmm, Reg16.Ax, cast(u16)instruction.operand)
            mov_to(asmm, Reg64.R10, Reg16.Ax, cast(i32)(-size))
        case .PushString:
            stack_push(stack, vm.primitiveTypes[PrimitiveType.String])
            size := get_stack_size(stack)
            mov(asmm, Reg64.Rax, transmute(u64)function.module.strings[instruction.operand])
            mov_to(asmm, Reg64.R10, Reg64.Rax, cast(i32)(-size))
        case .Pop:
            stack_pop(stack)
        case .Add: 
            jit_compile_add(asmm, stack)
        case .Sub:
            jit_compile_sub(asmm, stack)
        case .PushLocal:
            type := get_local(function, instruction.operand)
            jit_compile_pushlocal(asmm, stack, cast(i32)local[instruction.operand], type)
        case .SetLocal:
            type := get_local(function, instruction.operand)
            offset := local[instruction.operand]
            jit_compile_setlocal(asmm, stack, cast(i32)offset, type)
        case .EQ:
            jit_compile_eq(asmm, stack, vm) 
        case .LT:
            jit_compile_lt(asmm, stack, vm)
        case .GT:
            jit_compile_gt(asmm, stack, vm)
        case .Jmp:
            jmp(asmm, labels[cast(int)instruction.operand])
        case .Jtrue:
            size := get_stack_size(stack)
            stack_pop(stack)
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            mov(asmm, Reg8.Cl, 0)
            cmp(asmm, Reg8.Al, Reg8.Cl)
            jne(asmm, labels[cast(int)instruction.operand])
        case .Not:
            size := get_stack_size(stack)
            mov(asmm, Reg8.Cl, 0)
            mov_from(asmm, Reg8.Al, Reg64.R10, -size)
            cmp(asmm, Reg8.Al, Reg8.Cl)
            eq := create_label(asmm)
            end := create_label(asmm)
            je(asmm, eq)
            mov(asmm, Reg8.Al, 0)
            jmp(asmm,end)
            set_label(asmm, eq)
            mov(asmm, Reg8.Cl, 1)
            set_label(asmm, end)
            mov_to(asmm, Reg64.R10, Reg8.Cl, -size)
        case .RefLocal:
            stack_push(stack, make_ref(vm, get_local(function, instruction.operand)))
            offset := local[instruction.operand]
            mov(asmm, Reg64.Rax, Reg64.Rbp)
            mov(asmm, Reg64.Rcx, transmute(u64)offset)
            add(asmm, Reg64.Rax, Reg64.Rcx)
            mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
        case .Deref:
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -get_stack_size(stack))
            jit_null_check(asmm, Reg64.Rcx)
            reftype := stack_pop(stack)
            stack_push(stack, reftype.(RefType).underlaying)
            jit_memcpy(asmm, get_type_size(reftype.(RefType).underlaying), Reg64.Rcx, Reg64.R10, 0, -get_stack_size(stack))

        case .StoreRef:
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -get_stack_size(stack))
            jit_null_check(asmm, Reg64.Rcx)
            reftype := stack_pop(stack)
            jit_memcpy(asmm, get_type_size(reftype.(RefType).underlaying), Reg64.R10, Reg64.Rcx, -get_stack_size(stack), 0)
            stack_pop(stack)
        case .GetFieldRef:
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -get_stack_size(stack))
            jit_null_check(asmm, Reg64.Rcx)
            reftype := stack_pop(stack)
            field: ^Field = nil
            if type_is(RefType, reftype) {
                field = reftype.(RefType).underlaying.(CustomType).fields[instruction.operand]
                mov(asmm, Reg64.Rdx, transmute(u64)field.offset)
            }
            else {
                field = reftype.(BoxedType).underlaying.(CustomType).fields[instruction.operand]
                mov(asmm, Reg64.Rdx, transmute(u64)field.offset + size_of(ObjectHeader))
            }
            add(asmm, Reg64.Rcx, Reg64.Rdx)
            reft := make_ref(vm, field.type)
            stack_push(stack, reft)
            mov_to(asmm, Reg64.R10, Reg64.Rcx, -get_stack_size(stack))
        case .GetField:
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -get_stack_size(stack))
            jit_null_check(asmm, Reg64.Rcx)
            reftype := stack_pop(stack)
            field: ^Field = nil
            fmt.print(stack.types)
            if type_is(RefType, reftype) {
                field = reftype.(RefType).underlaying.(CustomType).fields[instruction.operand]
                mov(asmm, Reg64.Rdx, transmute(u64)field.offset)
            }
            else {
                field = reftype.(BoxedType).underlaying.(CustomType).fields[instruction.operand]
                mov(asmm, Reg64.Rdx, transmute(u64)field.offset + size_of(ObjectHeader))
            }
            add(asmm, Reg64.Rcx, Reg64.Rdx)
            stack_push(stack, field.type)
            jit_memcpy(asmm, get_type_size(field.type), Reg64.Rcx, Reg64.R10, 0, -get_stack_size(stack))
        case .ToRawPtr:
            stack_pop(stack)
            stack_push(stack, vm.primitiveTypes[PrimitiveType.I64])
        case .SetField:
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -get_stack_size(stack))
            jit_null_check(asmm, Reg64.Rcx)
            reftype := stack_pop(stack)
            field: ^Field = nil
            if type_is(RefType, reftype) {
                field = reftype.(RefType).underlaying.(CustomType).fields[instruction.operand]
                mov(asmm, Reg64.Rdx, transmute(u64)field.offset)
            }
            else {
                field = reftype.(BoxedType).underlaying.(CustomType).fields[instruction.operand]
                mov(asmm, Reg64.Rdx, transmute(u64)field.offset + size_of(ObjectHeader))
            }
            add(asmm, Reg64.Rcx, Reg64.Rdx)
            jit_memcpy(asmm, get_type_size(field.type), Reg64.R10, Reg64.Rcx, -get_stack_size(stack), 0)
            stack_pop(stack) 
        case .Box:
//             int3(asmm)
            type := stack_pop(stack)
            stack_push(stack, type)

            when os.OS == runtime.Odin_OS_Type.Windows {
                push(asmm, Reg64.R10)
                push(asmm, Reg64.R10)
                mov(asmm, Reg64.Rcx, transmute(u64)vm)
                mov(asmm, Reg64.Rdx, transmute(u64)type)
                mov(asmm, Reg32.Eax, 32)
                sub(asmm, Reg64.Rsp, Reg64.Rax)
                mov(asmm, Reg64.Rax, transmute(u64)box_obj)
                call_reg(asmm, Reg64.Rax)
                mov(asmm, Reg32.Edx, 32)
                add(asmm, Reg64.Rsp, Reg64.Rdx)
                pop(asmm, Reg64.R10)
                pop(asmm, Reg64.R10)
            }
            else when os.OS == runtime.Odin_OS_Type.Linux {
                push(asmm, Reg64.R10)
                push(asmm, Reg64.R10)
                mov(asmm, Reg64.Rdi, transmute(u64)vm)
                mov(asmm, Reg64.Rsi, transmute(u64)type)
                mov(asmm, Reg32.Eax, 32)
                sub(asmm, Reg64.Rsp, Reg64.Rax)
                mov(asmm, Reg64.Rax, transmute(u64)box_obj)
                call_reg(asmm, Reg64.Rax)
                mov(asmm, Reg32.Edx, 32)
                add(asmm, Reg64.Rsp, Reg64.Rdx)
                pop(asmm, Reg64.R10)
                pop(asmm, Reg64.R10)
            }
            mov(asmm, Reg64.Rcx, Reg64.Rax)
            jit_memcpy(asmm, get_type_size(type), Reg64.R10, Reg64.Rcx, -get_stack_size(stack), size_of(ObjectHeader))
            stack_pop(stack)
            stack_push(stack, make_box(vm, type))
            mov_to(asmm, Reg64.R10, Reg64.Rcx, -get_stack_size(stack))
            
        case .Unbox:
            mov_from(asmm, Reg64.Rcx, Reg64.R10, -get_stack_size(stack))
            jit_null_check(asmm, Reg64.Rcx)
            box := stack_pop(stack)
            stack_push(stack, box.(BoxedType).underlaying)
            jit_memcpy(asmm, get_type_size(box.(BoxedType).underlaying), Reg64.Rcx, Reg64.R10, size_of(ObjectHeader), -get_stack_size(stack)) 
        case .IsInstanceOf:
            firstArg := Reg64.Rcx
            secondArg := Reg64.Rdx
            when os.OS == runtime.Odin_OS_Type.Linux {
                firstArg = Reg64.Rdi
                secondArg = Reg64.Rsi
            }
            mov_from(asmm, firstArg, Reg64.R10, -get_stack_size(stack))
            stack_pop(stack)
            stack_push(stack, vm.primitiveTypes[PrimitiveType.Boolean])

            mov(asmm, Reg64.Rax, 0)
            cmp(asmm, firstArg, Reg64.Rax)
            notnull := create_label(asmm)
            endofblock := create_label(asmm)
            jne(asmm, notnull)
            mov(asmm, Reg8.Al, 0)
            jmp(asmm, endofblock)
            
            set_label(asmm, notnull)
            mov_from(asmm, firstArg, firstArg)
            mov(asmm, secondArg, transmute(u64)function.module.typedescriptors[instruction.operand])
            mov(asmm, Reg64.Rax, transmute(u64)type_equals)
            push(asmm, Reg64.R10)
            push(asmm, Reg64.R10)
            mov(asmm, Reg64.R8, 32)
            sub(asmm, Reg64.Rsp, Reg64.R8)
            call_reg(asmm, Reg64.Rax)
            mov(asmm, Reg64.R8, 32)
            add(asmm, Reg64.Rsp, Reg64.R8)

            pop(asmm, Reg64.R10)
            pop(asmm, Reg64.R10)

            set_label(asmm, endofblock)
            mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack))
        case .Cast:
            mov_from(asmm, Reg64.R8, Reg64.R10, -get_stack_size(stack))
            stack_pop(stack)
            casttype := function.module.typedescriptors[instruction.operand]
            stack_push(stack, casttype)

            mov(asmm, Reg64.Rax, 0)
            cmp(asmm, Reg64.R8, Reg64.Rax)
            notnull := create_label(asmm)
            endofblock := create_label(asmm)
            jne(asmm, notnull)
            mov(asmm, Reg64.Rax, 0)
            mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
            jmp(asmm, endofblock)

            set_label(asmm, notnull)
            if type_is(PrimitiveType, casttype) && casttype.(PrimitiveType) == PrimitiveType.Any {
                mov_to(asmm, Reg64.R10, Reg64.R8, -get_stack_size(stack))
            }
            else {
                when os.OS == runtime.Odin_OS_Type.Windows {
                    mov_from(asmm, Reg64.Rcx, Reg64.R8)
                    mov(asmm, Reg64.Rdx, transmute(u64)casttype)
                }
                else when os.OS == runtime.Odin_OS_Type.Linux {
                    mov_from(asmm, Reg64.Rdi, Reg64.R8)
                    mov(asmm, Reg64.Rsi, transmute(u64)casttype)
                }
                else {
                    panic("")
                }
                mov(asmm, Reg64.Rax, transmute(u64)type_equals)
                push(asmm, Reg64.R8)
                push(asmm, Reg64.R10)
                mov(asmm, Reg64.R8, 32)
                sub(asmm, Reg64.Rsp, Reg64.R8)
                call_reg(asmm, Reg64.Rax)
                mov(asmm, Reg64.R8, 32)
                add(asmm, Reg64.Rsp, Reg64.R8)

                pop(asmm, Reg64.R10)
                pop(asmm, Reg64.R8)
                mov_to(asmm, Reg64.R10, Reg64.R8, -get_stack_size(stack))
            }
            set_label(asmm, endofblock)
        case .Conv:
            jit_compile_conv(asmm, stack, function.module.typedescriptors[instruction.operand])
        case .NewObj:
            type := function.module.typedescriptors[instruction.operand]
            if type_is(CustomType, type) {
                panic("Not implemented")
            }
            push(asmm, Reg64.R10)
            push(asmm, Reg64.R10)
            when os.OS == runtime.Odin_OS_Type.Windows {
                mov(asmm, Reg64.Rdx, transmute(u64)type)
                mov(asmm, Reg64.Rcx, transmute(u64)vm)
                mov_from(asmm, Reg64.R8, Reg64.R10, -get_stack_size(stack))
            }
            else when os.OS == runtime.Odin_OS_Type.Linux {
                mov(asmm, Reg64.Rsi, transmute(u64)type)
                mov(asmm, Reg64.Rdi, transmute(u64)vm)
                mov_from(asmm, Reg64.Rdx, Reg64.R10, -get_stack_size(stack))
            }
            else {
                panic("")
            }
            lentype := stack_pop(stack)
            if lentype.(PrimitiveType) != PrimitiveType.I64 {
                panic("Not implemented")
            }
            mov(asmm, Reg32.Eax, 32)
            sub(asmm, Reg64.Rsp, Reg64.Rax)
            mov(asmm, Reg64.R11, transmute(u64)new_array)
            call_reg(asmm, Reg64.R11)
            mov(asmm, Reg32.Ecx, 32)
            add(asmm, Reg64.Rsp, Reg64.Rcx)
            pop(asmm, Reg64.R10)
            pop(asmm, Reg64.R10)
            stack_push(stack, make_array(vm, type))
            mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
        case .GetIndexRef:
            firstArg := Reg64.Rcx
            secondArg := Reg64.Rdx
            when os.OS == runtime.Odin_OS_Type.Linux {
                firstArg = Reg64.Rdi
                secondArg = Reg64.Rsi
            }
            mov_from(asmm, firstArg, Reg64.R10, -get_stack_size(stack))
            indextype := stack_pop(stack)
            mov_from(asmm, secondArg, Reg64.R10, -get_stack_size(stack))
            type := stack_pop(stack)
            if indextype.(PrimitiveType) != PrimitiveType.I64 {
                panic("Not implemented")
            }
            jit_null_check(asmm, secondArg)
            mov_from(asmm, Reg64.R8, secondArg, size_of(ObjectHeader))
            mov(asmm, Reg32.Eax, 0)
            cmp(asmm, firstArg, Reg64.Rax)
            notout := create_label(asmm)
            out := create_label(asmm)
            jlt(asmm, out)
            cmp(asmm, firstArg, Reg64.R8)
            jge(asmm, out)
            jmp(asmm, notout)
            set_label(asmm, out)
            mov(asmm, Reg64.Rax, transmute(u64)out_of_bounds)
            call_reg(asmm, Reg64.Rax)
            set_label(asmm, notout)
            elemType := type.(ArrayType).underlaying
            mov(asmm, Reg32.R8d, cast(u32)get_type_size(elemType))
            imul(asmm, firstArg, Reg64.R8)
            add(asmm, firstArg, secondArg)
            stack_push(stack, make_ref(vm, elemType))
            mov(asmm, secondArg, size_of(ObjectHeader) + 8)
            add(asmm, firstArg, secondArg)
            mov_to(asmm, Reg64.R10, firstArg, -get_stack_size(stack))
        case .GetLength:
            mov_from(asmm, Reg64.Rdx, Reg64.R10, -get_stack_size(stack))
            type := stack_pop(stack)
            jit_null_check(asmm, Reg64.Rdx)
            stack_push(stack, vm.primitiveTypes[PrimitiveType.I64])
            mov_from(asmm, Reg64.Rdx, Reg64.Rdx, size_of(ObjectHeader))
            mov_to(asmm, Reg64.R10, Reg64.Rdx, -get_stack_size(stack))
        case .GetIndex:
            indexReg := Reg64.Rcx
            when os.OS == runtime.Odin_OS_Type.Windows {
                indexReg = Reg64.Rcx
            }
            else when os.OS == runtime.Odin_OS_Type.Linux {
                indexReg = Reg64.Rdi
            }
            else {
                panic("")
            }
            mov_from(asmm, indexReg, Reg64.R10, -get_stack_size(stack))
            indextype := stack_pop(stack)
            mov_from(asmm, Reg64.Rdx, Reg64.R10, -get_stack_size(stack))
            type := stack_pop(stack)
            if indextype.(PrimitiveType) != PrimitiveType.I64 {
                panic("Not implemented")
            }
            jit_null_check(asmm, Reg64.Rdx)
            mov_from(asmm, Reg64.R8, Reg64.Rdx, size_of(ObjectHeader))
            mov(asmm, Reg32.Eax, 0)
            cmp(asmm, indexReg, Reg64.Rax)
            notout := create_label(asmm)
            out := create_label(asmm)
            jlt(asmm, out)
            cmp(asmm, indexReg, Reg64.R8)
            jge(asmm, out)
            jmp(asmm, notout)
            set_label(asmm, out)
            mov(asmm, Reg64.Rax, transmute(u64)out_of_bounds)
            call_reg(asmm, Reg64.Rax)
            set_label(asmm, notout)
            elemType: ^Type = nil
            if type_is(ArrayType, type) {
                elemType = type.(ArrayType).underlaying
            } else {
                elemType = vm.primitiveTypes[PrimitiveType.Char] 
            }
            mov(asmm, Reg32.R8d, cast(u32)get_type_size(elemType))
            imul(asmm, indexReg, Reg64.R8)
            add(asmm, indexReg, Reg64.Rdx)
            stack_push(stack, elemType)
            jit_memcpy(asmm, get_type_size(elemType), indexReg, Reg64.R10, size_of(ObjectHeader) + 8, -get_stack_size(stack))
        case .SetIndex:
//             int3(asmm)
            indexReg := Reg64.Rcx
            when os.OS == runtime.Odin_OS_Type.Windows {
                indexReg = Reg64.Rcx
            }
            else when os.OS == runtime.Odin_OS_Type.Linux {
                indexReg = Reg64.Rdi
            }
            else {
                panic("")
            }
            mov_from(asmm, indexReg, Reg64.R10, -get_stack_size(stack))
            indextype := stack_pop(stack)
            mov_from(asmm, Reg64.Rdx, Reg64.R10, -get_stack_size(stack))
            type := stack_pop(stack)
            if indextype.(PrimitiveType) != PrimitiveType.I64 {
                panic("Not implemented")
            }
            jit_null_check(asmm, Reg64.Rdx)
            mov_from(asmm, Reg64.R8, Reg64.Rdx, size_of(ObjectHeader))
            mov(asmm, Reg32.Eax, 0)
            cmp(asmm, indexReg, Reg64.Rax)
            notout := create_label(asmm)
            out := create_label(asmm)
            jlt(asmm, out)
            cmp(asmm, indexReg, Reg64.R8)
            jge(asmm, out)
            jmp(asmm, notout)
            set_label(asmm, out)
            mov(asmm, Reg64.Rax, transmute(u64)out_of_bounds)
            call_reg(asmm, Reg64.Rax)
            set_label(asmm, notout)
            elemType := type.(ArrayType).underlaying
            mov(asmm, Reg32.R8d, cast(u32)get_type_size(elemType))
            imul(asmm, indexReg, Reg64.R8)
            add(asmm, indexReg, Reg64.Rdx)
            jit_memcpy(asmm, get_type_size(elemType), Reg64.R10, indexReg, -get_stack_size(stack), size_of(ArrayHeader))
            stack_pop(stack)
        case .Call:
            when os.OS == runtime.Odin_OS_Type.Windows {
                jit_compile_call_win_abi(function, vm, instruction, asmm, stack)
            }
            else when os.OS == runtime.Odin_OS_Type.Linux {
                jit_compile_call_systemv_abi(function, vm, instruction, asmm, stack)
            }
            else {
                panic("Not IMPLEMENTED") 
            }
        case .Ret:
            arg := Reg64.Rcx
            when os.OS == runtime.Odin_OS_Type.Windows {
                arg = Reg64.Rcx
            }
            else when os.OS == runtime.Odin_OS_Type.Linux {
                arg = Reg64.Rdi
            }
            else {
                panic("Not IMPLEMENTED") 
            }
            push(asmm, Reg64.R10)
            mov(asmm, Reg64.Rax, 24)
            sub(asmm, Reg64.Rsp, Reg64.Rax)
            mov(asmm, arg, 0)
            mov(asmm, Reg64.Rax, 32)
            sub(asmm, Reg64.Rsp, Reg64.Rax)
            mov(asmm, Reg64.Rax, transmute(u64)stack_trace_pop)
            call_reg(asmm, Reg64.Rax)
            mov(asmm, Reg64.Rax, 32 + 24)
            add(asmm, Reg64.Rsp, Reg64.Rax)
            pop(asmm, Reg64.R10)
            if stack.count == 0 {
                mov(asmm, Reg64.Rsp, Reg64.Rbp)

                pop(asmm, Reg64.Rbp)
                ret(asmm)
            } 
            else {
                when os.OS == runtime.Odin_OS_Type.Windows {
                    size := get_stack_size(stack)
                    retSize := get_type_size(function.retType)
                    if retSize <= 8 {
                        mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
                        mov(asmm, Reg64.Rsp, Reg64.Rbp)
                        pop(asmm, Reg64.Rbp)
                        ret(asmm)
                    }
                    else {
                        s: i32 = 0
                        mov_from(asmm, Reg64.R11, Reg64.Rbp, -8)
                        jit_memcpy(asmm, retSize, Reg64.R10, Reg64.R11, -size, 0)
                        mov(asmm, Reg64.Rax, Reg64.R11)
                        mov(asmm, Reg64.Rsp, Reg64.Rbp)
                        pop(asmm, Reg64.Rbp)
                        ret(asmm)
                    }
                }
                else {
                    size := get_stack_size(stack)
                    retSize := get_type_size(retType)
                    if retSize <= 8 {
                        mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
                        mov(asmm, Reg64.Rsp, Reg64.Rbp)
                        pop(asmm, Reg64.Rbp)
                        ret(asmm)
                    }
                    else if retSize > 8 && retSize <= 16 {
                        mov_from(asmm, Reg64.Rax, Reg64.R10, -size)
                        mov_from(asmm, Reg64.Rdx, Reg64.R10, -size + 8)
                        mov(asmm, Reg64.Rsp, Reg64.Rbp)
                        pop(asmm, Reg64.Rbp)
                        ret(asmm)
                    }
                    else {
                        s: i32 = 0
                        mov_from(asmm, Reg64.Rax, Reg64.Rbp, -8)
                        for s < cast(i32)retSize {
                            mov_from(asmm, Reg64.R11, Reg64.R10, -size + s)                        
                            mov_to(asmm, Reg64.Rax, Reg64.R11, s)
                            s += 8
                        }
                        mov(asmm, Reg64.Rsp, Reg64.Rbp)
                        pop(asmm, Reg64.Rbp)
                        ret(asmm)
                    }
                }
            }

        case: 
            fmt.println(instruction)
            panic("FUKIE WAKIE")
    }
}
reverse :: proc($T: typeid, arr: []T) -> []T {
    s := 0
    i := len(arr) - 1
    for s < i {
        t := arr[i]
        arr[i] = arr[s]
        arr[s] = t
        s += 1
        i -= 1
    }
    return arr
}
StackFrame :: struct {
    fn: ^Function,
    stack: [^]u8,
    stack_size: i64,
}
stacktrace := make([dynamic]StackFrame)
stack_trace_add :: proc "c" (frame: ^StackFrame) {
    context = ctx
//     fmt.println("Name", frame.fn.name)
    append(&stacktrace, frame^)
}
stack_trace_pop :: proc "c" (out: ^StackFrame) {
    context = ctx
    res := stacktrace[len(stacktrace) - 1]
    remove_range(&stacktrace, len(stacktrace) - 1, len(stacktrace))    
    if out != nil {
        out^ = res
    }

}
jit_compile_call_systemv_abi :: proc(using function: ^Function, vm: ^VM, instruction: Instruction, asmm: ^x86asm.Assembler, stack: ^TypeStack) {
    using x86asm
    fnindex := cast(int)instruction.operand
    fn: ^Function = nil

    if fnindex < len(module.functionImports) {
        fn = module.functionImports[fnindex] 
    }
    else {
        fn = module.functions[fnindex - len(module.functionImports)] 
    }
    if fn.name == "testmany" {
//          int3(asmm)
    }
    registers: []Reg64 = nil
    big_return := get_type_size(fn.retType) > 16
    if big_return {
        registers = ([]Reg64{Reg64.Rsi, Reg64.Rdx, Reg64.Rcx, Reg64.R8, Reg64.R9 });
    }
    else {
        registers = ([]Reg64{Reg64.Rdi, Reg64.Rsi, Reg64.Rdx, Reg64.Rcx, Reg64.R8, Reg64.R9 });
        
    }
    //int3(asmm)
    i := 0
    regindex := 0
    //args = fn.args
    stack_args := make([dynamic]Tuple(^Type, i32))
    defer delete(stack_args)
    for i < len(fn.args) {
        arg := fn.args[i]
        if type_is_float(arg) {
            panic("FLOAT NOT IMPLEMENTED")
        }
        size := get_type_size(arg)
        switch size {
            case 1:
                if regindex < len(registers) {
                    mov_from(asmm, cast(Reg8)registers[regindex], Reg64.R10, -get_stack_size(stack))
                }
                else {
                    append(&stack_args, tuple(arg, -get_stack_size(stack)))
                }
            case 2:
                if regindex < len(registers) {
                    mov_from(asmm, cast(Reg16)registers[regindex], Reg64.R10, -get_stack_size(stack))
                }
                else {
                    append(&stack_args, tuple(arg, -get_stack_size(stack)))
                }
            case 4:
                if regindex < len(registers) {
                    mov_from(asmm, cast(Reg32)registers[regindex], Reg64.R10, -get_stack_size(stack))
                }
                else {
                    append(&stack_args, tuple(arg, -get_stack_size(stack)))
                }
            case 8:
                if regindex < len(registers) {
                    mov_from(asmm, cast(Reg64)registers[regindex], Reg64.R10, -get_stack_size(stack))
                }
                else {
                    append(&stack_args, tuple(arg, -get_stack_size(stack)))
                }
            case:
                if size <= 16 {
//                     int3(asmm)
                    mov_from(asmm, registers[regindex], Reg64.R10, -get_stack_size(stack))
                    mov_from(asmm, registers[regindex + 1], Reg64.R10, -get_stack_size(stack) + 8)
                    regindex += 1
                } 
                else {
                    append(&stack_args, tuple(arg, -get_stack_size(stack)))
                } 
        }
        
        stack_pop(stack)
        i += 1
        regindex += 1
    }
    push(asmm, Reg64.R10)
    push(asmm, Reg64.R10)
    i = len(stack_args) - 1
    stack_size := 0
    for a in stack_args {
        stack_size += get_type_size(a.first, true)
    }
   

    if big_return {
        fmt.println("BIG RETURN")
        mov(asmm, Reg64.R11, cast(u64)get_type_size(fn.retType))
        sub(asmm, Reg64.Rsp, Reg64.R11)
        mov(asmm, Reg64.Rdi, Reg64.Rsp)
        stack_size += get_type_size(fn.retType)
    }
    if stack_size % 16 != 0 {
        alignment := 16 - (stack_size % 16)
        stack_size += alignment
        mov(asmm, Reg64.R11, transmute(u64)(alignment))
        sub(asmm, Reg64.Rsp, Reg64.R11)
    }
    st := stack_size
    fmt.println("STACK ARGS", fn.name, len(stack_args), stack_args)
    for i >= 0 && len(stack_args) >= 1 {
        stack_arg := stack_args[i];
        st += get_type_size(stack_arg.first, true)
        argg := stack_arg.first
        if get_type_size(argg) <= 8 {
            mov_from(asmm, Reg64.R11, Reg64.R10, stack_arg.second)
            push(asmm, Reg64.R11)
        }
        else {
            mov(asmm, Reg64.R11, cast(u64)get_type_size(argg))
            sub(asmm, Reg64.Rsp, Reg64.R11)
            s: i32 = 0
            for s <= cast(i32)get_type_size(argg) {
                mov_from(asmm, Reg64.R11, Reg64.R10, stack_arg.second + s)
                mov_to(asmm, Reg64.Rsp, Reg64.R11, s)
                s += 8
            }
        }
        i -= 1 

    } 
//     mov(asmm, Reg64.Rax, 32)
//     sub(asmm, Reg64.Rsp, Reg64.Rax)
    mov(asmm, Reg64.Rax, 0)
    mov(asmm, Reg64.R12, transmute(u64)&fn.jmp_body.base)
    call_at_reg(asmm, Reg64.R12)
//     mov(asmm, Reg64.R15, 32)
//     add(asmm, Reg64.Rsp, Reg64.R15)
    mov(asmm, Reg64.R11, cast(u64)stack_size)
    add(asmm, Reg64.Rsp, Reg64.R11)
    pop(asmm, Reg64.R10)
    pop(asmm, Reg64.R10)
    if !type_equals(fn.retType, vm.primitiveTypes[PrimitiveType.Void]) {
        stack_push(stack, fn.retType)
        size := get_type_size(fn.retType)
        switch size {
            case 8:
                mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack)) 
            case 4:
                mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack)) 
            case 2:
                mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack)) 
            case 1:
                mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack)) 
            case:
                if size > 8 && size <= 16 {
                    mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack))
                    mov_to(asmm, Reg64.R10, Reg64.Rdx, -get_stack_size(stack) + 8)
                } else {
                    s: i32 = 0
                    for cast(int)s < size {
                        mov_from(asmm, Reg64.R11, Reg64.Rax, s)
                        mov_to(asmm, Reg64.R10, Reg64.R11, -get_stack_size(stack) + s)
                        s += 8
                    }
                }
        }
    }
}
jit_compile_call_win_abi :: proc(using function: ^Function, vm: ^VM, instruction: Instruction, asmm: ^x86asm.Assembler, stack: ^TypeStack) {
    using x86asm
    fnindex := cast(int)instruction.operand
    fn: ^Function = nil
    if fnindex < len(module.functionImports) {
        fn = module.functionImports[fnindex] 
    }
    else {
        fn = module.functions[fnindex - len(module.functionImports)] 
    }
    allocated_stack := 0
    mov(asmm, Reg64.R11, Reg64.Rsp)
    registers: []Reg64 = nil
    returnSize := 0
    if get_type_size(fn.retType) > 8 {
        size := get_type_size(fn.retType)
        if size % 16 != 0 {
            size += 16 - (size % 16)
        }
        returnSize = size
        sub(asmm, Reg64.Rsp, size)
        mov(asmm, Reg64.Rcx, Reg64.Rsp)
        registers = (([]Reg64{Reg64.Rdx, Reg64.R8, Reg64.R9}));
    }
    else {
        registers = ([]Reg64{Reg64.Rcx, Reg64.Rdx, Reg64.R8, Reg64.R9});
    }
    stack_args := make([dynamic]Tuple(^Type, i32))
    avail_regs := len(registers)
    for arg, i in fn.args {
        size := get_type_size(arg)
        if(avail_regs > 0 ) {
            switch size {
                case 1:
                    mov_from(asmm, cast(Reg8)registers[i], Reg64.R10, -get_stack_size(stack))
                case 2:
                    mov_from(asmm, cast(Reg16)registers[i], Reg64.R10, -get_stack_size(stack))
                case 4:
                    mov_from(asmm, cast(Reg32)registers[i], Reg64.R10, -get_stack_size(stack))
                case 8:
                    mov_from(asmm, cast(Reg64)registers[i], Reg64.R10, -get_stack_size(stack))
                case:
                    if size % 16 != 0 {
                        size += 16 - (size % 16)
                    }
                    allocated_stack += size
                    sub(asmm, Reg64.Rsp, size)
                    mov(asmm, registers[i], Reg64.Rsp)
                    jit_memcpy(asmm, size, Reg64.R10, Reg64.Rsp, -get_stack_size(stack), 0)

            } 
            avail_regs -= 1
        }   
        else {
            if size <= 8 { 
                append(&stack_args, tuple(arg, -get_stack_size(stack)))
            } else {
                if size % 16 != 0 {
                    size += 16 - (size % 16)
                }
                allocated_stack += size
                sub(asmm, Reg64.Rsp, size)
                jit_memcpy(asmm, size, Reg64.R10, Reg64.Rsp, -get_stack_size(stack), 0)
                append(&stack_args, tuple(arg, cast(i32)allocated_stack))
            }
        }
        stack_pop(stack)
    }
    if len(stack_args) % 2 != 0 { // stack allignment
        push(asmm, Reg64.Rax) 
        allocated_stack += 8
    }
    push(asmm, Reg64.R10)
    push(asmm, Reg64.R10)
    i := len(stack_args) - 1
    for i >= 0 && len(stack_args) >= 1 {
        stack_arg := stack_args[i]
        if get_type_size(stack_arg.first) <= 8 {
            mov_from(asmm, Reg64.Rax, Reg64.R10, stack_arg.second)
            push(asmm, Reg64.Rax)
        }
        else {
            mov(asmm, Reg64.Rax, Reg64.R11)
            sub(asmm, Reg64.Rax, cast(int)stack_arg.second) 
            push(asmm, Reg64.Rax)
        }
        i -= 1
    }
    sub(asmm, Reg64.Rsp, 32)
    mov(asmm, Reg64.Rax, transmute(u64)&fn.jmp_body.base)
    call_at_reg(asmm, Reg64.Rax)
    add(asmm, Reg64.Rsp, cast(i32)allocated_stack + 32)
    pop(asmm, Reg64.R10)
    pop(asmm, Reg64.R10)
    if !type_equals(fn.retType, vm.primitiveTypes[PrimitiveType.Void]) {
        stack_push(stack, fn.retType)
        size := get_type_size(fn.retType)
        switch size {
            case 8:
                mov_to(asmm, Reg64.R10, Reg64.Rax, -get_stack_size(stack)) 
            case 4:
                mov_to(asmm, Reg64.R10, Reg32.Eax, -get_stack_size(stack)) 
            case 2:
                mov_to(asmm, Reg64.R10, Reg16.Ax, -get_stack_size(stack)) 
            case 1:
                mov_to(asmm, Reg64.R10, Reg8.Al, -get_stack_size(stack)) 
            case:
                // TODO: MAYBE USE R11
                mov(asmm, Reg64.Rcx, Reg64.Rax)
                jit_memcpy(asmm, size, Reg64.Rcx, Reg64.R10, 0, -get_stack_size(stack))
                add(asmm, Reg64.Rsp, cast(i32)returnSize)
        }
    }
}
jit_function :: proc(using function: ^Function, vm: ^VM) -> Maybe(JitError) {
    using x86asm
    blocks := make([dynamic]int)
    append(&blocks, 0)
    
    for instr, i in instructions {
        if instr.opcode == OpCode.Jmp || instr.opcode == OpCode.Jtrue {
            append(&blocks, i + 1)
            append(&blocks, cast(int)instr.operand)
        }
        else if instr.opcode == OpCode.Ret {
            append(&blocks, i + 1)
        }
    }
    codeblocks := make([dynamic]CodeBlock)
    if len(blocks) >= 2
    {
        append(&codeblocks, CodeBlock { start = 0, instructions = instructions[blocks[0]:blocks[1]]})
        for i in 1..<len(blocks) {
            if i + 1 < len(blocks) && blocks[i] < blocks[i+1] {
                append(&codeblocks, CodeBlock { start = blocks[i], instructions = instructions[blocks[i]:blocks[i + 1]]})
            }
            else if blocks[i] != len(instructions) {
                append(&codeblocks, CodeBlock { start = blocks[i], instructions = instructions[blocks[i]:]})
            }
        }
    }
    else {
        append(&codeblocks, CodeBlock { instructions = instructions[:]})
    }
    err := calculate_stack(function, vm, &codeblocks[0],codeblocks)
    if err != nil {
        return err
    }
    res := check_if_all_code_paths_return_value(function, vm, &codeblocks[0], codeblocks)
    if !res {
        return not_all_code_paths_returns(function.name, module.name)
    }
    labels := make(map[int]x86asm.Label)
    

    a := initasm()
    if function.name == "main" {
//         int3(&a)
    }
//     for reg in ([]Reg64{Reg64.Rbx, Reg64.R10, Reg64.R11, Reg64.R12, Reg64.R13, Reg64.R14, Reg64.R15, Reg64.R15 }) {
//         push(&a, reg)   
//     }
    push(&a, Reg64.Rbp)
    mov(&a, Reg64.Rbp, Reg64.Rsp)
    when os.OS == runtime.Odin_OS_Type.Linux {
        if get_type_size(function.retType) > 16 {
            push(&a, Reg64.Rdi)
            push(&a, Reg64.Rdi)
        }
    } else when os.OS == runtime.Odin_OS_Type.Windows {
        if get_type_size(function.retType) > 8 {
            push(&a, Reg64.Rcx)
            push(&a, Reg64.Rcx)
        }
    }
    local, localssize := jit_prepare_locals(function, &a)
    fmt.println("LOCALS = ")
    fmt.println(local)
        
    stacksize: i64 = -128
    mov(&a, Reg64.R10, Reg64.Rsp) 
    mov(&a, Reg64.Rax, transmute(u64)stacksize)
    add(&a, Reg64.Rsp, Reg64.Rax)
    for cb in codeblocks {
        labels[cb.start] = create_label(&a)
    }
    when os.OS == runtime.Odin_OS_Type.Windows {
        push(&a, Reg64.R10)
        mov(&a, Reg64.Rax, 24)
        sub(&a, Reg64.Rsp, Reg64.Rax)
        mov(&a, Reg64.Rcx, Reg64.Rsp)
        mov(&a, Reg64.Rax, transmute(u64)function)
        mov_to(&a, Reg64.Rcx, Reg64.Rax)
        mov(&a, Reg64.Rax, Reg64.Rbp)
        mov_to(&a, Reg64.Rcx, Reg64.Rax, 8)
        mov(&a, Reg64.Rax, cast(u64)-(localssize + stacksize))
        mov_to(&a, Reg64.Rcx, Reg64.Rax, 16)
        mov(&a, Reg64.Rax, 32)
        sub(&a, Reg64.Rsp, Reg64.Rax)
        mov(&a, Reg64.Rax, transmute(u64)stack_trace_add)
        call_reg(&a, Reg64.Rax)
        mov(&a, Reg64.Rax, 24 + 32)
        add(&a, Reg64.Rsp, Reg64.Rax)
        pop(&a, Reg64.R10)
    }
    else when os.OS == runtime.Odin_OS_Type.Linux {
        push(&a, Reg64.R10)
        mov(&a, Reg64.Rax, 24)
        sub(&a, Reg64.Rsp, Reg64.Rax)
        mov(&a, Reg64.Rdi, Reg64.Rsp)
        mov(&a, Reg64.Rax, transmute(u64)function)
        mov_to(&a, Reg64.Rdi, Reg64.Rax)
        mov(&a, Reg64.Rax, Reg64.Rbp)
        mov_to(&a, Reg64.Rdi, Reg64.Rax, 8)
        mov(&a, Reg64.Rax, cast(u64)-(localssize + stacksize))
        mov_to(&a, Reg64.Rdi, Reg64.Rax, 16)
        mov(&a, Reg64.Rax, 32)
        sub(&a, Reg64.Rsp, Reg64.Rax)
        mov(&a, Reg64.Rax, transmute(u64)stack_trace_add)
        call_reg(&a, Reg64.Rax)
        mov(&a, Reg64.Rax, 24 + 32)
        add(&a, Reg64.Rsp, Reg64.Rax)
        pop(&a, Reg64.R10)
    }
    else {
        panic("")
    }

    append(&a.bytes, 0x90, 0x90, 0x90, 0x90, 0x90)
    for _, cbi in codeblocks {
        cb := &codeblocks[cbi]
        if cb.stack.types == nil {
            continue
        }
        set_label(&a, labels[cb.start])
        fmt.println(cb)
        for instr, index in cb.instructions {
            append(&a.bytes, 0x90)
            jit_compile_instruction(function, vm, instr, local, &a, &cb.stack, labels)
//             if function.name == "modify" && index == 4 { int3(&a) }
        
        }
    }
    assemble(&a)
    fmt.println(function.name)
    print_bytes(a.bytes)
    function.jitted_body = alloc_executable(len(a.bytes))
    for b, index in a.bytes {
        function.jitted_body.base[index] = b
    }
    jmpasm := initasm()
    mov(&jmpasm, Reg64.Rax, transmute(u64)&function.jitted_body.base)
    jmp_reg(&jmpasm, Reg64.Rax)
    for b, index in jmpasm.bytes {
        function.jmp_body.base[index] = b
    }
    for cb in codeblocks {
        if cb.stack.types != nil {
            delete(cb.stack.types)
        }
    }
    destroyasm(&a)
    delete(codeblocks)
    delete(blocks)
    return nil
}
JitErrorCode :: enum {
    NONE,
    NOT_ENOUGH_ITEMS_ON_STACK,
    TYPE_MISMATCH,
    UNDECLARED_LOCAL,
    UNKNOWN_TYPE,
    UNKNOWN_FUNCTION,
    UNKNOWN_FIELD,
    INVALID_INSTRUCTION_INDEX,
    TOO_MANY_ITEMS_ON_STACK,
    INVALID_STACK_ON_JUMP,
    NOT_ALL_CODE_PATHS_RETURNS,
}
JitError :: struct {
    error: JitErrorCode,
    module: string,
    function: string,
    instruction: Instruction,
    instructionIndex: int,
}
type_is_integer :: proc(t: ^Type) -> bool {
    if !type_is(PrimitiveType, t) {
        return false
    }
    prim := t.(PrimitiveType)
    #partial switch prim {
        case .I64, .I32, .I16, .U16, .I8, .U8, .U64, .U32:
            return true
        case: return false
    }
}
type_is_float :: proc(t: ^Type) -> bool {
    if !type_is(PrimitiveType, t) {
        return false
    }
    return t.(PrimitiveType) == PrimitiveType.F64 || t.(PrimitiveType) == PrimitiveType.F32
    
}
type_is_number :: proc(t: ^Type) -> bool {
    return type_is_integer(t) || type_is_float(t)
}
type_is_signedint :: proc(t: ^Type) -> bool {
    if !type_is(PrimitiveType, t) {
        return false
    }
    return t.(PrimitiveType) == PrimitiveType.I64 || t.(PrimitiveType) == PrimitiveType.I32 || t.(PrimitiveType) == PrimitiveType.I16 || t.(PrimitiveType) == PrimitiveType.I8 
}
type_is:: proc "c" ($type: typeid , t: ^Type) -> bool {
    _, ok := t.(type)
    return ok
}
type_is_primitive :: proc(t: ^Type, prim: PrimitiveType) -> bool {
    if !type_is(PrimitiveType, t) {
        return false
    }
    return t.(PrimitiveType) == prim
}
type_is_pointertype :: proc (t1: ^Type) -> bool {
    return (type_is(ArrayType, t1) || type_is(BoxedType, t1) || type_is_primitive(t1, PrimitiveType.Any) || type_is_primitive(t1, PrimitiveType.String))
}
type_equals :: proc "c" (t1: ^Type, t2: ^Type) -> bool {
//     context = ctx
    if t1 == t2 {
        return true
    }
    else if type_is(PrimitiveType, t1) && type_is(PrimitiveType, t2) {
        return t1.(PrimitiveType) == t2.(PrimitiveType)
    }
    else if type_is(ArrayType, t1) && type_is(ArrayType, t2) {
        return type_equals(t1.(ArrayType).underlaying, t2.(ArrayType).underlaying)
    }
    else if type_is(BoxedType, t1) && type_is(BoxedType, t2) {
        return type_equals(t1.(BoxedType).underlaying, t2.(BoxedType).underlaying)
    }
    else if type_is(RefType, t1) && type_is(RefType, t2) {
        return type_equals(t1.(RefType).underlaying, t2.(RefType).underlaying)
    }
    else if type_is(CustomType, t1) && type_is(CustomType, t2) {
        return t1 == t2 
    }
    return false
}
copy_stack :: proc(stack: TypeStack) -> TypeStack {
    res := TypeStack {
        types = make([dynamic]^Type, stack.count),
        count = stack.count,
    }
    for t, index in stack.types {
        res.types[index] = t
    }
    return res
}
check_if_all_code_paths_return_value :: proc(using function: ^Function, vm: ^VM, cb: ^CodeBlock, codeblocks: [dynamic]CodeBlock) -> bool {

    if cb.visited {
        return true
    }

    cb.visited = true
    last := cb.instructions[len(cb.instructions) - 1];
    if last.opcode == OpCode.Ret {
        return true
    }
    else if last.opcode == OpCode.Jmp {
        block: ^CodeBlock = nil
        for i in 0..<len(codeblocks) {
            bl := &codeblocks[i]
            if bl.start == cast(int)last.operand {
                block = bl
                break
            }
        }
        return check_if_all_code_paths_return_value(function, vm, block, codeblocks)
    }
    else if last.opcode == OpCode.Jtrue {
        block: ^CodeBlock = nil
        for i in 0..<len(codeblocks) {
            bl := &codeblocks[i]
            if bl.start == cast(int)last.operand {
                block = bl
                break
            }
        }
        next: ^CodeBlock = nil
        for i in 0..<len(codeblocks) {
            bl := &codeblocks[i]
            if bl.start == cb.start + cast(int)len(cb.instructions) {
                next = bl
                break
            }
        }
        if next == nil {
            fmt.println("FUCKSI")
            return false
        }
        blockres := check_if_all_code_paths_return_value(function, vm, block, codeblocks); 
        nextres := check_if_all_code_paths_return_value(function, vm, next, codeblocks) 
        return blockres && nextres
    }
    else {
        next: ^CodeBlock = nil
        for i in 0..<len(codeblocks) {
            bl := &codeblocks[i]
            if bl.start == cb.start + cast(int)len(cb.instructions) {
                next = bl
                break
            }
        }
        if next == nil {
            return false
        }
        return check_if_all_code_paths_return_value(function, vm, next, codeblocks) 
    }
    
}
calculate_stack :: proc(using function: ^Function, vm: ^VM, cb: ^CodeBlock, codeblocks: [dynamic]CodeBlock) -> Maybe(JitError) {
    resultStack := TypeStack {}
    if cb.stack.types != nil { 
        resultStack = copy_stack(cb.stack)
    }
    if cb.stack.types == nil {
        cb.stack.types = make([dynamic]^Type)
    }
    canEscape := true
    for instr, index in cb.instructions {
        switch instr.opcode {
        case .PushI64:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.I64])
        case .PushU64:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.U64])
        case .PushI32:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.I32])
        case .PushU32:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.U32])
        case .PushI16:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.I16])
        case .PushU16:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.U16])
        case .PushI8:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.I8])
        case .PushU8:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.U8])
        case .PushF32:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.F32])
        case .PushF64:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.F64])
        case .PushTrue:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Boolean])
        case .PushFalse:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Boolean])
        case .PushNull:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Any])
        case .PushChar:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Char])
        case .PushString:
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.String])
        case .ToRawPtr:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            } 
            t := stack_pop(&resultStack)
            if !type_is_pointertype(t) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.I64])
        case .Add, .Sub, .Mul, .Div:
            if resultStack.count < 2 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            } 
            t1 := stack_pop(&resultStack)
            t2 := stack_pop(&resultStack)
            if !type_equals(t1, t2) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is(PrimitiveType, t1) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is_number(t1) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            } 
            stack_push(&resultStack, t1)
        case .Pop:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            stack_pop(&resultStack)
        case .GT, .LT:
            if resultStack.count < 2 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            } 
            t1 := stack_pop(&resultStack)
            t2 := stack_pop(&resultStack)
            if !type_equals(t1, t2) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is(PrimitiveType, t1) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !(t1.(PrimitiveType) == PrimitiveType.I64 || t1.(PrimitiveType) == PrimitiveType.I32 || t1.(PrimitiveType) == PrimitiveType.F64 ||  t1.(PrimitiveType) == PrimitiveType.F32) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            } 
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Boolean])
        case .Not: 
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack)
            if !type_is(PrimitiveType, t) || t.(PrimitiveType) != PrimitiveType.Boolean {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, t)
        case .EQ:
            if resultStack.count < 2 { 
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            } 
            t1 := stack_pop(&resultStack)
            t2 := stack_pop(&resultStack)
            
            if !type_equals(t1, t2) && !(type_is_pointertype(t1) && type_is_pointertype(t2)){
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if type_is(PrimitiveType, t1) || type_is_pointertype(t1) {
                stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Boolean])
            }
            else {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
        case .Neg: 
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            } 
            t := stack_pop(&resultStack)
            if !type_is(PrimitiveType, t) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !(t.(PrimitiveType) == PrimitiveType.I64 || t.(PrimitiveType) == PrimitiveType.I32 || t.(PrimitiveType) == PrimitiveType.F64 ||  t.(PrimitiveType) == PrimitiveType.F32) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, t)
        case .PushLocal:
            if cast(int)instr.operand < len(function.args) {
                stack_push(&resultStack, function.args[cast(int)instr.operand])
            }
            else if cast(int)instr.operand - len(function.args) < len(function.locals) {
                stack_push(&resultStack, function.locals[cast(int)instr.operand - len(function.args)])
            }
            else {
                return undeclared_local(function.module.name, function.name, instr, cb.start + index)
            }
        case .SetLocal:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack)
            if cast(int)instr.operand < len(function.args) {
                if !type_equals(t, function.args[instr.operand]) {
                    return type_mismatch(function.module.name, function.name, instr, cb.start + index)
                }
            }
            else if cast(int)instr.operand - len(function.args) < len(function.locals) {
                if !type_equals(t, function.locals[cast(int)instr.operand - len(function.args)]) {
                    return type_mismatch(function.module.name, function.name, instr, cb.start + index)
                }
            }
            else 
            {
                return undeclared_local(function.module.name, function.name, instr, cb.start + index)
            }
        case .NewObj: 
            if cast(int)instr.operand >= len(function.module.typedescriptors) {
                return unknown_type(function.module.name, function.name, instr, cb.start + index)
            }
            descriptor := function.module.typedescriptors[instr.operand]
            if type_is(PrimitiveType, descriptor) || type_is(CustomType, descriptor) {
                stack_push(&resultStack, descriptor)
            }
            else if type_is(ArrayType, descriptor) {
                count := stack_pop(&resultStack)
                if !(type_is(PrimitiveType, count) && count.(PrimitiveType) == PrimitiveType.I64) {
                    return type_mismatch(function.module.name, function.name, instr, cb.start + index)
                }
                stack_push(&resultStack, descriptor)
            }
        case .Call:
            fn: ^Function = nil

            if cast(int)instr.operand < len(function.module.functionImports) {
                fn = function.module.functionImports[instr.operand]
            }
            else if cast(int)instr.operand - len(function.module.functionImports) < len(function.module.functions) {
                fn = function.module.functions[cast(int)instr.operand - len(function.module.functionImports)]
            }
            else
            {
                return unknown_function(function.module.name, function.name, instr, cb.start + index)
            }
            if len(fn.args) > resultStack.count {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            fmt.println(resultStack)
            fmt.println(fn.args)
            fmt.println(fn.name)

            for arg in fn.args {
                if !type_equals(arg, stack_pop(&resultStack)) {
                    return type_mismatch(function.module.name, function.name, instr, cb.start + index)
                }
            }
            if !type_equals(fn.retType, vm.primitiveTypes[PrimitiveType.Void]) {
                stack_push(&resultStack, fn.retType)
            }
        case .Jmp: 
            block: ^CodeBlock = nil
            for i in 0..<len(codeblocks) {
                bl := &codeblocks[i]
                if bl.start == cast(int)instr.operand {
                    block = bl
                    break
                }
            }
            if block == nil {
                return invalid_instruction_index(function.module.name, function.name, instr, cb.start + index) 
            }
            if block.stack.types == nil {
                block.stack = copy_stack(resultStack)
                err := calculate_stack(function, vm, block, codeblocks)
                if err != nil {
                    return err
                }
            }
            if !stack_equals(resultStack, block.stack) {
                return invalid_stack_on_jump(function.module.name, function.name, instr, cb.start + index)
            }
            canEscape = false
        case .Jtrue:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack)
            if !type_equals(t, vm.primitiveTypes[PrimitiveType.Boolean]) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            block: ^CodeBlock = nil
            for i in 0..<len(codeblocks) {
                bl := &codeblocks[i]
                if bl.start == cast(int)instr.operand {
                    block = bl
                    break
                }
            }
            if block == nil {
                return invalid_instruction_index(function.module.name, function.name, instr, cb.start + index) 
            }
            if block.stack.types == nil {
                block.stack = copy_stack(resultStack)
                err := calculate_stack(function, vm, block, codeblocks)
                if err != nil {
                    return err
                }
            }
            if !stack_equals(resultStack, block.stack) {
                return invalid_stack_on_jump(function.module.name, function.name, instr, cb.start + index)
            }
        case .Ret:
            canEscape = false
            if type_equals(function.retType, vm.primitiveTypes[PrimitiveType.Void]) {
                if resultStack.count != 0 {
                    return too_many_items_on_stack(function.module.name, function.name, instr, cb.start + index) 
                }
            }
            else {
                if resultStack.count == 0 {
                    return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
                }
                if resultStack.count > 1 {
                    return too_many_items_on_stack(function.module.name, function.name, instr, cb.start + index) 
                }
                type := stack_pop(&resultStack)
                if !type_equals(type, function.retType) {
                    return type_mismatch(function.module.name, function.name, instr, cb.start + index) 
                }
            }
        case .GetIndexRef:
            if resultStack.count < 2 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            indextype := stack_pop(&resultStack)
            arraytype := stack_pop(&resultStack)
            if !type_is(ArrayType, arraytype) || !type_is(PrimitiveType, indextype)  {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is_integer(indextype) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, make_ref(vm, arraytype.(ArrayType).underlaying))
        case .GetIndex:
            
            if resultStack.count < 2 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            indextype := stack_pop(&resultStack)
            arraytype := stack_pop(&resultStack)
            if !(type_is(ArrayType, arraytype) || type_is_primitive(arraytype, PrimitiveType.String)) || !type_is(PrimitiveType, indextype)  {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is_integer(indextype) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if type_is(ArrayType, arraytype) {
                stack_push(&resultStack, arraytype.(ArrayType).underlaying)
            } else {
                stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Char])
            }
        case .GetLength:
            if resultStack.count < 1 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            arr := stack_pop(&resultStack)
            if !type_is(ArrayType, arr) && !type_is_primitive(arr, PrimitiveType.String) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.I64])
        case .SetIndex:
            if resultStack.count < 3 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            indextype := stack_pop(&resultStack)
            arraytype := stack_pop(&resultStack)
            valuetype := stack_pop(&resultStack)
            if !type_is(ArrayType, arraytype) || !type_is(PrimitiveType, indextype)  {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is_integer(indextype) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_equals(valuetype, arraytype.(ArrayType).underlaying) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
        case .IsInstanceOf:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            if cast(int)instr.operand > len(function.module.typedescriptors) {
                return unknown_type(function.module.name, function.name, instr, cb.start + index)
            }
            obj := stack_pop(&resultStack)
            if !((type_is(PrimitiveType, obj) && obj.(PrimitiveType) == PrimitiveType.Any) || (type_is(ArrayType, obj) || type_is(BoxedType, obj))) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, vm.primitiveTypes[PrimitiveType.Boolean])
        case .GetFieldRef:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            object := stack_pop(&resultStack)
            type: ^CustomType = nil
            if type_is(BoxedType, object) && type_is(CustomType, object.(BoxedType).underlaying) {
                type = &object.(BoxedType).underlaying.(CustomType)
            }
            else if type_is(RefType, object) && type_is(CustomType, object.(RefType).underlaying) {
                type = &object.(RefType).underlaying.(CustomType)
            }
            else {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if cast(int)instr.operand > len(type.fields) {
                return unknown_field(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, make_ref(vm, type.fields[instr.operand].type));
        case .GetField:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            object := stack_pop(&resultStack)
            type: ^CustomType = nil
            if type_is(BoxedType, object) && type_is(CustomType, object.(BoxedType).underlaying) {
                type = &object.(BoxedType).underlaying.(CustomType)
            }
            else if type_is(RefType, object) && type_is(CustomType, object.(RefType).underlaying) {
                type = &object.(RefType).underlaying.(CustomType)
            }
            else {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if cast(int)instr.operand > len(type.fields) {
                return unknown_field(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, type.fields[instr.operand].type);
        case .SetField:
            if resultStack.count < 2 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            object := stack_pop(&resultStack)
            type: ^CustomType = nil
            if type_is(BoxedType, object) && type_is(CustomType, object.(BoxedType).underlaying) {
                type = &object.(BoxedType).underlaying.(CustomType)
            }
            else if type_is(RefType, object) && type_is(CustomType, object.(RefType).underlaying) {
                type = &object.(RefType).underlaying.(CustomType)
            }
            else {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if cast(int)instr.operand > len(type.fields) {
                return unknown_field(function.module.name, function.name, instr, cb.start + index)
            }
            value := stack_pop(&resultStack)
            if !type_equals(value, type.fields[instr.operand].type) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
        case .RefLocal:
            if cast(int)instr.operand < len(function.args) {
                stack_push(&resultStack, make_ref(vm, function.args[cast(int)instr.operand]))
            }
            else if cast(int)instr.operand - len(function.args) < len(function.locals) {
                stack_push(&resultStack, make_ref(vm, function.locals[cast(int)instr.operand - len(function.args)]))
            }
            else {
                return undeclared_local(function.module.name, function.name, instr, cb.start + index)
            }
        case .StoreRef:
            if resultStack.count < 2 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            refType := stack_pop(&resultStack)
            valueType := stack_pop(&resultStack)
            if !type_is(RefType, refType) || !type_equals(refType.(RefType).underlaying, valueType) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
        case .Deref: 
            if resultStack.count < 1 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            refType := stack_pop(&resultStack)
            if !type_is(RefType, refType) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack,refType.(RefType).underlaying)
        case .Dup:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack)
            stack_push(&resultStack, t)
            stack_push(&resultStack, t)
        case .Box:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack)
            if !(type_is(PrimitiveType, t) || type_is(CustomType, t)) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, make_box(vm, t))
        case .Unbox:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack);
            if !type_is(BoxedType, t) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, t.(BoxedType).underlaying)
        case .UnboxAs:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            if cast(int)instr.operand > len(function.module.typedescriptors) {
                return unknown_type(function.module.name, function.name, instr, cb.start + index)
            }
            casttype := function.module.typedescriptors[instr.operand]
            t := stack_pop(&resultStack);
            if !type_is(PrimitiveType, t) && t.(PrimitiveType) != PrimitiveType.Any {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, casttype)
        case .Cast:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            if cast(int)instr.operand > len(function.module.typedescriptors) {
                return unknown_type(function.module.name, function.name, instr, cb.start + index)
            }
            casttype := function.module.typedescriptors[instr.operand]
            if !type_is_pointertype(casttype){
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack);
            if !type_is_pointertype(t){
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, casttype)
        case .Conv:
            if resultStack.count == 0 {
                return not_enough_items_on_stack(function.module.name, function.name, instr, cb.start + index)
            }
            t := stack_pop(&resultStack)

            if cast(int)instr.operand > len(function.module.typedescriptors) {
                return unknown_type(function.module.name, function.name, instr, cb.start + index)
            }
            casttype := function.module.typedescriptors[instr.operand]
            if type_is_float(t) || type_is_float(casttype) {
                panic("NOT IMPLEMENTED")
            }
            if !type_is(PrimitiveType, t) || !type_is(PrimitiveType, casttype) {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is_number(t) && t.(PrimitiveType) != PrimitiveType.Boolean && t.(PrimitiveType) != PrimitiveType.Char {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            if !type_is_number(casttype) && casttype.(PrimitiveType) != PrimitiveType.Boolean && t.(PrimitiveType) != PrimitiveType.Char {
                return type_mismatch(function.module.name, function.name, instr, cb.start + index)
            }
            stack_push(&resultStack, casttype)
        }

    }
    if canEscape {
        block: ^CodeBlock = nil
        for i in 0..<len(codeblocks) {
            bl := &codeblocks[i]
            if bl.start == cast(int)cb.start + len(cb.instructions) {
                block = bl
                break
            }
        }
        if block != nil && block.stack.types == nil {
            block.stack = copy_stack(resultStack)
            return calculate_stack(function, vm, block, codeblocks)
        }
    }
    return nil
}
jit_error :: proc(error: JitErrorCode, module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return JitError {
        error = error,
        module = strings.clone(module),
        function = strings.clone(function),
        instruction = instruction,
        instructionIndex = index,
    }
}
type_mismatch :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.TYPE_MISMATCH, module, function, instruction, index)
}
not_enough_items_on_stack :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.NOT_ENOUGH_ITEMS_ON_STACK, module, function, instruction, index)
}
undeclared_local :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.UNDECLARED_LOCAL, module, function, instruction, index)
}
unknown_type :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.UNKNOWN_TYPE, module, function, instruction, index)
}
unknown_function :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.UNKNOWN_FUNCTION, module, function, instruction, index)
}
unknown_field:: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.UNKNOWN_FIELD, module, function, instruction, index)
}
invalid_instruction_index :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.INVALID_INSTRUCTION_INDEX, module, function, instruction, index)
}
too_many_items_on_stack :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.TOO_MANY_ITEMS_ON_STACK, module, function, instruction, index)
}
invalid_stack_on_jump :: proc(module: string, function: string, instruction: Instruction, index: int) -> JitError {
    return jit_error(JitErrorCode.INVALID_STACK_ON_JUMP, module, function, instruction, index)
}
not_all_code_paths_returns :: proc(module: string, function: string) -> JitError {
    return jit_error(JitErrorCode.NOT_ALL_CODE_PATHS_RETURNS, module, function, {}, 0)
}
MemBlock :: struct {
    base: [^]u8,
    size: uint,
}
alloc_executable :: proc(size: uint) -> MemBlock {
    when os.OS == runtime.Odin_OS_Type.Linux {
        base := transmute([^]u8)unix.sys_mmap(nil, size, unix.PROT_READ | unix.PROT_EXEC | unix.PROT_WRITE, unix.MAP_ANONYMOUS | unix.MAP_PRIVATE, -1, 0)
        return { base, size } 
    }
    else {
        data, err := virtual.memory_block_alloc(size, size, {})

        if err != virtual.Allocator_Error.None {
            panic("Failed to allocate executable memory")
        }
        ok := virtual.protect(data.base, data.reserved, { virtual.Protect_Flag.Read, virtual.Protect_Flag.Write, virtual.Protect_Flag.Execute})
        if !ok {
            panic("Failed to allocate executable memory")
        }
        return {data.base, size} 
    }

}
