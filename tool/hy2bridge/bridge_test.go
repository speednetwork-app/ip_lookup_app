package hy2bridge

import (
    "crypto/rand"
    "crypto/rsa"
    "crypto/x509"
    "crypto/x509/pkix"
    "encoding/binary"
    "encoding/json"
    "encoding/pem"
    "io"
    "math/big"
    "net"
    "net/http"
    "net/http/httptest"
    "os"
    "path/filepath"
    "strconv"
    "strings"
    "testing"
    "time"

    _ "github.com/xtls/libxray/xray"
    "github.com/xtls/xray-core/core"
    "golang.org/x/net/proxy"
)

func fixtureServer(t *testing.T, obfsPassword string) int {
    t.Helper()
    privateKey, err := rsa.GenerateKey(rand.Reader, 2048); if err != nil { t.Fatal(err) }
    template := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "self-signed-fixture"},
        NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour),
        KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
    der, err := x509.CreateCertificate(rand.Reader, template, template, &privateKey.PublicKey, privateKey); if err != nil { t.Fatal(err) }
    dir := t.TempDir(); cert, key := filepath.Join(dir, "cert.pem"), filepath.Join(dir, "key.pem")
    if err := os.WriteFile(cert, pem.EncodeToMemory(&pem.Block{Type:"CERTIFICATE",Bytes:der}),0600); err != nil {t.Fatal(err)}
    if err := os.WriteFile(key, pem.EncodeToMemory(&pem.Block{Type:"RSA PRIVATE KEY",Bytes:x509.MarshalPKCS1PrivateKey(privateKey)}),0600);err!=nil{t.Fatal(err)}
    sock, err := net.ListenPacket("udp","127.0.0.1:0");if err!=nil{t.Fatal(err)}
    port:=sock.LocalAddr().(*net.UDPAddr).Port;sock.Close()
    masks:=[]any{}
    if obfsPassword!=""{masks=append(masks,map[string]any{"type":"salamander","settings":map[string]any{"password":obfsPassword}})}
    data,_:=json.Marshal(map[string]any{"log":map[string]any{"loglevel":"none"},
        "inbounds":[]any{map[string]any{"listen":"127.0.0.1","port":port,"protocol":"hysteria",
            "settings":map[string]any{"version":2,"users":[]any{map[string]any{"auth":"fixture-password"}}},
            "streamSettings":map[string]any{"network":"hysteria","security":"tls","hysteriaSettings":map[string]any{"version":2},
                "tlsSettings":map[string]any{"alpn":[]string{"h3"},"certificates":[]any{map[string]any{"certificateFile":cert,"keyFile":key}}},
                "finalmask":map[string]any{"udp":masks,"quicParams":map[string]any{"disableChromeParrot":true}}}}},
        "outbounds":[]any{map[string]any{"protocol":"freedom","settings":map[string]any{
            "finalRules":[]any{map[string]any{"action":"allow","ip":[]string{"127.0.0.1/32"}}}}}},
    })
    parsed,err:=core.LoadConfig("json",strings.NewReader(string(data)));if err!=nil{t.Fatal(err)}
    server,err:=core.New(parsed);if err!=nil{t.Fatal(err)}
    if err=server.Start();err!=nil{t.Fatal(err)};t.Cleanup(func(){server.Close()})
    return port
}

