<?php

namespace App\Http\Controllers\V1\User;

use App\Http\Controllers\Controller;
use App\Models\Plan;
use App\Models\Server;
use App\Models\User;
use App\Services\ServerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class MobileVpnConfigController extends Controller
{
    private const CACHE_SECONDS = 300;

    public function store(Request $request): JsonResponse
    {
        $country = strtoupper(trim((string) $request->header('X-Verified-Country', '')));
        if (!preg_match('/^[A-Z]{2}$/', $country) || in_array($country, ['XX', 'T1'], true)) {
            return $this->noStore($this->fail([403001, '无法验证当前所在地区']));
        }
        if ($country === 'CN') {
            return $this->noStore($this->fail([451001, '该服务在中国大陆地区不可用']));
        }

        $validator = Validator::make($request->all(), [
            'node_id' => ['required', 'integer', 'min:1'],
            'platform' => ['required', 'in:ios'],
            'app_version' => ['nullable', 'string', 'max:64'],
        ]);
        if ($validator->fails()) {
            return $this->noStore($this->fail([422001, '请求参数错误'], null, $validator->errors()));
        }

        $user = User::find($request->user()->id);
        if (!$user) {
            return $this->noStore($this->fail([404001, '用户不存在']));
        }

        $accountError = $this->accountError($user);
        if ($accountError !== null) {
            return $this->noStore($this->fail([403002, $accountError]));
        }

        $nodeId = (int) $validator->validated()['node_id'];
        $server = collect(ServerService::getAvailableServers($user))
            ->first(static fn (array $candidate): bool => (int) ($candidate['id'] ?? 0) === $nodeId);

        if (!$server) {
            return $this->noStore($this->fail([404002, '节点不存在或无权访问']));
        }
        if ((int) ($server['available_status'] ?? Server::STATUS_OFFLINE) !== Server::STATUS_ONLINE) {
            return $this->noStore($this->fail([503001, '节点当前不可用，请选择其他节点']));
        }
        if (($server['type'] ?? null) === Server::TYPE_HYSTERIA) {
            $path = storage_path('app/v2rayn-hy2-forward.json');
            $manifest = is_readable($path) ? json_decode(file_get_contents($path), true) : null;
            $pinPath = storage_path('app/mobile-hy2-cert-pins.json');
            $pins = is_readable($pinPath) ? json_decode(file_get_contents($pinPath), true) : [];
            try {
                $config = \App\Services\MobileHysteriaConfig::build(
                    $server, is_array($manifest) ? $manifest : null, time(), is_array($pins) ? $pins : []
                );
                return $this->noStore($this->success($config));
            } catch (\DomainException $error) {
                return $this->noStore($this->fail([503003, $error->getMessage()]));
            }
        }
        if (($server['type'] ?? null) !== Server::TYPE_VLESS) {
            return $this->noStore($this->fail([422002, '当前版本暂不支持该节点协议']));
        }

        $settings = (array) ($server['protocol_settings'] ?? []);
        $reality = (array) ($settings['reality_settings'] ?? []);
        $network = strtolower((string) ($settings['network'] ?? ''));
        $host = trim((string) ($server['host'] ?? ''));
        $port = (int) ($server['port'] ?? 0);
        $serverName = trim((string) ($reality['server_name'] ?? ''));
        $publicKey = trim((string) ($reality['public_key'] ?? ''));
        $shortId = trim((string) ($reality['short_id'] ?? ''));
        $flow = trim((string) ($settings['flow'] ?? ''));

        $isRealityNode = (int) ($settings['tls'] ?? 0) === 2
            && in_array($network, ['tcp', 'raw'], true)
            && $host !== ''
            && $port >= 1
            && $port <= 65535
            && $serverName !== ''
            && $publicKey !== ''
            && ($shortId === '' || (strlen($shortId) <= 16 && strlen($shortId) % 2 === 0 && ctype_xdigit($shortId)))
            && Str::isUuid((string) $user->uuid);

        if (!$isRealityNode) {
            return $this->noStore($this->fail([503002, '节点配置不完整，请选择其他节点']));
        }

        $now = time();
        return $this->noStore($this->success([
            'schema_version' => 1,
            'issued_at' => $now,
            'refresh_after' => $now + self::CACHE_SECONDS,
            'protocol' => 'vless',
            'node' => [
                'id' => (int) $server['id'],
                'name' => (string) ($server['name'] ?? ''),
            ],
            'endpoint' => [
                'address' => $host,
                'port' => $port,
            ],
            'authentication' => [
                'id' => (string) $user->uuid,
                'encryption' => 'none',
                'flow' => $flow,
            ],
            'transport' => [
                'type' => 'raw',
            ],
            'security' => [
                'type' => 'reality',
                'server_name' => $serverName,
                'public_key' => $publicKey,
                'short_id' => $shortId,
                'fingerprint' => 'chrome',
                'spider_x' => '/',
            ],
        ]));
    }

    private function accountError(User $user): ?string
    {
        if ((bool) $user->banned) {
            return '账号已被停用';
        }
        if (empty($user->plan_id) || !Plan::whereKey($user->plan_id)->exists()) {
            return '当前没有有效套餐';
        }
        if ($user->expired_at !== null && (int) $user->expired_at <= time()) {
            return '套餐已过期';
        }

        $used = max(0, (int) ($user->u ?? 0) + (int) ($user->d ?? 0));
        $total = max(0, (int) ($user->transfer_enable ?? 0));
        if ($total <= 0 || $used >= $total) {
            return '套餐流量已用尽';
        }
        if (!Str::isUuid((string) $user->uuid)) {
            return '账号凭据无效';
        }

        return null;
    }

    private function noStore(JsonResponse $response): JsonResponse
    {
        return $response->withHeaders([
            'Cache-Control' => 'private, no-store, max-age=0',
            'Pragma' => 'no-cache',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
