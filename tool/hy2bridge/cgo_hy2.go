package main

/*
#include <stdlib.h>
*/
import "C"

import "github.com/xtls/libxray/pikahy2"

//export CGoHy2Invoke
func CGoHy2Invoke(requestJSON *C.char) *C.char {
    return C.CString(hy2bridge.Invoke(C.GoString(requestJSON)))
}
