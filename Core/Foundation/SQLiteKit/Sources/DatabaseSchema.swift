public import SQLiteData

public struct DatabaseSchema: Sendable {
    public let registerMigrations: @Sendable (inout DatabaseMigrator) -> Void

    public init(registerMigrations: @escaping @Sendable (inout DatabaseMigrator) -> Void) {
        self.registerMigrations = registerMigrations
    }
}
