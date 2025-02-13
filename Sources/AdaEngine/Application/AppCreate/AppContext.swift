//
//  AppContext.swift
//  
//
//  Created by v.prusakov on 4/30/24.
//

final class AppContext<T: App> {

    private var app: T
    private var application: Application

    init() throws {
        self.app = T.init()

        let argc = CommandLine.argc
        let argv = CommandLine.unsafeArgv

#if os(macOS)
        self.application = try MacApplication(argc: argc, argv: argv)
#endif

#if os(iOS) || os(tvOS)
        self.application = try iOSApplication(argc: argc, argv: argv)
#endif

#if os(Android)
        self.application = try AndroidApplication(argc: argc, argv: argv)
#endif

#if os(Linux)
        self.application = try LinuxApplication(argc: argc, argv: argv)
#endif
    }

    func setup() throws {
        try ResourceManager.initialize()
        try AudioServer.initialize()
        
        RuntimeTypeLoader.loadTypes()

        guard let appScene = app.scene as? InternalAppScene else {
            fatalError("Incorrect object of App Scene")
        }

        Task { @MainActor in
            var configuration = _AppSceneConfiguration()
            appScene._buildConfiguration(&configuration)
            let window = try await appScene._makeWindow(with: configuration)

            if configuration.useDefaultRenderPlugins {
                await self.application.renderWorld.addPlugin(DefaultRenderPlugin())
            }

            for plugin in configuration.plugins {
                await self.application.renderWorld.addPlugin(plugin)
            }

            window.showWindow(makeFocused: true)
        }
    }

    func runApplication() throws {
        try AudioServer.shared.start()

        try application.run()

        try AudioServer.shared.stop()
    }
}
