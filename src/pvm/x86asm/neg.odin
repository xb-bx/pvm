package x86asm

neg_r8 :: proc(asmm: ^Assembler, reg: Reg8) {
    ireg := cast(int)reg
    if ireg >=4 && ireg <= 7 {
        append(&asmm.bytes, 0x40)
    }
    else if ireg > 15 {
        ireg -= 12
    }
    generic_instruction(asmm, nil, nil, 0xf6, 0b11011000 , ireg, 0, 0, 0, ModRmMode.MR)    
}
neg_r16 :: proc(asmm: ^Assembler, reg: Reg16) {
    generic_instruction(asmm, nil, 0x66, 0xf7, 0b11011000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
neg_r32 :: proc(asmm: ^Assembler, reg: Reg32) {
    generic_instruction(asmm, nil, nil, 0xf7, 0b11011000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
neg_r64 :: proc(asmm: ^Assembler, reg: Reg64) {
    generic_instruction(asmm, 0x48, nil, 0xf7, 0b11011000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
neg :: proc{neg_r8, neg_r16, neg_r32, neg_r64}
