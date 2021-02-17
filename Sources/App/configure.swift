import Vapor
import Fluent
import FluentSQLiteDriver
import VaporCron



// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // register routes
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    app.migrations.add(CreateGalaxy())
    app.migrations.add(User.Migration())
    app.migrations.add(UserToken.Migration())
    app.migrations.add(NewUser.Migration())
   
   
    struct ComplexJob: VaporCronSchedulable {
    static var expression: String { "*/30 * * * *" }

    static func task(on application: Application) -> EventLoopFuture<Void> {
        
        NewUser.query(on:application.db).filter("created_at", .lessThan, Double(Date().timeIntervalSince1970)-Double(60)).all().map { rows in
            // rows.delete(on: application.db)
            // var rowstobedeleted = application.db.query(NewUser.self).filter("created_at", .lessThan, Double(Date().timeIntervalSince1970)-Double(120))
            // print("\(rowstobedeleted)")
            
            // rowstobedeleted.delete(force:true)
            rows.delete(force:true, on:application.db)
            print("delete operation successful")
            print("ComplexJob fired")
        }
    }
    }
    let complexJob = try app.cron.schedule(ComplexJob.self)
    

    try routes(app)
}
