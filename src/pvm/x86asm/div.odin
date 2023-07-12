package x86asm

div_r8 :: proc(asmm: ^Assembler, reg: Reg8) {
    ireg := cast(int)reg
    if ireg >=4 && ireg <= 7 {
        append(&asmm.bytes, 0x40)
    }
    else if ireg > 15 {
        ireg -= 12
    }
    generic_instruction(asmm, nil, nil, 0xf6, 0b11110000 , ireg, 0, 0, 0, ModRmMode.MR)    
}

div_r16 :: proc(asmm: ^Assembler, reg: Reg16) {
    generic_instruction(asmm, nil, 0x66, 0xf7, 0b11110000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
div_r32 :: proc(asmm: ^Assembler, reg: Reg32) {
    generic_instruction(asmm, nil, nil, 0xf7, 0b11110000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
div_r64 :: proc(asmm: ^Assembler, reg: Reg64) {
    generic_instruction(asmm, 0x48, nil, 0xf7, 0b11110000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
idiv_r8 :: proc(asmm: ^Assembler, reg: Reg8) {
    ireg := cast(int)reg
    if ireg >=4 && ireg <= 7 {
        append(&asmm.bytes, 0x40)
    }
    else if ireg > 15 {
        ireg -= 12
    }
    generic_instruction(asmm, nil, nil, 0xf6, 0b11111000 , ireg, 0, 0, 0, ModRmMode.MR)    
}

idiv_r16 :: proc(asmm: ^Assembler, reg: Reg16) {
    generic_instruction(asmm, nil, 0x66, 0xf7, 0b11111000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
idiv_r32 :: proc(asmm: ^Assembler, reg: Reg32) {
    generic_instruction(asmm, nil, nil, 0xf7, 0b11111000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}
idiv_r64 :: proc(asmm: ^Assembler, reg: Reg64) {
    generic_instruction(asmm, 0x48, nil, 0xf7, 0b11111000 , cast(int)reg, 0, 0, 0, ModRmMode.MR)    
}


div :: proc{div_r8, div_r16, div_r32, div_r64}
idiv :: proc{idiv_r8, idiv_r16, idiv_r32, idiv_r64}

