package mobile

/*
#include <stdlib.h>
*/
import "C"

import (
    "bytes"
    "context"
    "io"
    "os"
    "sync"
    "github.com/fatedier/frp/client"
    "github.com/fatedier/frp/pkg/util/version"
    "github.com/sirupsen/logrus"
)

var (
    cancel  context.CancelFunc
    logBuf  bytes.Buffer
    logLock sync.Mutex
    redirectOnce sync.Once
)

type ringWriter struct{}

func (ringWriter) Write(p []byte) (n int, err error) {
    logLock.Lock()
    // 控制日志缓冲区大小，最多 1 MB
    if logBuf.Len() > 1<<20 {
        logBuf.Reset()
    }
    logBuf.Write(p)
    logLock.Unlock()
    return len(p), nil
}

func startStdCapture() {
    r, w, _ := os.Pipe()
    // Replace stdout/stderr
    os.Stdout = w
    os.Stderr = w
    go func() {
        buf := make([]byte, 4096)
        for {
            n, err := r.Read(buf)
            if n > 0 {
                ringWriter{}.Write(buf[:n])
            }
            if err != nil {
                if err == io.EOF {
                    return
                }
            }
        }
    }()
}

//export StartFrp
func StartFrp(cCfgPath *C.char) {
    if cancel != nil {
        return
    }
    cfgPath := C.GoString(cCfgPath)

    // 将 frp 日志输出重定向到 ring 缓冲区，并调高日志级别
    logrus.SetOutput(ringWriter{})
    logrus.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})
    logrus.SetLevel(logrus.DebugLevel)

    // 重定向标准输出和标准错误到 ringWriter（一次性）
    redirectOnce.Do(startStdCapture)

    ctx, c := context.WithCancel(context.Background())
    cancel = c
    go client.RunClient(ctx, cfgPath)
}

//export StopFrp
func StopFrp() {
    if cancel != nil {
        cancel()
        cancel = nil
    }
}

//export FrpLogs
func FrpLogs() *C.char {
    logLock.Lock()
    data := logBuf.String()
    logBuf.Reset()
    logLock.Unlock()
    return C.CString(data)
}

//export FrpVersion
func FrpVersion() *C.char {
    return C.CString(version.Full())
} 