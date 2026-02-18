#!/bin/bash

echo "🚀 Memasang semua proteksi Pterodactyl..."

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {}

    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    public function handle(Server $server): void
    {
        $user = Auth::user();

        if ($user) {
            if ($user->id !== 1) {
                $ownerId = $server->owner_id
                    ?? $server->user_id
                    ?? ($server->owner?->id ?? null)
                    ?? ($server->user?->id ?? null);

                if ($ownerId === null) {
                    throw new DisplayException('Akses ditolak: informasi pemilik server tidak tersedia.');
                }

                if ($ownerId !== $user->id) {
                    throw new DisplayException('Akses ditolak: Anda hanya dapat menghapus server milik Anda sendiri ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode.');
                }
            }
        }

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }
            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }
                    $database->delete();
                    Log::warning($exception);
                }
            }
            $server->delete();
        });
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi ServerDeletionService dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;

class UserController extends Controller
{
    use AvailableLanguages;

    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {}

    public function index(Request $request): View
    {
        $users = QueryBuilder::for(
            User::query()->select('users.*')
                ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
                ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
                ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
                ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
                ->groupBy('users.id')
        )
            ->allowedFilters(['username', 'email', 'uuid'])
            ->allowedSorts(['id', 'uuid'])
            ->paginate(50);

        return $this->view->make('admin.users.index', ['users' => $users]);
    }

    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function view(User $user): View
    {
        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function delete(Request $request, User $user): RedirectResponse
    {
        if ($request->user()->id !== 1) {
            throw new DisplayException("❌ Hanya admin ID 1 yang dapat menghapus user lain! ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode");
        }

        if ($request->user()->id === $user->id) {
            throw new DisplayException($this->translator->get('admin/user.exceptions.user_has_servers'));
        }

        $this->deletionService->handle($user);

        return redirect()->route('admin.users');
    }

    public function store(NewUserFormRequest $request): RedirectResponse
    {
        $user = $this->creationService->handle($request->normalize());
        $this->alert->success($this->translator->get('admin/user.notices.account_created'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        $restrictedFields = ['email', 'first_name', 'last_name', 'password'];

        foreach ($restrictedFields as $field) {
            if ($request->filled($field) && $request->user()->id !== 1) {
                throw new DisplayException("⚠️ Data hanya bisa diubah oleh admin ID 1. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode");
            }
        }

        if ($user->root_admin && $request->user()->id !== 1) {
            throw new DisplayException("🚫 Tidak dapat menurunkan hak admin pengguna ini. Hanya ID 1 yang memiliki izin. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode");
        }

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $request->normalize());

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));
            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));
            return $item;
        });
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi UserController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Location;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;
use Pterodactyl\Services\Locations\LocationUpdateService;
use Pterodactyl\Services\Locations\LocationCreationService;
use Pterodactyl\Services\Locations\LocationDeletionService;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;

class LocationController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected LocationCreationService $creationService,
        protected LocationDeletionService $deletionService,
        protected LocationRepositoryInterface $repository,
        protected LocationUpdateService $updateService,
        protected ViewFactory $view
    ) {}

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak ❌');
        }

        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    public function view(int $id): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak ❌');
        }

        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    public function create(LocationFormRequest $request): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak ❌');
        }

        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location was created successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak ❌');
        }

        if ($request->input('action') === 'delete') {
            return $this->delete($location);
        }

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location was updated successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    public function delete(Location $location): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak ❌');
        }

        try {
            $this->deletionService->handle($location->id);
            return redirect()->route('admin.locations');
        } catch (DisplayException $ex) {
            $this->alert->danger($ex->getMessage())->flash();
        }

        return redirect()->route('admin.locations.view', $location->id);
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi LocationController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth;

class NodeController extends Controller
{
    public function __construct(private ViewFactory $view) {}

    public function index(Request $request): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode');
        }

        $nodes = QueryBuilder::for(
            Node::query()->with('location')->withCount('servers')
        )
            ->allowedFilters(['uuid', 'name'])
            ->allowedSorts(['id'])
            ->paginate(25);

        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi NodeController (pertama) dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nests;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Nests\NestUpdateService;
