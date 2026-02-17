#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/SystemInformationController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Install Proteksi Anti Modifikasi Detail Nodes 4..."
echo "Watermark: 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲"

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Node;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Repositories\Wings\DaemonConfigurationRepository;

class SystemInformationController extends Controller
{
    public function __construct(private DaemonConfigurationRepository $repository)
    {
        $user = Auth::user();

        if (!$user || $user->id !== 1) {
            \Log::warning('Unauthorized access blocked - 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲', [
                'user_id' => $user?->id,
                'ip' => request()->ip(),
                'route' => request()->path(),
                'method' => request()->method(),
                'time' => now()->toDateTimeString(),
            ]);

            abort(403, '🚫 Akses ditolak! 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲');
        }
    }

    public function __invoke(Request $request, Node $node): JsonResponse
    {
        $data = $this->repository->setNode($node)->getSystemInformation();

        return new JsonResponse([
            'version' => $data['version'] ?? '',
            'system' => [
                'type' => Str::title($data['os'] ?? 'Unknown'),
                'arch' => $data['architecture'] ?? '--',
                'release' => $data['kernel_version'] ?? '--',
                'cpus' => $data['cpu_count'] ?? 0,
            ],
        ]);
    }
}
EOF

chmod 644 "$REMOTE_PATH"
echo "✅ Install Proteksi Anti Modifikasi Detail Nodes 4 berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"