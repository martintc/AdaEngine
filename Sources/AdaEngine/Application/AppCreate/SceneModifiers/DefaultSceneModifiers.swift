//
//  DefaultSceneModifiers.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

/// Set the minimum size of presented window.
struct MinimumWindowSizeSceneModifier: SceneModifier {
    
    let size: Size
    
    func modify(_ configuration: inout _AppSceneConfiguration) {
        configuration.minimumSize = self.size
    }
}

/// Set the window mode.
struct WindowModeSceneModifier: SceneModifier {
    
    let windowMode: Window.Mode
    
    func modify(_ configuration: inout _AppSceneConfiguration) {
        configuration.windowMode = self.windowMode
    }
}

/// Set flag if we can't create more than one window per app.
struct IsSingleWindowSceneModifier: SceneModifier {
    let isSingleWindow: Bool
    
    func modify(_ configuration: inout _AppSceneConfiguration) {
        configuration.isSingleWindow = self.isSingleWindow
    }
}

/// Set the title for the window.
struct WindowTitleSceneModifier: SceneModifier {
    let title: String
    
    func modify(_ configuration: inout _AppSceneConfiguration) {
        configuration.title = self.title
    }
}

/// Add render world plugin.
struct RenderWorldPlugin<T: ScenePlugin>: SceneModifier {
    let plugin: T
    
    func modify(_ configuration: inout _AppSceneConfiguration) {
        configuration.plugins.append(plugin)
    }
}

/// Set flag for using defaults render plugins. Users can disable default plugins and set up their own plugins.
struct UseDefaultRenderPlugins: SceneModifier {
    let isEnabled: Bool
    
    func modify(_ configuration: inout _AppSceneConfiguration) {
        configuration.useDefaultRenderPlugins = isEnabled
    }
}
