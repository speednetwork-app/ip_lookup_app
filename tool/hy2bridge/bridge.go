// Package hy2bridge provides an isolated official-Hysteria compatibility client.
// It never modifies Xray's TLS policy, REALITY, or the app's HTTPS connections.
package hy2bridge

import (
    "crypto/rand"
    "crypto/sha256"
    "crypto/subtle"
    "crypto/x509"
    "encoding/hex"
    "encoding/json"
    "errors"
    "fmt"
    "net"
    "strconv"
    "sync"
    "time"

    "github.com/apernet/hysteria/core/v2/client"
    "github.com/apernet/hysteria/extras/v2/obfs"
    "github.com/apernet/hysteria/extras/v2/transport/udphop"
    "github.com/xtls/libxray/pikahy2/socks5"
)

type Config struct {
    Address string `json:"address"`
    Port int `json:"port"`
    Password string `json:"password"`
    ServerName string `json:"server_name"`
    AllowInsecure bool `json:"allow_insecure"`
    InsecureConsent bool `json:"insecure_consent"`
    Pin string `json:"pinned_peer_cert_sha256"`
    ObfsPassword string `json:"obfs_password"`
    ServerPorts string `json:"server_ports"`
    HopInterval int `json:"hop_interval"`
    UpMbps int `json:"up_mbps"`
    DownMbps int `json:"down_mbps"`
}

type Endpoint struct {
    Port int `json:"port"`
    User string `json:"user"`
    Password string `json:"password"`
}

type Runtime struct {
    listener net.Listener
    hy client.Client
    Endpoint Endpoint
    mu sync.Mutex
    closed bool
    connections map[net.Conn]struct{}
}

type packetFactory struct { config Config }
func (f packetFactory) New(addr net.Addr) (net.PacketConn, error) {
    var conn net.PacketConn
    var err error
    if hop, ok := addr.(*udphop.UDPHopAddr); ok {
        interval := time.Duration(f.config.HopInterval)*time.Second
        conn, err = udphop.NewUDPHopPacketConn(hop, udphop.HopIntervalConfig{Min: interval, Max: interval}, nil)
    } else { conn, err = net.ListenUDP("udp", nil) }
    if err != nil { return nil, err }
    if f.config.ObfsPassword != "" {
        wrapped, wrapErr := obfs.WrapPacketConnSalamander(conn, []byte(f.config.ObfsPassword))
        if wrapErr != nil { conn.Close(); return nil, wrapErr }
        conn = wrapped
    }
    return conn, nil
}

func New(c Config) (*Runtime, error) {
    if c.Address == "" || c.ServerName == "" || c.Password == "" || c.Port < 1 || c.Port > 65535 ||
        c.HopInterval < 5 || c.HopInterval > 3600 || c.UpMbps < 0 || c.UpMbps > 1000000 ||
        c.DownMbps < 0 || c.DownMbps > 1000000 { return nil, errors.New("invalid HY2 configuration") }
    if c.AllowInsecure && c.Pin == "" && !c.InsecureConsent {
        return nil, errors.New("HY2 certificate compatibility requires explicit consent")
    }
    var addr net.Addr
    var err error
    if c.ServerPorts != "" { addr, err = udphop.ResolveUDPHopAddr(net.JoinHostPort(c.Address, c.ServerPorts))
    } else { addr, err = net.ResolveUDPAddr("udp", net.JoinHostPort(c.Address, strconv.Itoa(c.Port))) }
    if err != nil { return nil, errors.New("HY2 endpoint resolution failed") }
    tls := client.TLSConfig{ServerName: c.ServerName, InsecureSkipVerify: c.AllowInsecure}
    if c.Pin != "" {
        pin, err := hex.DecodeString(c.Pin)
        if err != nil || len(pin) != 32 { return nil, errors.New("invalid HY2 certificate pin") }
        // A pin replaces CA verification, not certificate identity verification.
        tls.InsecureSkipVerify = true
        tls.VerifyPeerCertificate = func(raw [][]byte, _ [][]*x509.Certificate) error {
            if len(raw) == 0 { return errors.New("missing HY2 certificate") }
            digest := sha256.Sum256(raw[0])
            if subtle.ConstantTimeCompare(digest[:], pin) != 1 { return errors.New("HY2 certificate pin mismatch") }
            return nil
        }
    }
    hy, info, err := client.NewClient(&client.Config{
        ConnFactory: packetFactory{c}, ServerAddr: addr, Auth: c.Password, TLSConfig: tls,
        QUICConfig: client.QUICConfig{DisableChromeParrot: true, KeepAlivePeriod: 10*time.Second},
        BandwidthConfig: client.BandwidthConfig{MaxTx: uint64(c.UpMbps)*125000, MaxRx: uint64(c.DownMbps)*125000},
    })
    // Never return raw upstream errors which may contain sensitive configuration.
    if err != nil { return nil, errors.New("HY2 handshake failed: check the selected line, TLS settings or network") }
    if !info.UDPEnabled { hy.Close(); return nil, errors.New("HY2 server does not enable UDP forwarding") }
    listener, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil { hy.Close(); return nil, errors.New("cannot start internal HY2 bridge") }
    var token [24]byte
    if _, err = rand.Read(token[:]); err != nil { listener.Close(); hy.Close(); return nil, err }
    r := &Runtime{listener: listener, hy: hy, connections: make(map[net.Conn]struct{}),
        Endpoint: Endpoint{Port: listener.Addr().(*net.TCPAddr).Port, User: "pikayun", Password: hex.EncodeToString(token[:])}}
    server := &socks5.Server{HyClient: hy, AuthFunc: func(user, password string) bool {
        return subtle.ConstantTimeCompare([]byte(user), []byte(r.Endpoint.User)) == 1 &&
            subtle.ConstantTimeCompare([]byte(password), []byte(r.Endpoint.Password)) == 1
    }}
    go func() { _ = server.Serve(&trackedListener{r}) }()
    return r, nil
}

