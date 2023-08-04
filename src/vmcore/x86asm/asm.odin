package x86asm 
import "core:fmt"
import "core:math"
Label :: struct {
    id: int,
    offset: int,
}
Tuple :: struct($T1, $T2: typeid) {
    first: T1,
    second: T2,
}
tuple :: proc(fst: $T1, snd: $T2) -> Tuple(T1, T2) {
    return Tuple(T1, T2) { first = fst, second = snd }
}
Assembler :: struct {
    bytes: [dynamic]u8,
    labels: [dynamic]Label,
    labelplaces: [dynamic]Tuple(int, int),
}
initasm :: proc() -> Assembler {
    return Assembler {
        bytes = make([dynamic]u8, 0, 128),
        labels = make([dynamic]Label, 0, 16),
        labelplaces = make([dynamic]Tuple(int, int), 0, 16),
    }
}
destroyasm :: proc(using assembler: ^Assembler) {
    delete(bytes)
    delete(labels)
    delete(labelplaces)
}
create_label :: proc(using assembler: ^Assembler) -> Label {
    lbl := Label { id = len(labels), offset = 0 }
    append(&labels, lbl)
    return lbl
}
set_label :: proc(using assembler: ^Assembler, lbl: Label) {
    lbl := &labels[lbl.id]    
    lbl.offset = len(bytes)
}
jmp :: proc(using assembler: ^Assembler, lbl: Label) {
    append(&bytes, 0xe9)
    place := len(bytes)
    append(&bytes, 0)
    append(&bytes, 0)
    append(&bytes, 0)
    append(&bytes, 0)
    append(&labelplaces, tuple(lbl.id, place))
}
// j<cond> lbl
jcc :: proc(using assembler: ^Assembler, cond: u8, lbl: Label) {
    append(&bytes, 0x0f)
    append(&bytes, cond)
    place := len(bytes)
    append(&bytes, 0)
    append(&bytes, 0)
    append(&bytes, 0)
    append(&bytes, 0)
    append(&labelplaces, tuple(lbl.id, place))
}
je :: proc(using assembler: ^Assembler, lbl: Label) {
    jcc(assembler, 0x84, lbl)
}
jne :: proc(using assembler: ^Assembler, lbl: Label) {
    jcc(assembler, 0x85, lbl)
}
jlt :: proc(using assembler: ^Assembler, lbl: Label) {
    jcc(assembler, 0x8c, lbl)
}
jgt :: proc(using assembler: ^Assembler, lbl: Label) {
    jcc(assembler, 0x8f, lbl)
}
jge :: proc(using assembler: ^Assembler, lbl: Label) {
    jcc(assembler, 0x8d, lbl)
}
call_reg :: proc(using assembler: ^Assembler, reg: Reg64) {
    if cast(u8)reg > 7 {
        append(&bytes, 0x41) 
    }
    append(&bytes, 0xff)
    append(&bytes, 0xd0 | (cast(u8)reg % 8))
}
call_at_reg :: proc(using assembler: ^Assembler, reg: Reg64) {
    if cast(u8)reg > 7 {
        append(&bytes, 0x41) 
    }
    append(&bytes, 0xff)
    if reg == Reg64.Rsp || reg == Reg64.R12 {
        append(&bytes, 0x14)    
        append(&bytes, 0x24)    
    }
    else if reg == Reg64.Rbp || reg == Reg64.R13 {
        append(&bytes, 0x55)    
        append(&bytes, 0x0)    
    }
    else {
        append(&bytes, 0x10 | (cast(u8)reg % 8))
    }
}
// jmp [reg]
jmp_reg :: proc(using assembler: ^Assembler, reg: Reg64) {
    if cast(u8)reg > 7 {
        append(&bytes, 0x41) 
    }
    append(&bytes, 0xff)
    if reg == Reg64.Rsp || reg == Reg64.R12 {
        append(&bytes, 0x24)    
        append(&bytes, 0x24)    
    }
    else if reg == Reg64.Rbp || reg == Reg64.R13 {
        append(&bytes, 0x65)    
        append(&bytes, 0x0)    
    }
    else {
        append(&bytes, 0x20 | (cast(u8)reg % 8))
    }
}
//cmp r1, r2
cmp_reg8_reg8 :: proc(using assembler: ^Assembler, r1: Reg8, r2: Reg8) {
    prefix: u8 = 0 
    modrm: u8 = 0b11000000
    opcode: u8 = 0x38
    desti := cast(u8)r1
    srci := cast(u8)r2
    if (desti >= cast(u8)Reg8.Ah && srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil) || 
    (srci >= cast(u8)Reg8.Ah && desti >= cast(u8)Reg8.Spl && desti <= cast(u8)Reg8.Dil) || 
    (srci > 7 && desti >= cast(u8)Reg8.Ah) || (desti > 7 && srci >= cast(u8)Reg8.Ah) {
        panic(fmt.aprintf("Cant encode both %v and %v", r1, r2))
    }
    if (srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil) || (desti >= cast(u8)Reg8.Spl && desti <= cast(u8)Reg8.Dil) {
        prefix = 0x40
    }  
    if cast(u8)r2 > 7 
    {
        prefix |= 0x44
    }
    if srci >= cast(u8)Reg8.Ah {
        srci -= 12
    }
    if desti >= cast(u8)Reg8.Ah {
        desti -= 12
    }
    if cast(u8)r1 > 7
    {
        prefix |= 0x41
    }
    modrm |= ((cast(u8)r2 % 8) << 3)  
    modrm |= (cast(u8)r1 % 8)  
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}
//cmp r1, r2
cmp_reg16_reg16 :: proc(using assembler: ^Assembler, r1: Reg16, r2: Reg16) {
    generic_instruction(assembler, nil, 0x66, 0x39, 0b11000000, cast(int)r1, cast(int)r2, 0, 0, ModRmMode.MR)
}
//cmp r1, r2
cmp_reg32_reg32 :: proc(using assembler: ^Assembler, r1: Reg32, r2: Reg32) {
    generic_instruction(assembler, nil, nil, 0x39, 0b11000000, cast(int)r1, cast(int)r2, 0, 0, ModRmMode.MR)
}
//cmp r1, r2
cmp_reg64_reg64 :: proc(using assembler: ^Assembler, r1: Reg64, r2: Reg64) {
    generic_instruction(assembler, 0x48, nil, 0x39, 0b11000000, cast(int)r1, cast(int)r2, 0, 0, ModRmMode.MR)
}
cmp :: proc {cmp_reg64_reg64, cmp_reg8_reg8, cmp_reg16_reg16, cmp_reg32_reg32 }
pop_reg64 :: proc(using assembler: ^Assembler, reg: Reg64) {
    generic_instruction(assembler, nil, nil, 0x8f, 0b11000000, cast(int)reg, 0, 0, 0, ModRmMode.MI) 
}
pop :: proc{pop_reg64}
push_reg64 :: proc(using assembler: ^Assembler, reg: Reg64) {
    generic_instruction(assembler, nil, nil, 0xff, 0b11110000, cast(int)reg, 0, 0, 0, ModRmMode.MI) 
}
push_imm :: proc (using assembler: ^Assembler, imm: u32) 
{
    append(&bytes, 0x68)
    append(&bytes, cast(u8)(imm))
    append(&bytes, cast(u8)(imm >> ((8 * 1))))
    append(&bytes, cast(u8)(imm >> ((8 * 2))))
    append(&bytes, cast(u8)(imm >> ((8 * 3))))
}
push :: proc{push_reg64, push_imm}



