package x86asm
import "core:fmt"
sub_reg8_reg8 :: proc(using assembler: ^Assembler, dest: Reg8, src: Reg8) {
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
    modrm: u8 = 0b11000000
    opcode: u8 = 0x28
    if cast(u8)src > 7 {
        prefix |= 0x44
    }
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    modrm |= (cast(u8)src % 8) << 3
    modrm |= (cast(u8)dest % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}
sub_reg16_reg16 :: proc(using assembler: ^Assembler, dest: Reg16, src: Reg16) {
    prefix: u8 = 0
    modrm: u8 = 0b11000000
    opcode: u8 = 0x29
    if cast(u8)src > 7 {
        prefix |= 0x44
    }
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    modrm |= (cast(u8)src % 8) << 3
    modrm |= (cast(u8)dest % 8)
    append(&bytes, 0x66)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}

sub_reg32_reg32 :: proc(using assembler: ^Assembler, dest: Reg32, src: Reg32) {
    prefix: u8 = 0
    modrm: u8 = 0b11000000
    opcode: u8 = 0x29
    if cast(u8)src > 7 {
        prefix |= 0x44
    }
    if cast(u8)dest > 7 {
        prefix |= 0x41
    }
    modrm |= (cast(u8)src % 8) << 3
    modrm |= (cast(u8)dest % 8)
    if prefix != 0 {
        append(&bytes, prefix)
    }
    append(&bytes, opcode)
    append(&bytes, modrm)
}
// sub dest, src
sub_reg_reg :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg64) {
    prefix: u8 = 0b01001000 
    modrm: u8 = 0b11000000
    opcode: u8 = 0x29
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
sub_reg_imm32 :: proc(using assembler: ^Assembler, dest: Reg64, imm: i32) {
    prefix: u8 = 0b01001000 
    modrm: u8 = 0b11101000
    opcode: u8 = 0x81
    if cast(u8)dest > 7 {
        prefix |= 1
    }
    modrm |= (cast(u8)dest % 8)
    append(&bytes, prefix)
    append(&bytes, opcode)
    append(&bytes, modrm)

    append(&bytes, cast(u8)(imm & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 1))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 2))) & 0xFF))
    append(&bytes, cast(u8)((imm >> ((8 * 3))) & 0xFF))
    
}
sub :: proc {sub_reg_reg, sub_reg8_reg8, sub_reg16_reg16, sub_reg32_reg32, sub_reg_imm32}
