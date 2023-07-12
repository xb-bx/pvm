package x86asm

mul_r8 :: proc(asmm: ^Assembler, reg: Reg8) {
    ireg := cast(int)reg
    if ireg >=4 && ireg <= 7 {
        append(&asmm.bytes, 0x40)
    }
    else if ireg > 15 {
        ireg -= 12
    }
    generic_instruction(asmm, nil, nil, 0xf6, 0b11100000 , ireg, 0, 0, 0, ModRmMode.MR)    
}

mul_r16 :: proc(asmm: ^Assembler, reg: Reg16) {
    generic_instruction(asmm, nil, 0x66, 0xf7, 0b11100000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
mul_r32 :: proc(asmm: ^Assembler, reg: Reg32) {
    generic_instruction(asmm, nil, nil, 0xf7, 0b11100000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
mul_r64 :: proc(asmm: ^Assembler, reg: Reg64) {
    generic_instruction(asmm, 0x48, nil, 0xf7, 0b11100000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
imul_r8 :: proc(asmm: ^Assembler, reg: Reg8) {
    ireg := cast(int)reg
    if ireg >=4 && ireg <= 7 {
        append(&asmm.bytes, 0x40)
    }
    else if ireg > 15 {
        ireg -= 12
    }
    generic_instruction(asmm, nil, nil, 0xf6, 0b11101000 , ireg, 0, 0, 0, ModRmMode.MR)    
}

imul_r16 :: proc(asmm: ^Assembler, reg: Reg16) {
    generic_instruction(asmm, nil, 0x66, 0xf7, 0b11101000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
imul_r32 :: proc(asmm: ^Assembler, reg: Reg32) {
    generic_instruction(asmm, nil, nil, 0xf7, 0b11101000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
imul_r64 :: proc(asmm: ^Assembler, reg: Reg64) {
    generic_instruction(asmm, 0x48, nil, 0xf7, 0b11101000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}


imul_reg64_reg64 :: proc(using assembler: ^Assembler, dest: Reg64, src: Reg64) {
    prefix: u8 = 0b01001000
    modrm: u8 = 0b11000000
    if cast(u8)dest > 7 {
        prefix |= 0b100
    }
    if cast(u8)src > 7 {
        prefix |= 1
    }
    modrm |= (cast(u8)dest % 8) << 3
    modrm |= (cast(u8)src % 8)
    append(&bytes, prefix)
    append(&bytes, 0x0f)
    append(&bytes, 0xaf)
    append(&bytes, modrm)
}
mul :: proc{mul_r8, mul_r16, mul_r32, mul_r64}
imul :: proc{imul_r8, imul_r16, imul_r32, imul_r64, imul_reg64_reg64}