use Pterodactyl\Services\Nests\NestCreationService;
use Pterodactyl\Services\Nests\NestDeletionService;
use Pterodactyl\Contracts\Repository\NestRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Nest\StoreNestFormRequest;
use Illuminate\Support\Facades\Auth;

class NestController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected NestCreationService $nestCreationService,
        protected NestDeletionService $nestDeletionService,
        protected NestRepositoryInterface $repository,
        protected NestUpdateService $nestUpdateService,
        protected ViewFactory $view
    ) {}

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin utama (ID 1) yang bisa membuka menu Nests. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode');
        }

        return $this->view->make('admin.nests.index', [
            'nests' => $this->repository->getWithCounts(),
        ]);
    }

    public function create(): View
    {
        return $this->view->make('admin.nests.new');
    }

    public function store(StoreNestFormRequest $request): RedirectResponse
    {
        $nest = $this->nestCreationService->handle($request->normalize());
        $this->alert->success(trans('admin/nests.notices.created', ['name' => htmlspecialchars($nest->name)]))->flash();
        return redirect()->route('admin.nests.view', $nest->id);
    }

    public function view(int $nest): View
    {
        return $this->view->make('admin.nests.view', [
            'nest' => $this->repository->getWithEggServers($nest),
        ]);
    }

    public function update(StoreNestFormRequest $request, int $nest): RedirectResponse
    {
        $this->nestUpdateService->handle($nest, $request->normalize());
        $this->alert->success(trans('admin/nests.notices.updated'))->flash();
        return redirect()->route('admin.nests.view', $nest);
    }

    public function destroy(int $nest): RedirectResponse
    {
        $this->nestDeletionService->handle($nest);
        $this->alert->success(trans('admin/nests.notices.deleted'))->flash();
        return redirect()->route('admin.nests');
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi NestController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Settings;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Settings\BaseSettingsFormRequest;

class IndexController extends Controller
{
    use AvailableLanguages;

    public function __construct(
        private AlertsMessageBag $alert,
        private Kernel $kernel,
        private SettingsRepositoryInterface $settings,
        private SoftwareVersionService $versionService,
        private ViewFactory $view
    ) {}

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak❌');
        }

        return $this->view->make('admin.settings.index', [
            'version' => $this->versionService,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function update(BaseSettingsFormRequest $request): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode - Akses ditolak ❌');
        }

        foreach ($request->normalize() as $key => $value) {
            $this->settings->set('settings::' . $key, $value);
        }

        $this->kernel->call('queue:restart');
        $this->alert->success('Panel settings have been updated successfully and the queue worker was restarted to apply these changes.')->flash();

        return redirect()->route('admin.settings');
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi Settings IndexController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Carbon\CarbonImmutable;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Services\Nodes\NodeJWTService;
use Pterodactyl\Repositories\Wings\DaemonFileRepository;
use Pterodactyl\Transformers\Api\Client\FileObjectTransformer;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CopyFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\PullFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ListFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ChmodFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DeleteFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\RenameFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CreateFolderRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DecompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\GetFileContentsRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\WriteFileContentRequest;

class FileController extends ClientApiController
{
    public function __construct(
        private NodeJWTService $jwtService,
        private DaemonFileRepository $fileRepository
    ) {
        parent::__construct();
    }

    private function checkServerAccess($request, Server $server)
    {
        $user = $request->user();
        if ($user->id === 1) {
            return;
        }
        if ($server->owner_id !== $user->id) {
            abort(403, 'Anda tidak memiliki akses ke server ini.');
        }
    }

    public function directory(ListFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);
        $contents = $this->fileRepository->setServer($server)->getDirectory($request->get('directory') ?? '/');
        return $this->fractal->collection($contents)->transformWith($this->getTransformer(FileObjectTransformer::class))->toArray();
    }

    public function contents(GetFileContentsRequest $request, Server $server): Response
    {
        $this->checkServerAccess($request, $server);
        $response = $this->fileRepository->setServer($server)->getContent($request->get('file'), config('pterodactyl.files.max_edit_size'));
        Activity::event('server:file.read')->property('file', $request->get('file'))->log();
        return new Response($response, Response::HTTP_OK, ['Content-Type' => 'text/plain']);
    }

    public function download(GetFileContentsRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);
        $token = $this->jwtService
            ->setExpiresAt(CarbonImmutable::now()->addMinutes(15))
            ->setUser($request->user())
            ->setClaims(['file_path' => rawurldecode($request->get('file')), 'server_uuid' => $server->uuid])
            ->handle($server->node, $request->user()->id . $server->uuid);
        Activity::event('server:file.download')->property('file', $request->get('file'))->log();
        return ['object' => 'signed_url', 'attributes' => ['url' => sprintf('%s/download/file?token=%s', $server->node->getConnectionAddress(), $token->toString())]];
    }

    public function write(WriteFileContentRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->putContent($request->get('file'), $request->getContent());
        Activity::event('server:file.write')->property('file', $request->get('file'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function create(CreateFolderRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->createDirectory($request->input('name'), $request->input('root', '/'));
        Activity::event('server:file.create-directory')->property('name', $request->input('name'))->property('directory', $request->input('root'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function rename(RenameFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->renameFiles($request->input('root'), $request->input('files'));
        Activity::event('server:file.rename')->property('directory', $request->input('root'))->property('files', $request->input('files'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function copy(CopyFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->copyFile($request->input('location'));
        Activity::event('server:file.copy')->property('file', $request->input('location'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function compress(CompressFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);
        $file = $this->fileRepository->setServer($server)->compressFiles($request->input('root'), $request->input('files'));
        Activity::event('server:file.compress')->property('directory', $request->input('root'))->property('files', $request->input('files'))->log();
        return $this->fractal->item($file)->transformWith($this->getTransformer(FileObjectTransformer::class))->toArray();
    }

    public function decompress(DecompressFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        set_time_limit(300);
        $this->fileRepository->setServer($server)->decompressFile($request->input('root'), $request->input('file'));
        Activity::event('server:file.decompress')->property('directory', $request->input('root'))->property('files', $request->input('file'))->log();
        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }

    public function delete(DeleteFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->deleteFiles($request->input('root'), $request->input('files'));
        Activity::event('server:file.delete')->property('directory', $request->input('root'))->property('files', $request->input('files'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function chmod(ChmodFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->chmodFiles($request->input('root'), $request->input('files'));
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function pull(PullFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->pull($request->input('url'), $request->input('directory'), $request->safe(['filename', 'use_header', 'foreground']));
        Activity::event('server:file.pull')->property('directory', $request->input('directory'))->property('url', $request->input('url'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi FileController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;
use Pterodactyl\Services\Servers\GetUserPermissionsService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;

class ServerController extends ClientApiController
{
    public function __construct(private GetUserPermissionsService $permissionsService)
    {
        parent::__construct();
    }

    public function index(GetServerRequest $request, Server $server): array
    {
        $authUser = Auth::user();

        if ($authUser->id !== 1 && (int) $server->owner_id !== (int) $authUser->id) {
            abort(403, '©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode • Lu ngapain kocak😹😹. cuma bisa buka server lu sendiri.');
        }

        return $this->fractal->item($server)
            ->transformWith($this->getTransformer(ServerTransformer::class))
            ->addMeta([
                'is_server_owner' => $request->user()->id === $server->owner_id,
                'user_permissions' => $this->permissionsService->handle($server, $request->user()),
            ])
            ->toArray();
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi ServerController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
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
            throw new AccessDeniedHttpException('❌ Kamu tidak diizinkan mengubah detail server ini - ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode.');
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
                } catch (DaemonConnectionException $exception) {}
            }

            return $server;
        });
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi DetailsModificationService dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/NodesController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Illuminate\Http\Response;
use Pterodactyl\Models\Allocation;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Nodes\NodeUpdateService;
use Illuminate\Cache\Repository as CacheRepository;
use Pterodactyl\Services\Nodes\NodeCreationService;
use Pterodactyl\Services\Nodes\NodeDeletionService;
use Pterodactyl\Services\Allocations\AssignmentService;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Http\Requests\Admin\Node\NodeFormRequest;
use Pterodactyl\Contracts\Repository\NodeRepositoryInterface;
use Pterodactyl\Contracts\Repository\ServerRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Node\AllocationFormRequest;
use Pterodactyl\Services\Allocations\AllocationDeletionService;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;
use Pterodactyl\Contracts\Repository\AllocationRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Node\AllocationAliasFormRequest;

class NodesController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected AllocationDeletionService $allocationDeletionService,
        protected AllocationRepositoryInterface $allocationRepository,
        protected AssignmentService $assignmentService,
        protected CacheRepository $cache,
        protected NodeCreationService $creationService,
        protected NodeDeletionService $deletionService,
        protected LocationRepositoryInterface $locationRepository,
        protected NodeRepositoryInterface $repository,
        protected ServerRepositoryInterface $serverRepository,
        protected NodeUpdateService $updateService,
        protected SoftwareVersionService $versionService,
        protected ViewFactory $view
    ) {
        if (auth()->check() && auth()->user()->id !== 1) {
            abort(403, '🚫 Anda tidak diizinkan melakukan maintenance terhadap nodes.');
        }
    }

    public function create(): View|RedirectResponse
    {
        $locations = $this->locationRepository->all();
        if (count($locations) < 1) {
            $this->alert->warning(trans('admin/node.notices.location_required'))->flash();
            return redirect()->route('admin.locations');
        }
        return $this->view->make('admin.nodes.new', ['locations' => $locations]);
    }

    public function store(NodeFormRequest $request): RedirectResponse
    {
        $node = $this->creationService->handle($request->normalize());
        $this->alert->info(trans('admin/node.notices.node_created'))->flash();
        return redirect()->route('admin.nodes.view.allocation', $node->id);
    }

    public function updateSettings(NodeFormRequest $request, Node $node): RedirectResponse
    {
        $this->updateService->handle($node, $request->normalize(), $request->input('reset_secret') === 'on');
        $this->alert->success(trans('admin/node.notices.node_updated'))->flash();
        return redirect()->route('admin.nodes.view.settings', $node->id)->withInput();
    }

    public function allocationRemoveSingle(int $node, Allocation $allocation): Response
    {
        $this->allocationDeletionService->handle($allocation);
        return response('', 204);
    }

    public function allocationRemoveMultiple(Request $request, int $node): Response
    {
        $allocations = $request->input('allocations');
        foreach ($allocations as $rawAllocation) {
            $allocation = new Allocation();
            $allocation->id = $rawAllocation['id'];
            $this->allocationRemoveSingle($node, $allocation);
        }
        return response('', 204);
    }

    public function allocationRemoveBlock(Request $request, int $node): RedirectResponse
    {
        $this->allocationRepository->deleteWhere([
            ['node_id', '=', $node],
            ['server_id', '=', null],
            ['ip', '=', $request->input('ip')],
        ]);
        $this->alert->success(trans('admin/node.notices.unallocated_deleted', ['ip' => htmlspecialchars($request->input('ip'))]))->flash();
        return redirect()->route('admin.nodes.view.allocation', $node);
    }

    public function allocationSetAlias(AllocationAliasFormRequest $request): \Symfony\Component\HttpFoundation\Response
    {
        $this->allocationRepository->update($request->input('allocation_id'), [
            'ip_alias' => (empty($request->input('alias'))) ? null : $request->input('alias'),
        ]);
        return response('', 204);
    }

    public function createAllocation(AllocationFormRequest $request, Node $node): RedirectResponse
    {
        $this->assignmentService->handle($node, $request->normalize());
        $this->alert->success(trans('admin/node.notices.allocations_added'))->flash();
        return redirect()->route('admin.nodes.view.allocation', $node->id);
    }

    public function delete(int|Node $node): RedirectResponse
    {
        $this->deletionService->handle($node);
        $this->alert->success(trans('admin/node.notices.node_deleted'))->flash();
        return redirect()->route('admin.nodes');
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi NodesController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
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
                Log::warning('🚨 Percobaan akses NodeViewController tanpa izin', [
                    'user_id' => $user?->id,
                    'ip' => $request->ip(),
                    'route' => $request->path(),
                    'method' => $request->method(),
                    'time' => now()->toDateTimeString(),
                ]);
                abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang boleh mengakses menu Nodes. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode');
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
echo "✅ Proteksi NodeViewController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/SystemInformationController.php"
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
            \Log::warning('🚨 Percobaan akses SystemInformationController tanpa izin', [
                'user_id' => $user?->id,
                'ip' => request()->ip(),
                'route' => request()->path(),
                'method' => request()->method(),
                'time' => now()->toDateTimeString(),
            ]);
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang boleh mengakses System Information Nodes. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode');
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
echo "✅ Proteksi SystemInformationController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth;

class NodeController extends Controller
{
    public function __construct(private ViewFactory $view) {}

    public function index(Request $request): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes. ©𝗣𝗿𝗼𝘁𝗲𝗰𝘁 𝗕𝘆 𝗟𝗲𝘃𝘃𝗶𝗖𝗼𝗱𝗲 t.me/lepicode');
        }

        $nodes = QueryBuilder::for(
            Node::query()->with('location')->withCount('servers')
        )
            ->allowedFilters(['uuid', 'name'])
            ->allowedSorts(['id'])
            ->paginate(25);

        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi NodeController (kedua) dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Servers/ServerTransferController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Servers;

use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
use Pterodactyl\Models\ServerTransfer;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Nodes\NodeJWTService;
use Pterodactyl\Repositories\Eloquent\NodeRepository;
use Pterodactyl\Repositories\Wings\DaemonTransferRepository;
use Pterodactyl\Contracts\Repository\AllocationRepositoryInterface;

class ServerTransferController extends Controller
{
    public function __construct(
        private AlertsMessageBag $alert,
        private AllocationRepositoryInterface $allocationRepository,
        private ConnectionInterface $connection,
        private DaemonTransferRepository $daemonTransferRepository,
        private NodeJWTService $nodeJWTService,
        private NodeRepository $nodeRepository
    ) {}

    private function authorizeTransfer(): void
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'Anda tidak memiliki izin untuk mentransfer server.');
        }
    }

    public function transfer(Request $request, Server $server): RedirectResponse
    {
        $this->authorizeTransfer();

        $validatedData = $request->validate([
            'node_id' => 'required|exists:nodes,id',
            'allocation_id' => 'required|bail|unique:servers|exists:allocations,id',
            'allocation_additional' => 'nullable',
        ]);

        $node_id = $validatedData['node_id'];
        $allocation_id = intval($validatedData['allocation_id']);
        $additional_allocations = array_map('intval', $validatedData['allocation_additional'] ?? []);

        $node = $this->nodeRepository->getNodeWithResourceUsage($node_id);
        if (!$node->isViable($server->memory, $server->disk)) {
            $this->alert->danger(trans('admin/server.alerts.transfer_not_viable'))->flash();
            return redirect()->route('admin.servers.view.manage', $server->id);
        }

        $server->validateTransferState();

        $this->connection->transaction(function () use ($server, $node_id, $allocation_id, $additional_allocations) {
            $transfer = new ServerTransfer();
            $transfer->server_id = $server->id;
            $transfer->old_node = $server->node_id;
            $transfer->new_node = $node_id;
            $transfer->old_allocation = $server->allocation_id;
            $transfer->new_allocation = $allocation_id;
            $transfer->old_additional_allocations = $server->allocations->where('id', '!=', $server->allocation_id)->pluck('id');
            $transfer->new_additional_allocations = $additional_allocations;
            $transfer->save();

            $this->assignAllocationsToServer($server, $node_id, $allocation_id, $additional_allocations);

            $token = $this->nodeJWTService
                ->setExpiresAt(CarbonImmutable::now()->addMinutes(15))
                ->setSubject($server->uuid)
                ->handle($transfer->newNode, $server->uuid, 'sha256');

            $this->daemonTransferRepository->setServer($server)->notify($transfer->newNode, $token);

            return $transfer;
        });

        $this->alert->success(trans('admin/server.alerts.transfer_started'))->flash();
        return redirect()->route('admin.servers.view.manage', $server->id);
    }

    private function assignAllocationsToServer(Server $server, int $node_id, int $allocation_id, array $additional_allocations)
    {
        $allocations = $additional_allocations;
        $allocations[] = $allocation_id;

        $unassigned = $this->allocationRepository->getUnassignedAllocationIds($node_id);

        $updateIds = [];
        foreach ($allocations as $allocation) {
            if (!in_array($allocation, $unassigned)) {
                continue;
            }
            $updateIds[] = $allocation;
        }

        if (!empty($updateIds)) {
            $this->allocationRepository->updateWhereIn('id', $updateIds, ['server_id' => $server->id]);
        }
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi ServerTransferController dipasang."

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Servers/ServerViewController.php"
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Servers;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Nest;
use Pterodactyl\Models\Server;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Servers\EnvironmentService;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Pterodactyl\Repositories\Eloquent\NestRepository;
use Pterodactyl\Repositories\Eloquent\NodeRepository;
use Pterodactyl\Repositories\Eloquent\MountRepository;
use Pterodactyl\Repositories\Eloquent\ServerRepository;
use Pterodactyl\Traits\Controllers\JavascriptInjection;
use Pterodactyl\Repositories\Eloquent\LocationRepository;
use Pterodactyl\Repositories\Eloquent\DatabaseHostRepository;

class ServerViewController extends Controller
{
    use JavascriptInjection;

    public function __construct(
        private DatabaseHostRepository $databaseHostRepository,
        private LocationRepository $locationRepository,
        private MountRepository $mountRepository,
        private NestRepository $nestRepository,
        private NodeRepository $nodeRepository,
        private ServerRepository $repository,
        private EnvironmentService $environmentService,
        private ViewFactory $view
    ) {}

    private function authorizeServerAccess(Server $server): void
    {
        $user = Auth::user();
        if ($user->id !== 1 && $server->owner_id !== $user->id) {
            abort(403, 'Anda tidak memiliki izin untuk mengakses server ini.');
        }
    }

    public function index(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        return $this->view->make('admin.servers.view.index', compact('server'));
    }

    public function details(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        return $this->view->make('admin.servers.view.details', compact('server'));
    }

    public function build(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        $allocations = $server->node->allocations->toBase();
        return $this->view->make('admin.servers.view.build', [
            'server' => $server,
            'assigned' => $allocations->where('server_id', $server->id)->sortBy('port')->sortBy('ip'),
            'unassigned' => $allocations->where('server_id', null)->sortBy('port')->sortBy('ip'),
        ]);
    }

    public function startup(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        $nests = $this->nestRepository->getWithEggs();
        $variables = $this->environmentService->handle($server);

        $this->plainInject([
            'server' => $server,
            'server_variables' => $variables,
            'nests' => $nests->map(function (Nest $item) {
                return array_merge($item->toArray(), ['eggs' => $item->eggs->keyBy('id')->toArray()]);
            })->keyBy('id'),
        ]);

        return $this->view->make('admin.servers.view.startup', compact('server', 'nests'));
    }

    public function database(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        return $this->view->make('admin.servers.view.database', [
            'hosts' => $this->databaseHostRepository->all(),
            'server' => $server,
        ]);
    }

    public function mounts(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        $server->load('mounts');
        return $this->view->make('admin.servers.view.mounts', [
            'mounts' => $this->mountRepository->getMountListForServer($server),
            'server' => $server,
        ]);
    }

    public function manage(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);

        if ($server->status === Server::STATUS_INSTALL_FAILED) {
            throw new DisplayException('This server is in a failed install state and cannot be recovered. Please delete and re-create the server.');
        }

        $nodes = $this->nodeRepository->all();
        $canTransfer = count($nodes) >= 2;

        \JavaScript::put(['nodeData' => $this->nodeRepository->getNodesForServerCreation()]);

        return $this->view->make('admin.servers.view.manage', [
            'server' => $server,
            'locations' => $this->locationRepository->all(),
            'canTransfer' => $canTransfer,
        ]);
    }

    public function delete(Request $request, Server $server): View
    {
        $this->authorizeServerAccess($server);
        return $this->view->make('admin.servers.view.delete', compact('server'));
    }
}
EOF
chmod 644 "$REMOTE_PATH"
echo "✅ Proteksi ServerViewController dipasang."

echo "🎉 Semua proteksi berhasil dipasang!"
