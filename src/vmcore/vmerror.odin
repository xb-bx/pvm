package vmcore

function_not_found :: proc(name: string) -> FunctionNotFound {
    return FunctionNotFound{
        name = name,
    }
}
type_redefinition :: proc(name: string) -> TypeRedefinition {
    return TypeRedefinition {
        name = name,
    }
}
type_not_found :: proc(name: string) -> TypeNotFound {
    return TypeNotFound{
        name = name,
    }
}
module_not_found :: proc(path: string) -> ModuleNotFound {
    return ModuleNotFound {
        path = path,
    }
}
corrupted_module :: proc(path: string) -> CorruptedModule {
    return CorruptedModule {
        path = path,
    }
}
failed_to_find_type_size :: proc(type: string) -> FailedToFindTypeSize {
    return FailedToFindTypeSize {
        type = type,
    }   
}
field_of_ref_type :: proc(file: string, field: string) ->  FieldOfRefType {
    return FieldOfRefType {
        file = file,
        field = field,
    }
}
cant_return_reference_from_function :: proc(file: string, function: string) -> CantReturnRefFromFunction {
    return CantReturnRefFromFunction {
        file = file,
        function = function,
    }
}
recursive_type :: proc(type: string) -> RecursiveType {
    return RecursiveType {
        type = type,
    }
}
none := None {}
CantReturnRefFromFunction :: struct {
    file: string, function: string,
}
FailedToFindTypeSize :: struct {
    type: string,
}
ModuleNotFound :: struct {
    path: string,
}
CorruptedModule :: struct {
    path: string,
}
TypeNotFound :: struct {
    name: string,
}
TypeRedefinition :: struct {
    name: string,
}
FunctionNotFound :: struct {
    name: string,
}
RecursiveType :: struct {
    type: string,
}
FieldOfRefType :: struct {
    file: string, field: string,
}
None :: struct {}
VMError :: union {
    None,
    ModuleNotFound,
    CorruptedModule,
    TypeNotFound,    
    TypeRedefinition,
    FunctionNotFound,
    RecursiveType,
    CantReturnRefFromFunction,
    FieldOfRefType,
}