ret :: proc(using assembler: ^Assembler) {
    append(&bytes, 0xc3)
}
int3 :: proc(using assembler: ^Assembler) {
    append(&bytes, 0xcc)
}
assemble :: proc(using assebler: ^Assembler) {
    for place in labelplaces {
        lbl := labels[place.first]
        offset := lbl.offset - ((place.second) + 4)
        bytes[place.second + 3] = cast(u8)(offset >> 24)
        bytes[place.second + 2] = cast(u8)(offset >> 16)
        bytes[place.second + 1] = cast(u8)(offset >> 8)
        bytes[place.second + 0] = cast(u8)(offset)
    }
}






Reg64 :: enum {
    Rax = 0,
    Rcx,
    Rdx,
    Rbx,
    Rsp,
    Rbp,
    Rsi,
    Rdi,
    R8,
    R9,
    R10,
    R11,
    R12,
    R13,
    R14,
    R15,
}
Reg32 :: enum {
    Eax = 0,
    Ecx,
    Edx,
    Ebx,
    Esp,
    Ebp,
    Esi,
    Edi,
    R8d,
    R9d,
    R10d,
    R11d,
    R12d,
    R13d,
    R14d,
    R15d,
}
Reg16 :: enum {
    Ax = 0,
    Cx,
    Dx,
    Bx,
    Sp,
    Bp,
    Si,
    Di,
    R8w,
    R9w,
    R10w,
    R11w,
    R12w,
    R13w,
    R14w,
    R15w,
}
Reg8 :: enum {
    Al,
    Cl,
    Dl,
    Bl,
    Spl,
    Bpl,
    Sil,
    Dil,
    R8b,
    R9b,
    R10b,
    R11b,
    R12b,
    R13b,
    R14b,
    R15b,
    Ah,
    Ch,
    Dh,
    Bh,
}
ModRmMode :: enum {
    MI,
    MR,
    RM,
}
generic_instruction :: proc(using asmm: ^Assembler, rex: Maybe(u8) = nil, old_prefix: Maybe(u8) = nil, opcode: u8, modrm: u8, reg1: int, reg2: int, imm: int, imm_size: int, modrmmode: ModRmMode) {
    rex := rex.? or_else 0x40
    reg1 := reg1
    reg2 := reg2
    imm := imm
    modrm := modrm
    if modrmmode == ModRmMode.MI || modrmmode == ModRmMode.MR {
        if reg1 >= 8 {
            rex |= 1 
        }
        reg1 = reg1 & 7
        modrm |= cast(u8)reg1
        if modrmmode == ModRmMode.MR {
            if reg2 >= 8 {
                rex |= 0b100
            }
            reg2 = reg2 & 7
            modrm |= cast(u8)reg2 << 3
        }
    }
    else {
        if reg1 >= 8 {
            rex |= 0b100 
        }
        reg1 = reg1 & 7
        modrm |= cast(u8)reg1 << 3
        if reg2 >= 8 {
            rex |= 1 
        }
        reg2 = reg2 & 7
        modrm |= cast(u8)reg2
    }
    if old, ok := old_prefix.?; ok {
        append(&asmm.bytes, old)
    }
    if rex != 0x40 {
        append(&asmm.bytes, rex)
    }
    append(&asmm.bytes, opcode)
    append(&asmm.bytes, modrm)
    if modrmmode == ModRmMode.MI {
        for i in 0..=imm_size-1 {
            append(&asmm.bytes, cast(u8)(imm & 0xff))
            imm >>= 8
        }
    }
}
