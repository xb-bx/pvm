package nobuild
import "core:fmt"
import "core:os"
econio_lib := ""
asm_bin := ""
main :: proc() {
    if !os.exists("c-econio") {
        run("git", "clone", "https://github.com/czirkoszoltan/c-econio")
    }
    cd("c-econio")
    when ODIN_OS == .Windows {
        run("cl", "-TC", "-c", "econio.c")
        run("lib", "-nologo", "econio.obj", "-out:econio.lib")
        econio_lib = "econio.lib"
        asm_bin = "asm.exe"
    } else {
        run("gcc", "-c", "econio.c")
        run("ar", "rcs", "econio.a", "econio.o")
        econio_lib = "econio.a"
        asm_bin = "asm.bin"
    }
    cp(econio_lib, "../src")
    cd("..")
    build_pvm()
    build_pasm() 
    build_programs()
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
    for file in list_files("./testprograms") {
        run(asm_bin, file.fullpath) 
    }
}