func TestCompatibilityTCPUDPAndLifecycle(t *testing.T) {
    for _, mode:=range []string{"plain","salamander","hop"}{t.Run(mode,func(t *testing.T){
        obfsPassword:="";if mode=="salamander"{obfsPassword="fixture-obfs"}
        port:=fixtureServer(t,obfsPassword)
        cfg:=Config{Address:"127.0.0.1",Port:port,Password:"fixture-password",ServerName:"self-signed-fixture",
            HopInterval:5,AllowInsecure:true,InsecureConsent:true,ObfsPassword:obfsPassword}
        if mode=="hop"{cfg.ServerPorts=strconv.Itoa(port)+"-"+strconv.Itoa(port);cfg.UpMbps=10;cfg.DownMbps=100}
        runtime,err:=New(cfg);if err!=nil{t.Fatal(err)};defer runtime.Close()
        address:=net.JoinHostPort("127.0.0.1",strconv.Itoa(runtime.Endpoint.Port))
        auth:=&proxy.Auth{User:runtime.Endpoint.User,Password:runtime.Endpoint.Password}
        dialer,err:=proxy.SOCKS5("tcp",address,auth,&net.Dialer{Timeout:5*time.Second});if err!=nil{t.Fatal(err)}
        target:=httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter,r *http.Request){io.WriteString(w,"hy2-compat-ok")}));defer target.Close()
        transport:=&http.Transport{Dial:dialer.Dial};defer transport.CloseIdleConnections()
        httpClient:=&http.Client{Transport:transport,Timeout:8*time.Second}
        response,err:=httpClient.Get(target.URL);if err!=nil{t.Fatal(err)}
        body,err:=io.ReadAll(response.Body);response.Body.Close();if err!=nil||string(body)!="hy2-compat-ok"{t.Fatal("TCP transfer failed")}
        wrong,_:=proxy.SOCKS5("tcp",address,&proxy.Auth{User:"wrong",Password:"wrong"},&net.Dialer{Timeout:time.Second})
        if conn,err:=wrong.Dial("tcp",strings.TrimPrefix(target.URL,"http://"));err==nil{conn.Close();t.Fatal("bridge allowed unauthenticated client")}
        verifyUDP(t,runtime)
        if err:=runtime.Close();err!=nil{t.Fatal(err)}
        if conn,err:=net.DialTimeout("tcp",address,250*time.Millisecond);err==nil{conn.Close();t.Fatal("bridge listener survived Close")}
        if err:=runtime.Close();err!=nil{t.Fatal("Close not idempotent")}
    })}
}

func verifyUDP(t *testing.T,r *Runtime){
    t.Helper()
    echo,err:=net.ListenUDP("udp",&net.UDPAddr{IP:net.IPv4(127,0,0,1)});if err!=nil{t.Fatal(err)};defer echo.Close()
    go func(){var b [2048]byte;for{n,a,e:=echo.ReadFromUDP(b[:]);if e!=nil{return};echo.WriteToUDP(b[:n],a)}}()
    tcp,err:=net.Dial("tcp",net.JoinHostPort("127.0.0.1",strconv.Itoa(r.Endpoint.Port)));if err!=nil{t.Fatal(err)};defer tcp.Close()
    tcp.SetDeadline(time.Now().Add(8*time.Second))
    tcp.Write([]byte{5,1,2});var reply [2]byte
    if _,err=io.ReadFull(tcp,reply[:]);err!=nil||reply!=[2]byte{5,2}{t.Fatal("SOCKS auth negotiation failed")}
    request:=append([]byte{1,byte(len(r.Endpoint.User))},[]byte(r.Endpoint.User)...)
    request=append(request,byte(len(r.Endpoint.Password)));request=append(request,[]byte(r.Endpoint.Password)...);tcp.Write(request)
    if _,err=io.ReadFull(tcp,reply[:]);err!=nil||reply!=[2]byte{1,0}{t.Fatal("SOCKS auth failed")}
    tcp.Write([]byte{5,3,0,1,0,0,0,0,0,0});var bind [10]byte
    if _,err=io.ReadFull(tcp,bind[:]);err!=nil||bind[1]!=0||bind[3]!=1{t.Fatal("UDP association failed")}
    udp,err:=net.DialUDP("udp",nil,&net.UDPAddr{IP:net.IP(bind[4:8]),Port:int(binary.BigEndian.Uint16(bind[8:10]))});if err!=nil{t.Fatal(err)};defer udp.Close()
    udp.SetDeadline(time.Now().Add(8*time.Second))
    packet:=[]byte{0,0,0,1,127,0,0,1,0,0};binary.BigEndian.PutUint16(packet[8:10],uint16(echo.LocalAddr().(*net.UDPAddr).Port));packet=append(packet,[]byte("udp-ok")...)
    udp.Write(packet);var b [2048]byte;n,err:=udp.Read(b[:]);if err!=nil||n<10||string(b[10:n])!="udp-ok"{t.Fatalf("UDP transfer failed: %v",err)}
}

func TestCertificatePolicies(t *testing.T){
    port:=fixtureServer(t,"")
    cfg:=Config{Address:"127.0.0.1",Port:port,Password:"fixture-password",ServerName:"self-signed-fixture",HopInterval:5}
    if r,err:=New(cfg);err==nil{r.Close();t.Fatal("strict mode accepted self-signed certificate")}
    cfg.AllowInsecure=true
    if r,err:=New(cfg);err==nil{r.Close();t.Fatal("compatibility accepted without user consent")}
    cfg.InsecureConsent=true;cfg.Pin=strings.Repeat("0",64)
    if r,err:=New(cfg);err==nil{r.Close();t.Fatal("pin mismatch was ignored")}
}
