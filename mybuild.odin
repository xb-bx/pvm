package nobuild
import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
econio_lib := ""
asm_bin := ""
main :: proc() {
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
