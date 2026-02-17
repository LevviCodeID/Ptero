#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Memasang Proteksi Anti Modifikasi Detail Server..."
echo "Watermark: 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲"

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Traits\Services\ReturnsUpdatedModels;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class DetailsModificationService
{
    use ReturnsUpdatedModels;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $serverRepository
    ) {}

    public function handle(Server $server, array $data): Server
    {
        $user = auth()->user();
        if (!$user || $user->id !== 1) {
            throw new AccessDeniedHttpException('Akses ditolak - 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲');
        }

        return $this->connection->transaction(function () use ($data, $server) {
            $owner = $server->owner_id;

            $server->forceFill([
                'external_id' => Arr::get($data, 'external_id'),
                'owner_id' => Arr::get($data, 'owner_id'),
                'name' => Arr::get($data, 'name'),
                'description' => Arr::get($data, 'description') ?? '',
            ])->saveOrFail();

            if ($server->owner_id !== $owner) {
                try {
                    $this->serverRepository->setServer($server)->revokeUserJTI($owner);
                } catch (DaemonConnectionException $exception) {
                }
            }

            return $server;
        });
    }
}
EOF

chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi Anti Modifikasi Detail Server berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"