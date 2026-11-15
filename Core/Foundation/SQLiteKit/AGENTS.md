# SQLiteKit

**Purpose:** The app's one SQLite database: opening it, migrating every module's tables in order, recovering from a broken file, and the single bridge that hands it to sqlite-data.
**Tier:** Foundation
**Project deps:** none (packages: `SQLiteData`, `Dependencies`, `FactoryKit`)
**Public Factory keys:** `database` (`.singleton`; in-memory `.onTest`), `databaseSchemas` (bound by the app)
**Entry points:**
- `AppDatabase` — `openOrRecover(at:schemas:)` (a `DatabasePool` in Application Support, excluded from backups), `inMemory(schemas:)` for tests and previews, `bridgeToSQLiteData(_:)`.
- `DatabaseSchema` — one module's migrations; the module that owns tables exposes `DatabaseSchema.<name>`.
- `BackgroundReadScheduler` (`.backgroundRead`) — the scheduler for a fetch wrapper's `load(_:scheduler:)`.

**Ownership map:**
- The database connection → `Container.database`, opened on first use.
- Which tables exist, in which order → `Container.databaseSchemas`, bound once in the app's `autoRegister()`.
- sqlite-data's `defaultDatabase` → set once per process by `AppDatabase.bridgeToSQLiteData` (AppDelegate's `didFinishLaunching`).

## Rules

- This module holds the only Point-Free `@Dependency`/`prepareDependencies` use in the app (lint `no_dependency_property_wrapper`). Everything else gets the database from FactoryKit or through sqlite-data's wrappers.
- Everything stored locally mirrors the server or the outbox, so a corrupt file (`SQLITE_CORRUPT`, `SQLITE_NOTADB`) or one its migrations fail on is deleted and created again. When the device can't open it (disk full, I/O, permissions, locked), the launch runs in memory and the file, with the unsent outbox, is kept. In-memory is also the last resort when recreating fails.
- Migrations are `#sql` strings in `STRICT` tables, registered by the owning module's `DatabaseSchema`. DEBUG erases the database on a schema change; release must only ever add migrations.
- Foreign keys are on.
- **Changing a `@Fetch`/`@FetchAll`'s query** (`$x.load(query)`) passes `scheduler: .backgroundRead`. With the default scheduler sqlite-data reads the new query on the main actor and drops that value before its own background read (`FetchKey`: `ImmediateScheduler`, `dropFirst` for a load): measured at about 15 ms for a 2000-spot viewport and 50 ms for a 5000-spot city in a Debug simulator build, on every map rest. A wrapper made with its query keeps the default: that synchronous read is its first value, and the cached first frame.
