<?php

namespace App\Services;

use DomainException;

/** Typed HY2 response only; authorization remains in MobileVpnConfigController. */
final class MobileHysteriaConfig
{
    public static function build(array $server, ?array $manifest, int $now, array $certificatePins = []): array
    {
        $settings = (array) ($server['protocol_settings'] ?? []);
        if (($server['type'] ?? '') !== 'hysteria' || (int) ($settings['version'] ?? 0) !== 2) {
            throw new DomainException('当前版本仅支持 Hysteria 2');
        }
        $host = trim((string) ($server['host'] ?? ''));
        $port = (int) ($server['port'] ?? 0);
        $ports = (string) ($server['ports'] ?? '');
        $parentId = (int) ($server['parent_id'] ?? 0);
        if ($parentId > 0) {
            // Match the existing v2rayN active UDP-forward manifest exactly.
            // Never silently bypass a configured relay by connecting directly.
            $entry = $manifest['nodes'][(string) ($server['id'] ?? '')] ?? null;
            if (!is_array($entry)
                || (int) ($manifest['parent_id'] ?? 0) !== $parentId
                || (int) ($server['relay_parent']['id'] ?? 0) !== $parentId
                || (string) ($entry['code'] ?? '') !== (string) ($server['code'] ?? '')
                || (string) ($entry['host'] ?? '') !== $host
                || (int) ($entry['port'] ?? 0) !== $port
                || !filter_var($manifest['parent_host'] ?? '', FILTER_VALIDATE_IP)
                || (int) ($entry['forward_port'] ?? 0) < 1
                || (int) ($entry['forward_port'] ?? 0) > 65535) {
                throw new DomainException('HY2 中转配置尚未就绪，请选择其他线路');
            }
            $host = $manifest['parent_host'];
            $port = (int) $entry['forward_port'];
            $ports = '';
        }
        $password = (string) ($server['password'] ?? '');
        $tls = (array) ($settings['tls'] ?? []);
        $serverName = trim((string) ($tls['server_name'] ?? '')) ?: $host;
        $pin = $certificatePins[(string) ($server['id'] ?? '')] ?? null;
        $fingerprint = '';
        if (is_array($pin)
            && ($pin['host'] ?? '') === ($server['host'] ?? '')
            && (int) ($pin['port'] ?? 0) === (int) ($server['port'] ?? 0)
            && ($pin['server_name'] ?? '') === $serverName
            && preg_match('/^[a-fA-F0-9]{64}$/D', (string) ($pin['sha256'] ?? ''))) {
            $fingerprint = strtolower($pin['sha256']);
        }
        if (($tls['allow_insecure'] ?? false) && $fingerprint === '') {
            throw new DomainException('HY2 节点尚未配置可信证书指纹，请先使用 VLESS 线路');
        }
        if ($host === '' || $port < 1 || $port > 65535 || $password === '' || $serverName === '') {
            throw new DomainException('HY2 节点配置不完整，请选择其他线路');
        }
        if ($ports !== '' && (!preg_match('/^([0-9]+)-([0-9]+)$/D', $ports, $range)
            || (int) $range[1] < 1 || (int) $range[2] > 65535 || (int) $range[1] > (int) $range[2])) {
            throw new DomainException('HY2 端口范围无效');
        }
        $interval = (int) ($settings['hop_interval'] ?? 30);
        if ($interval < 5 || $interval > 3600) throw new DomainException('HY2 跳跃间隔无效');
        $transport = ['type' => 'quic', 'ports' => $ports, 'hop_interval' => $interval];
        foreach (['up' => 'up_mbps', 'down' => 'down_mbps'] as $source => $target) {
            $speed = (int) ($settings['bandwidth'][$source] ?? 0);
            if ($speed < 0 || $speed > 1000000) throw new DomainException('HY2 带宽配置无效');
            $transport[$target] = $speed;
        }
        $obfs = (array) ($settings['obfs'] ?? []);
        if ($obfs['open'] ?? false) {
            if (($obfs['type'] ?? '') !== 'salamander' || empty($obfs['password'])) {
                throw new DomainException('HY2 混淆配置不受支持');
            }
            $transport['obfs'] = ['type' => 'salamander', 'password' => (string) $obfs['password']];
        }
        return [
            'schema_version' => 1, 'issued_at' => $now, 'refresh_after' => $now + 300,
            'protocol' => 'hysteria2',
            'node' => ['id' => (int) $server['id'], 'name' => (string) ($server['name'] ?? '')],
            'endpoint' => ['address' => $host, 'port' => $port],
            // Existing ServerService generates the per-account password.
            'authentication' => ['password' => $password],
            'transport' => $transport,
            'security' => ['type' => 'tls', 'server_name' => $serverName,
                'allow_insecure' => false, 'pinned_peer_cert_sha256' => $fingerprint],
        ];
    }
}
