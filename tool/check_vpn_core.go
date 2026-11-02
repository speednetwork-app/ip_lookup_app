// Run inside the pinned libXray module. All credentials and endpoints here are
// isolated test fixtures; no production subscription or server is contacted.
package main

import (
    "crypto/rand"
    "crypto/rsa"
    "crypto/x509"
    "crypto/x509/pkix"
    "encoding/json"
    "encoding/pem"
    "fmt"
    "io"
    "math/big"
    "net"
    "net/http"
    "net/http/httptest"
    "os"
    "path/filepath"
    "strings"
    "time"

    _ "github.com/xtls/libxray/xray"
    "github.com/xtls/xray-core/core"
    "golang.org/x/net/proxy"
)

type object = map[string]any
type testCase struct { Name string `json:"name"`; Outbound object `json:"outbound"` }

func start(config object) (*core.Instance, error) {
    data, err := json.Marshal(config); if err != nil { return nil, err }
    parsed, err := core.LoadConfig("json", strings.NewReader(string(data))); if err != nil { return nil, err }
    instance, err := core.New(parsed); if err != nil { return nil, err }
    if err = instance.Start(); err != nil { instance.Close(); return nil, err }
    return instance, nil
}

func check(c testCase, cert, key string) error {
    if c.Name == "vless" {
        instance, err := start(object{"outbounds": []any{c.Outbound}})
        if err == nil { instance.Close() }
        return err
    }
    udp, err := net.ListenPacket("udp", "127.0.0.1:0"); if err != nil { return err }
    port := udp.LocalAddr().(*net.UDPAddr).Port; udp.Close()
    stream := c.Outbound["streamSettings"].(map[string]any)
    mask := stream["finalmask"].(map[string]any)
    masks := mask["udp"].([]any)
    serverMasks := []any{}
    for _, raw := range masks {
        item := raw.(map[string]any)
        if item["type"] == "udphop" {
            item["settings"].(map[string]any)["remotePorts"] = fmt.Sprintf("%d-%d", port, port)
        } else { serverMasks = append(serverMasks, item) }
    }
    server, err := start(object{
        "log": object{"loglevel": "none"},
        "inbounds": []any{object{"listen": "127.0.0.1", "port": port, "protocol": "hysteria",
            "settings": object{"version": 2, "users": []any{object{"auth": "fixture-password"}}},
            "streamSettings": object{"network": "hysteria", "security": "tls",
                "hysteriaSettings": object{"version": 2},
                "tlsSettings": object{"alpn": []string{"h3"}, "certificates": []any{object{"certificateFile": cert, "keyFile": key}}},
                "finalmask": object{"udp": serverMasks, "quicParams": object{"disableChromeParrot": true}},
            }}},
        "outbounds": []any{object{"protocol": "freedom"}},
    }); if err != nil { return err }; defer server.Close()
    settings := c.Outbound["settings"].(map[string]any)
    settings["address"] = "127.0.0.1"; settings["port"] = port
    // The isolated server uses an ephemeral self-signed test certificate.
    stream["tlsSettings"].(map[string]any)["allowInsecure"] = true
    tcp, err := net.Listen("tcp", "127.0.0.1:0"); if err != nil { return err }
    socksPort := tcp.Addr().(*net.TCPAddr).Port; tcp.Close()
    client, err := start(object{"log": object{"loglevel": "none"},
        "inbounds": []any{object{"listen": "127.0.0.1", "port": socksPort, "protocol": "socks", "settings": object{"auth": "noauth"}}},
        "outbounds": []any{c.Outbound},
    }); if err != nil { return err }; defer client.Close()
    target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, "hy2-ok") }))
    defer target.Close()
    dialer, err := proxy.SOCKS5("tcp", fmt.Sprintf("127.0.0.1:%d", socksPort), nil, &net.Dialer{Timeout: 5*time.Second})
    if err != nil { return err }
    transport := &http.Transport{Dial: dialer.Dial}; defer transport.CloseIdleConnections()
    httpClient := &http.Client{Transport: transport, Timeout: 8*time.Second}
    response, err := httpClient.Get(target.URL); if err != nil { return err }
    defer response.Body.Close(); body, err := io.ReadAll(response.Body)
    if err != nil { return err }; if string(body) != "hy2-ok" { return fmt.Errorf("tunnel response mismatch") }
    return nil
}

func main() {
    var cases []testCase
    if err := json.NewDecoder(os.Stdin).Decode(&cases); err != nil { panic(err) }
    dir, err := os.MkdirTemp("", "pikayun-hy2-fixture-"); if err != nil { panic(err) }; defer os.RemoveAll(dir)
    privateKey, err := rsa.GenerateKey(rand.Reader, 2048); if err != nil { panic(err) }
    template := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "localhost"},
        DNSNames: []string{"tls.example.com"}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour),
        KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
    der, err := x509.CreateCertificate(rand.Reader, template, template, &privateKey.PublicKey, privateKey); if err != nil { panic(err) }
    cert, key := filepath.Join(dir, "cert.pem"), filepath.Join(dir, "key.pem")
    if err := os.WriteFile(cert, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), 0600); err != nil { panic(err) }
    if err := os.WriteFile(key, pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(privateKey)}), 0600); err != nil { panic(err) }
    for _, c := range cases {
        if err := check(c, cert, key); err != nil { fmt.Fprintln(os.Stderr, c.Name+": "+err.Error()); os.Exit(1) }
        fmt.Println(c.Name+": native config and pinned-core verification passed")
    }
}
