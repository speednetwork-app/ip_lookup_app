<?php
require __DIR__.'/MobileHysteriaConfig.php';
use App\Services\MobileHysteriaConfig;

function check(bool $ok, string $name): void {
    if (!$ok) throw new RuntimeException($name);
}
function reject(array $server, ?array $manifest = null): void {
    try { MobileHysteriaConfig::build($server, $manifest, 1000); }
    catch (DomainException $error) { return; }
    throw new RuntimeException('Invalid configuration accepted');
}
$node = ['id' => 7, 'name' => 'Fixture', 'type' => 'hysteria', 'parent_id' => 0,
    'host' => 'node.example.com', 'port' => 443, 'password' => 'fixture-password',
    'protocol_settings' => ['version' => 2, 'tls' => ['server_name' => 'tls.example.com']]];
$result = MobileHysteriaConfig::build($node, null, 1000);
check($result['protocol'] === 'hysteria2', 'protocol');
check($result['authentication']['password'] === 'fixture-password', 'account password');
check($result['security']['allow_insecure'] === false, 'TLS must default to verification');
check($result['refresh_after'] === 1300, 'expiry');
$hy1 = $node; $hy1['protocol_settings']['version'] = 1; reject($hy1);
$invalid = $node; $invalid['password'] = ''; reject($invalid);
$invalid = $node; $invalid['port'] = 0; reject($invalid);
$invalid = $node; $invalid['protocol_settings']['obfs'] = ['open' => true, 'type' => 'unknown']; reject($invalid);
$node['ports'] = '20000-21000';
$node['protocol_settings']['obfs'] = ['open' => true, 'type' => 'salamander', 'password' => 'fixture-obfs'];
check(MobileHysteriaConfig::build($node, null, 1000)['transport']['obfs']['password'] === 'fixture-obfs', 'obfs');
$invalid = $node; $invalid['ports'] = '65000-70000'; reject($invalid);
$node['parent_id'] = 8; $node['relay_parent'] = ['id' => 8]; $node['code'] = 'fixture-code';
$manifest = ['parent_id' => 8, 'parent_host' => '192.0.2.1', 'nodes' => [7 => [
    'code' => 'fixture-code', 'host' => 'node.example.com', 'port' => 443, 'forward_port' => 30007]]];
$result = MobileHysteriaConfig::build($node, $manifest, 1000);
check($result['endpoint'] === ['address' => '192.0.2.1', 'port' => 30007], 'relay mapping');
check($result['transport']['ports'] === '', 'do not hop a fixed relay port');
check($result['security']['server_name'] === 'tls.example.com', 'keep destination SNI');
reject($node);
$invalidManifest = $manifest; $invalidManifest['nodes'][7]['code'] = 'stale'; reject($node, $invalidManifest);
$invalidManifest = $manifest; $invalidManifest['parent_id'] = 9; reject($node, $invalidManifest);
echo "HY2 backend configuration tests passed\n";
