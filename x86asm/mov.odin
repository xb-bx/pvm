package x86asm
import "core:fmt"
// mov [dest + disp], src
mov_reg64_to :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg64, disp: i32 = 0) {
    rex: u8 = 0b01001000
    if cast(u8)dest > 7 
    {
        rex |= 0b1
    }
    if cast(u8)src > 7 
    {
        rex |= 0b100
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    modrm |= (cast(u8)dest % 8)
    modrm |= (cast(u8)src % 8) << 3
    append(&bytes, rex)
    append(&bytes, 0x89)
    append(&bytes, modrm)
    if dest == Reg64.Rsp || dest == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov dest, byte[src]
mov_reg8_from :: proc(using assembler: ^Assembler, dest: Reg8, src: Reg64, disp: i32 = 0) {
    prefix: u8 = 0  
    desti := cast(u8)dest
    srci := cast(u8)src
    if srci >= cast(u8)Reg64.R8 && desti >= cast(u8)Reg8.Ah  {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil {
        prefix = 0x40
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    if desti > 7 
    {
        prefix |= 0x44 
    }
    if srci > 7 
    {
        prefix |= 0x41 
    }
    modrm |= (cast(u8)dest % 8) << 3
    modrm |= (cast(u8)src % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x8a)
    append(&bytes, modrm)

    if src == Reg64.Rsp || src == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov byte[dest], src
mov_reg8_to :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg8, disp: i32 = 0) {
    prefix: u8 = 0  
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti >= cast(u8)Reg64.R8 && srci >= cast(u8)Reg8.Ah  {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil {
        prefix = 0x40
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    if desti > 7 {
        prefix |= 0x41
    }
    modrm |= desti % 8
    if srci > 7 {
        prefix |= 0x44
    }
    modrm |= (srci % 8) << 3
    if prefix > 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x88)
    append(&bytes, modrm)
    if dest == Reg64.Rsp || dest == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
    
}
//mov dest, [src + disp] 
mov_reg64_from :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg64, disp: i32 = 0) {
    rex: u8 = 0b01001000
    if cast(u8)dest > 7 
    {
        rex |= 0b100
    }
    if cast(u8)src > 7 
    {
        rex |= 0b001
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    modrm |= (cast(u8)dest % 8) << 3
    modrm |= (cast(u8)src % 8)
    append(&bytes, rex)
    append(&bytes, 0x8b)
    append(&bytes, modrm)

    if src == Reg64.Rsp || src == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov dest, src
mov_reg64_reg64 :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg64) {
    prefix: u8 = 0b01001000 
    modrm: u8 = 0b11000000
    opcode: u8 = 0x89
    if cast(u8)src > 7 {
        prefix |= 0b100
    }
    if cast(u8)dest > 7 {
        prefix |= 1
    }
    modrm |= (cast(u8)src % 8) << 3
    modrm |= (cast(u8)dest % 8)
    append(&bytes, prefix)
    append(&bytes, opcode)
    append(&bytes, modrm)
}
// mov dest, imm
mov_reg64_imm :: proc(using assembler: ^Assembler, dest: Reg64, imm: u64) {
    prefix: u8 = 0b01001000 
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    opcode: u8 = 0xb8
    opcode |= (cast(u8)dest % 8)  
    append(&bytes, prefix)
    append(&bytes, opcode)
    append(&bytes, cast(u8)(imm & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 1))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 2))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 3))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 4))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 5))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 6))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 7))) & 0xFF))
}
mov_reg8_imm :: proc(using assembler: ^Assembler, dest: Reg8, imm: u8) {
    prefix: u8 = 0
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    opcode: u8 = 0xb0
    opcode |= (cast(u8)dest % 8)  
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, cast(u8)(imm & 0xFF))
}
mov_reg16_imm :: proc(using assembler: ^Assembler, dest: Reg16, imm: u16) {
    prefix: u8 = 0
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    opcode: u8 = 0xb8
    opcode |= (cast(u8)dest % 8)  
    append(&bytes, 0x66)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, cast(u8)(imm & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 1))) & 0xFF))
}
mov_reg32_imm :: proc(using assembler: ^Assembler, dest: Reg32, imm: u32) {
    prefix: u8 = 0
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    opcode: u8 = 0xb8
    opcode |= (cast(u8)dest % 8)  
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, cast(u8)(imm & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 1))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 2))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 3))) & 0xFF))
}
mov :: proc{mov_reg64_reg64, mov_reg64_imm, mov_reg32_reg32, mov_reg32_imm, mov_reg16_imm, mov_reg16_reg16, mov_reg8_imm, mov_reg8_reg8}
mov_to :: proc { mov_reg8_to, mov_reg16_to, mov_reg32_to, mov_reg64_to }
mov_from :: proc { mov_reg8_from, mov_reg16_from, mov_reg32_from, mov_reg64_from }

