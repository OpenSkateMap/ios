public import FactoryKit
public import SQLiteData

extension Container {
    public var databaseSchemas: Factory<[DatabaseSchema]> {
        self { [] }.singleton
    }

    public var database: Factory<any DatabaseWriter> {
        self { AppDatabase.openOrRecover(at: AppDatabase.defaultURL, schemas: self.databaseSchemas()) }
            .singleton
            .onTest { try! AppDatabase.inMemory(schemas: self.databaseSchemas()) }
    }
}
