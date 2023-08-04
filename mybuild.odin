package nobuild
import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:odin/ast"
import "core:slice"
econio_lib := ""
asm_bin := ""
generate_bindings :: proc() {
    entries := (directory_entries("src/modules"))
    for entry in entries {
        if entry.is_dir {
            generate_binding(entry.fullpath)
        }
    }

}
generate_binding :: proc(path: string) {
    bindingsname := strings.concatenate([]string{path, "/binding.odin"})
    if os.exists(bindingsname) {
        os.remove(bindingsname) 
    }
    pkg, ok := parser.parse_package_from_path(path)
    builder: strings.Builder = {}
    strings.builder_init(&builder)
    fmt.sbprintf(&builder, "package %s\n", filepath.base(path))
    strings.write_string(&builder, "import \"core:fmt\"\n")
    strings.write_string(&builder, "import \"../../vmcore\"\n")
    strings.write_string(&builder, "__bind :: proc(vmp: ^vmcore.VM) {\n")
    strings.write_string(&builder, "    vm = vmp\n")
    fmt.sbprintf(&builder, "    mod, is_mod_found := vm.modules[\"%s\"]\n", filepath.base(path))
    fmt.sbprintf(&builder, "    if !is_mod_found {{ fmt.println(\"Failed to bind module \\\"%s\\\" \"); return }}\n", filepath.base(path))
    fmt.sbprintf(&builder, "    for fn in mod.functions {{\n")
    for name, file in pkg.files {
        for decl in file.decls {
            if val, isval := decl.derived_stmt.(^ast.Value_Decl); isval {
                if len(val.values) != 1 { 
                    continue
                }
                if proclit, is_proc := val.values[0].derived_expr.(^ast.Proc_Lit); is_proc {
                    namenode :=val.names[0]
                    procname, res := strings.cut(file.src, namenode.pos.offset, namenode.end.offset - namenode.pos.offset)
                    fmt.sbprintf(&builder, "        if fn.name == \"%s\" {{ vmcore.replace_body(transmute(u64)%s, fn) }}\n", procname, procname)
                }
            }
        }
    }
    fmt.sbprintf(&builder, "    }}\n")
    fmt.sbprintf(&builder, "}}\n")
    res := strings.to_string(builder)
    written := os.write_entire_file(bindingsname, slice.bytes_from_ptr(raw_data(res), len(res)))
    
}
main :: proc() {
    generate_bindings()
    when ODIN_OS == .Windows {
        econio_lib = "econio.lib"
        asm_bin = "asm.exe"
    } else {
        econio_lib = "econio.a"
        asm_bin = "asm.bin"
    }
    if len(os.args) == 1 {
        build_all()
        return
    }
    else {
        switch os.args[1] {
            case "programs": 
                build_programs()
            case "pasm": 
                build_pasm()
            case "disasm":
                build_disasm()
            case "pvm":
                build_pvm()
            case:
                fmt.println("Unknown option")
        }
    }
}
build_all :: proc() {
    if !os.exists("c-econio") {
        run("git", "clone", "https://github.com/czirkoszoltan/c-econio")
    }
    if !os.exists(concat("src/", econio_lib)) {
        cd("c-econio")
        when ODIN_OS == .Windows {
            run("cl", "-TC", "-c", "econio.c")
            run("lib", "-nologo", "econio.obj", "-out:econio.lib")
        } else {
            run("gcc", "-c", "econio.c")
            run("ar", "rcs", "econio.a", "econio.o")
        }
        cp(econio_lib, "../src")
        cd("..")
    }
    build_pvm()
    build_pasm() 
    build_disasm()
    build_programs()
}
build_disasm :: proc() {
    cd("./src")
    when ODIN_OS == .Windows do output :: "disasm.exe"
    else do output :: "disasm.bin"
    run("odin", "build", "disasm", concat("-extra-linker-flags:", econio_lib), "-out:" + output)
    cp(output, "..")
    cd("..")
    when ODIN_OS == .Linux do run("chmod", "+x", output)
}
build_pasm :: proc() {
    cd("./src")
    when ODIN_OS == .Windows do output :: "asm.exe"
    else do output :: "asm.bin"
    run("odin", "build", "asm", concat("-extra-linker-flags:", econio_lib), "-out:" + output)
    cp(output, "..")
    cd("..")
    when ODIN_OS == .Linux do run("chmod", "+x", output)
}
build_pvm :: proc() {
    cd("./src")
    when ODIN_OS == .Windows do output :: "pvm.exe"
    else do output :: "pvm.bin"
    run("odin", "build", "pvm", concat("-extra-linker-flags:", econio_lib), "-out:" + output)
    cp(output, "..")
    cd("..")
    when ODIN_OS == .Linux do run("chmod", "+x", output)
}
build_programs :: proc() {
    cd("testprograms")
    asmm := concat("../", asm_bin) 
    for file in list_files() {
        if filepath.ext(file.fullpath ) == ".pasm" {
            run(asmm, file.fullpath) 
        }
    }
    cd("..")
}