// mov dest, src
mov_reg8_reg8 :: proc(using assebler: ^Assembler, dest: Reg8, src: Reg8) {
    desti := cast(u8)dest
    srci := cast(u8)src
    prefix:u8 = 0
    if (desti >= cast(u8)Reg8.Ah && srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil) || 
    (srci >= cast(u8)Reg8.Ah && desti >= cast(u8)Reg8.Spl && desti <= cast(u8)Reg8.Dil) || 
    (srci > 7 && desti >= cast(u8)Reg8.Ah) || (desti > 7 && srci >= cast(u8)Reg8.Ah) {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if (srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil) || (desti >= cast(u8)Reg8.Spl && desti <= cast(u8)Reg8.Dil) {
        prefix = 0x40
    }  
    if srci >= cast(u8)Reg8.Ah {
        srci -= 12
    }
    if desti >= cast(u8)Reg8.Ah {
        desti -= 12
    }
    modrm:u8 = 0b11000000
    if srci > 7 {
        prefix |= 0x44
    }
    modrm |= (srci % 8) << 3
    if desti > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8)
    opcode: u8 = 0x88
    if prefix > 0  {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}
// mov word[src], dest
mov_reg16_to:: proc(using assembler: ^Assembler, dest: Reg64, src: Reg16, disp: i32 = 0) {
    prefix: u8 = 0
    if cast(u8)dest > 7 
    {
        prefix |= 0x41
    }
    if cast(u8)src > 7 
    {
        prefix |= 0x44
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    modrm |= (cast(u8)dest % 8)
    modrm |= (cast(u8)src % 8) << 3
    append(&bytes, 0x66)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x89)
    append(&bytes, modrm)

    if dest == Reg64.Rsp || dest == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov dest, word[src]
mov_reg16_from :: proc(using assembler: ^Assembler, dest: Reg16, src: Reg64, disp: i32 = 0) {
    prefix: u8 = 0
    if cast(u8)dest > 7 
    {
        prefix |= 0x44
    }
    if cast(u8)src > 7 
    {
        prefix |= 0x41
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    modrm |= (cast(u8)dest % 8) << 3
    modrm |= (cast(u8)src % 8)
    append(&bytes, 0x66)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x8b)
    append(&bytes, modrm)

    if src == Reg64.Rsp || src == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov dest, src
mov_reg16_reg16 :: proc (using assembler: ^Assembler, dest: Reg16, src: Reg16) {
    desti := cast(u8)dest
    srci := cast(u8)src
    prefix:u8 = 0
    if srci >= cast(u8)Reg8.Ah {
        fmt.println(srci)
        srci -= 12
        fmt.println(srci)
    }
    if desti >= cast(u8)Reg8.Ah {
        desti -= 12
    }
    modrm:u8 = 0b11000000
    if srci > 7 {
        prefix |= 0x44
    }
    modrm |= (srci % 8) << 3
    if desti > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8)
    opcode: u8 = 0x89
    append(&bytes, 0x66)
    if prefix > 0  {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}
// mov dword[src], dest
mov_reg32_to:: proc(using assembler: ^Assembler, dest: Reg64, src: Reg32, disp: i32 = 0) {
    prefix: u8 = 0
    if cast(u8)dest > 7 
    {
        prefix |= 0x41
    }
    if cast(u8)src > 7 
    {
        prefix |= 0x44
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    modrm |= (cast(u8)dest % 8)
    modrm |= (cast(u8)src % 8) << 3
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x89)
    append(&bytes, modrm)

    if dest == Reg64.Rsp || dest == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov dest, dword[src]
mov_reg32_from :: proc(using assembler: ^Assembler, dest: Reg32, src: Reg64, disp: i32 = 0) {
    prefix: u8 = 0
    if cast(u8)dest > 7 
    {
        prefix |= 0x44
    }
    if cast(u8)src > 7 
    {
        prefix |= 0x41
    }
    modrm: u8 = 0
    is8bitDisp := false
    if abs(disp) <= 127 
    {
        modrm = 0b01000000
        is8bitDisp = true
    }
    else 
    {
        modrm = 0b10000000
    }
    modrm |= (cast(u8)dest % 8) << 3
    modrm |= (cast(u8)src % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x8b)
    append(&bytes, modrm)

    if src == Reg64.Rsp || src == Reg64.R12 {
        append(&bytes, 0x24)
    }
    if is8bitDisp 
    {
        append(&bytes, cast(u8)disp)
    } 
    else 
    {
        append(&bytes, cast(u8)(disp))
        append(&bytes, cast(u8)(disp >> (8 * 1)))
        append(&bytes, cast(u8)(disp >> (8 * 2)))
        append(&bytes, cast(u8)(disp >> (8 * 3)))
    }
}
// mov dest, src
mov_reg32_reg32 :: proc (using assembler: ^Assembler, dest: Reg32, src: Reg32) {
    desti := cast(u8)dest
    srci := cast(u8)src
    prefix:u8 = 0
    if srci >= cast(u8)Reg8.Ah {
        fmt.println(srci)
        srci -= 12
        fmt.println(srci)
    }
    if desti >= cast(u8)Reg8.Ah {
        desti -= 12
    }
    modrm:u8 = 0b11000000
    if srci > 7 {
        prefix |= 0x44
    }
    modrm |= (srci % 8) << 3
    if desti > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8)
    opcode: u8 = 0x89
    if prefix > 0  {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}
movzx_reg32_reg16 :: proc(using assembler: ^Assembler, dest: Reg32, src: Reg16) {
    prefix: u8 = 0
    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x0f)
    append(&bytes, 0xb7)
    append(&bytes, modrm)
}
movzx_reg32_reg8 :: proc(using assembler: ^Assembler, dest: Reg32, src: Reg8) {
    prefix: u8 = 0
    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti >= cast(u8)Reg32.R8d && srci >= cast(u8)Reg8.Ah  {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil {
        prefix = 0x40
    }
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x0f)
    append(&bytes, 0xb6)
    append(&bytes, modrm)
}
movzx_reg16_reg8 :: proc(using assembler: ^Assembler, dest: Reg16, src: Reg8) {
    prefix: u8 = 0
    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti >= cast(u8)Reg32.R8d && srci >= cast(u8)Reg8.Ah  {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil {
        prefix = 0x40
    }
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    append(&bytes, 0x66)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x0f)
    append(&bytes, 0xb6)
    append(&bytes, modrm)
}
movzx :: proc { movzx_reg32_reg8, movzx_reg16_reg8, movzx_reg32_reg16 }
movsx_reg16_reg8 :: proc(using assembler: ^Assembler, dest: Reg16, src: Reg8) {
    prefix: u8 = 0
    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti >= cast(u8)Reg32.R8d && srci >= cast(u8)Reg8.Ah  {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil {
        prefix = 0x40
    }
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    append(&bytes, 0x66)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x0f)
    append(&bytes, 0xbe)
    append(&bytes, modrm)
}
movsx_reg32_reg8 :: proc(using assembler: ^Assembler, dest: Reg32, src: Reg8, wide: bool = false) {
    prefix:u8 = wide ? 0x48 : 0 
    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if (desti >= cast(u8)Reg32.R8d || prefix != 0) && srci >= cast(u8)Reg8.Ah  {
        panic(fmt.aprintf("Cant encode both %v and %v", dest, src))
    }
    if srci >= cast(u8)Reg8.Spl && srci <= cast(u8)Reg8.Dil {
        prefix = 0x40
    }
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x0f)
    append(&bytes, 0xbe)
    append(&bytes, modrm)
}
movsx_reg32_reg16 :: proc(using assembler: ^Assembler, dest: Reg32, src: Reg16, wide: bool = false) {
    prefix:u8 = wide ? 0x48 : 0 
    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, 0x0f)
    append(&bytes, 0xbf)
    append(&bytes, modrm)
}
movsx_reg64_reg16 :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg16) {
    movsx_reg32_reg16(assembler, cast(Reg32)dest, src, true)
}
movsx_reg64_reg8 :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg8) {
    movsx_reg32_reg8(assembler, cast(Reg32)dest, src, true)
}
movsx_reg64_reg32 :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg32) {
    prefix: u8 = 0x48

    modrm: u8 = 0b11000000
    desti := cast(u8)dest
    srci := cast(u8)src
    if desti > 7 {
        prefix |= 0x44
    } 
    if srci > 7 {
        prefix |= 0x41
    }
    modrm |= (desti % 8) << 3
    modrm |= (srci % 8)
    append(&bytes, prefix)
    append(&bytes, 0x63)
    append(&bytes, modrm)
}

movsx :: proc { movsx_reg64_reg8, movsx_reg32_reg8, movsx_reg64_reg16, movsx_reg32_reg16, movsx_reg16_reg8, movsx_reg64_reg32 }