type trackedListener struct { runtime *Runtime }
func (l *trackedListener) Addr() net.Addr { return l.runtime.listener.Addr() }
func (l *trackedListener) Close() error { return l.runtime.listener.Close() }
func (l *trackedListener) Accept() (net.Conn, error) {
    conn, err := l.runtime.listener.Accept(); if err != nil { return nil, err }
    r := l.runtime
    r.mu.Lock(); defer r.mu.Unlock()
    if r.closed { conn.Close(); return nil, net.ErrClosed }
    tracked := &trackedConn{Conn: conn, runtime: r}
    r.connections[tracked] = struct{}{}
    // Internal clients cannot hold unauthenticated bridge sockets indefinitely.
    _ = conn.SetReadDeadline(time.Now().Add(15*time.Second))
    return tracked, nil
}
type trackedConn struct { net.Conn; runtime *Runtime; authenticated bool }
func (c *trackedConn) Write(b []byte) (int,error) {
    // Successful SOCKS user/password authentication response.
    if !c.authenticated && len(b) == 2 && b[0] == 1 && b[1] == 0 {
        c.authenticated = true; _ = c.Conn.SetReadDeadline(time.Time{})
    }
    return c.Conn.Write(b)
}
func (c *trackedConn) Close() error {
    c.runtime.mu.Lock(); delete(c.runtime.connections, c); c.runtime.mu.Unlock()
    return c.Conn.Close()
}
func (r *Runtime) Close() error {
    r.mu.Lock()
    if r.closed { r.mu.Unlock(); return nil }
    r.closed = true
    sockets := make([]net.Conn, 0, len(r.connections))
    for conn := range r.connections { sockets = append(sockets, conn) }
    r.mu.Unlock()
    _ = r.listener.Close()
    for _, conn := range sockets { _ = conn.Close() }
    return r.hy.Close()
}

var running struct { sync.Mutex; runtime *Runtime }
func Invoke(text string) string {
    response := func(data any, err error) string {
        message := ""; if err != nil { message = err.Error() }
        encoded, _ := json.Marshal(map[string]any{"success": err == nil, "data": data, "error": message})
        return string(encoded)
    }
    if len(text) > 32768 { return response(nil, errors.New("invalid HY2 request size")) }
    var request struct { Version int `json:"apiVersion"`; Method string `json:"method"`; Config Config `json:"payload"` }
    if err := json.Unmarshal([]byte(text), &request); err != nil || request.Version != 3 {
        return response(nil, errors.New("invalid HY2 bridge request"))
    }
    running.Lock(); defer running.Unlock()
    switch request.Method {
    case "startHy2":
        if running.runtime != nil { return response(nil, errors.New("HY2 bridge is already running")) }
        r, err := New(request.Config); if err != nil { return response(nil, err) }
        running.runtime = r; return response(r.Endpoint, nil)
    case "stopHy2":
        if running.runtime != nil { _ = running.runtime.Close(); running.runtime = nil }
        return response(nil, nil)
    default: return response(nil, fmt.Errorf("unsupported HY2 bridge operation"))
    }
}
