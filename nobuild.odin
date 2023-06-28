package nobuild
import "core:fmt"
import "core:strings"
import "core:os"
import "core:path/filepath"

when ODIN_OS == .Windows do import "core:sys/windows"

run :: proc(name: string, args: ..string) {
    if !try_run(name, ..args) {
        exit(1)
    }
}
try_run :: proc(name: string, args: ..string) -> bool {
    using strings
    start_info := windows.STARTUPINFOW {}
    proc_info := windows.PROCESS_INFORMATION {}

    builderobj : Builder = {}
    builder := &builderobj
    builder_init(builder)
    write_string(builder, name)
    for arg in args {
        write_rune(builder, ' ')
        write_rune(builder, '"')
        for c in arg {
            if c != '"' {
                write_rune(builder, c)
            }    
            else {
                write_rune(builder, '\\')
                write_rune(builder, c)
            }
        }
        write_rune(builder, '"')
    }
    cmdline := to_string(builder^)
    fmt.println(cmdline)
    ok := windows.CreateProcessW(nil, windows.utf8_to_wstring(cmdline), nil, nil, true, 0, nil, nil, &start_info, &proc_info)
    if !ok {
        fmt.printf("ERROR: failed to run %s\n", name)
        return false
        
    }
    windows.WaitForSingleObject(proc_info.hProcess, windows.INFINITE)
    exitcode: windows.DWORD = 0
    windows.GetExitCodeProcess(proc_info.hProcess, &exitcode) 
    if exitcode != 0 {
        fmt.printf("ERROR: Process %s returned exit code %i", name, exitcode)
        return false
    }
    return true

}
cd :: proc(dir: string) {
    os.change_directory(dir)
}
exit :: proc(err: int = 0) {
    os.exit(err)
}
exit_if_true :: proc(cond: bool) {
    if cond {
        exit(1) 
    }
}
try_rmdir :: proc(dir: string) -> bool {
    if !os.is_dir(dir) {
        fmt.printf("ERROR: %s is not a directory\n", dir)
        return false
    }
    handle, err := os.open(dir, os.O_RDWR)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", dir)
        return false
    }
    fi, errno := os.read_dir(handle, -1)
    if errno != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", dir)
        return false 
    }
    for file in fi {
        if file.is_dir {
            if !try_rmdir(file.fullpath) {
                return false
            }
        } else {
            err = os.remove(file.fullpath)
            if err != os.ERROR_NONE {
                fmt.printf("ERROR: failed to delete file %s\n", file.fullpath)
                return false
            }
        }
    } 
    os.close(handle)
    err = os.remove_directory(dir)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: failed to delete directory %s\n", dir)
        return false
    }
    return true
}
rmdir :: proc(dir: string) {
    if !try_rmdir(dir) {
        exit(1)
    }
}
pwd :: proc() -> string {
    return os.get_current_directory()
} 
concat :: proc(strs: ..string) -> string {
    str, _ := strings.concatenate(strs)
    return str
}
try_mkdir :: proc(dir: string) -> bool {
    return os.make_directory(dir) != os.ERROR_NONE
}

mkdir :: proc(dir: string) {
    if !try_mkdir(dir) {
        exit(1)
    }
}
_cp_dir :: proc(from: string, to: string) -> bool {
    if !os.is_dir(to) {
        fmt.printf("ERROR: %s is not a directory\n", from)
        return false
    }
    handle, err := os.open(from, os.O_RDONLY)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", from)
        return false
    }
    fi, errno := os.read_dir(handle, -1)
    if errno != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", from)
        return false 
    }
    new_path := concat(to, "/", file_name(from))
    mkdir(new_path)
    for file in fi {
    
        if file.is_dir {
            if !_cp_dir(file.fullpath, new_path) {
                fmt.printf("ERROR: Failed to copy dir %s\n", file.fullpath) 
                return false
            }
        } 
        else {
            if !_cp_file(file.fullpath, new_path) {
                fmt.printf("ERROR: Failed to copy file %s\n", file.fullpath) 
                return false
            }
        }
    }
    return true
}

_cp_file :: proc(from: string, to:string) -> bool {
    to := to
    if !os.exists(from) {
        fmt.printf("ERROR: File %s doesn't exists\n", from)
        return false
    }
    if os.is_dir(to) {
        to = concat(to, "/", file_name(from)) 
    }
    fromhandle, err := os.open(from, os.O_RDONLY)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: Can't open file %s\n", from)
        return false
    }
    fromdata, success := os.read_entire_file_from_handle(fromhandle)
    if !os.write_entire_file(to, fromdata, true) {
        fmt.printf("ERROR: Can't write file %s\n", to)
        return false
    }
    return true
} 
file_name :: proc(file: string) -> string {
    return filepath.base(file) 
}
try_cp :: proc(from: string, to: string) -> bool {
    if os.is_dir(from) {
        return _cp_dir(from, to)
    }
    else {
        return _cp_file(from, to)
    }
}
cp :: proc(from: string, to: string) {
    if !try_cp(from, to) {
        exit(1)
    }
}
