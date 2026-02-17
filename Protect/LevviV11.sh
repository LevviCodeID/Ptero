#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/NodeViewController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Install Proteksi Anti Modifikasi Detail Nodes 3..."
echo "Watermark: 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲"

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Illuminate\Support\Collection;
use Pterodactyl\Models\Allocation;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Pterodactyl\Repositories\Eloquent\NodeRepository;
use Pterodactyl\Repositories\Eloquent\ServerRepository;
use Pterodactyl\Traits\Controllers\JavascriptInjection;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Repositories\Eloquent\LocationRepository;
use Pterodactyl\Repositories\Eloquent\AllocationRepository;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class NodeViewController extends Controller
{
    use JavascriptInjection;

    public function __construct(
        private AllocationRepository $allocationRepository,
        private LocationRepository $locationRepository,
        private NodeRepository $repository,
        private ServerRepository $serverRepository,
        private SoftwareVersionService $versionService,
        private ViewFactory $view
    ) {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();

            if (!$user || (int)$user->id !== 1) {
                Log::warning('Unauthorized access blocked - 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲', [
                    'user_id' => $user?->id,
                    'ip' => $request->ip(),
                    'route' => $request->path(),
                    'method' => $request->method(),
                    'time' => now()->toDateTimeString(),
                ]);

                abort(403, '🚫 Akses ditolak! 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 | 𝘁.𝗺𝗲/𝗹𝗲𝗽𝗶𝗰𝗼𝗱𝗲');
            }

            return $next($request);
        });
    }

    public function index(Request $request, Node $node): View
    {
        $node = $this->repository->loadLocationAndServerCount($node);

        return $this->view->make('admin.nodes.view.index', [
            'node' => $node,
            'stats' => $this->repository->getUsageStats($node),
            'version' => $this->versionService,
        ]);
    }

    public function settings(Request $request, Node $node): View
    {
        return $this->view->make('admin.nodes.view.settings', [
            'node' => $node,
            'locations' => $this->locationRepository->all(),
        ]);
    }

    public function configuration(Request $request, Node $node): View
    {
        return $this->view->make('admin.nodes.view.configuration', compact('node'));
    }

    public function allocations(Request $request, Node $node): View
    {
        $node = $this->repository->loadNodeAllocations($node);

        $this->plainInject(['node' => Collection::wrap($node)->only(['id'])]);

        return $this->view->make('admin.nodes.view.allocation', [
            'node' => $node,
            'allocations' => Allocation::query()->where('node_id', $node->id)
                ->groupBy('ip')
                ->orderByRaw('INET_ATON(ip) ASC')
                ->get(['ip']),
        ]);
    }

    public function servers(Request $request, Node $node): View
    {
        $this->plainInject([
            'node' => Collection::wrap($node->makeVisible(['daemon_token_id', 'daemon_token']))
                ->only(['scheme', 'fqdn', 'daemonListen', 'daemon_token_id', 'daemon_token']),
        ]);

        return $this->view->make('admin.nodes.view.servers', [
            'node' => $node,
            'servers' => $this->serverRepository->loadAllServersForNode($node->id, 25),
        ]);
    }
}
EOF

chmod 644 "$REMOTE_PATH"
echo "✅ Install Proteksi Anti Modifikasi Detail Nodes 3 berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"