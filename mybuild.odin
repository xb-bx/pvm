package nobuild

main :: proc() {
    try_rmdir("c-econio")
    run("git", "clone", "https://github.com/czirkoszoltan/c-econio")
    cd("c-econio")
    when ODIN_OS == .Windows {
        run("cl", "-TC", "-c", "econio.c")
        run("lib", "-nologo", "econio.obj", "-out:econio.lib")
        econio_lib :: "econio.lib"
    } else {
        run("gcc", "-c", "econio.c")
        run("ar", "rcs", "econio.a", "econio.o")
        econio_lib :: "econio.a"
    }
    cp(econio_lib, "../src")
    cd("../src")
    when ODIN_OS == .Windows do output :: "pvm.exe"
    else do output :: "pvm"
    run("odin", "build", ".", "-extra-linker-flags:" + econio_lib, "-out:" + output)
    cp(output, "..")
    cd("..")
    
}
