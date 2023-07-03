package disasm
import "core:fmt"
import "core:os"
import "core:strings"
import "../pvm"

main :: proc() {
    if len(os.args) <= 2 {
        return
    }
    using pvm    
    vm := initvm()
    module, err := load_module(&vm, os.args[1])
    if _, ok := err.(None); !ok {
        fmt.println(err)
        return
    }
    fnname := os.args[2]
    fn: ^Function = nil
    for tfn in module.functions {
        if tfn.name == fnname {
            fn = tfn
            break
        }
    }
    if fn == nil {
        fmt.println("Function not found")
        return
    }
    for instruction, index in fn.instructions {
        fmt.printf("OP_%3i: %v ", index, instruction.opcode) 
        #partial switch instruction.opcode {
            case .PushI8:
                fmt.printf("%i", cast(i8)(instruction.operand))
            case .PushI16:
                fmt.printf("%i", cast(i16)(instruction.operand))
            case .PushI32:
                fmt.printf("%i", cast(i32)(instruction.operand))
            case .PushI64:
                fmt.printf("%i", transmute(i64)(instruction.operand))
            case .PushU8, .PushU16, .PushU32, .PushU64, .PushLocal, .SetLocal:
                fmt.printf("%i", (instruction.operand))
            case .Jmp, .Jtrue:
                fmt.printf("OP_%3i", (instruction.operand))
            case .Call:
                callTarget: ^Function = nil
                if cast(int)instruction.operand < len(module.functionImports) {
                    callTarget = module.functionImports[instruction.operand]
                }
                else {
                    callTarget = module.functions[cast(int)instruction.operand - len(module.functionImports)]
                }
                fmt.printf("%s.%s", callTarget.module.name, callTarget.name)
            case .PushString:
                str := module.strings[instruction.operand]
                s := strings.string_from_ptr(transmute(^byte)(transmute(int)str + size_of(StringObject)), cast(int)str.length * 2)
                s, _ = strings.replace_all(s, "\n", "\\n")
                fmt.printf("\"%s\"", s)
            case .PushChar:
                r := cast(rune)instruction.operand
                if r == '\n' {
                    fmt.print("'\\n'")
                }
                else {
                    fmt.printf("'%c'", r)
                }
            case .NewObj, .Cast, .IsInstanceOf, .Conv:
                type: ^Type= nil
                if cast(int)instruction.operand < len(module.typeImports) {
                    type = module.typeImports[instruction.operand]
                }
                else {
                    type = module.typedescriptors[cast(int)instruction.operand - len(module.typeImports)]
                }
                fmt.print(type^)
                
        }
        fmt.print("\n")
    }



    
}