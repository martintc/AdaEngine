//
//  PhysicsWorld2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/6/22.
//

@_implementationOnly import box2d
import Math

/// An object that holds and simulate all 2D physics bodies.
public final class PhysicsWorld2D: Codable {

    enum CodingKeys: CodingKey {
        case velocityIterations
        case positionIterations
        case gravity
    }
    
    public var velocityIterations: Int = 6
    public var positionIterations: Int = 2
    
    /// Contains world gravity.
    public var gravity: Vector2 {
        get {
            return self.world.GetGravity().asVector2
        }

        set {
            self.world.SetGravity(newValue.b2Vec)
        }
    }
    
    private let worldPtr: UnsafeMutablePointer<b2World>
    private var world: b2World {
        worldPtr.pointee
    }
    
    weak var scene: Scene?
    let contactListner = _Physics2DContactListener()
    
    /// - Parameter gravity: default gravity is 9.8.
    init(gravity: Vector2 = [0, -9.81]) {
        self.worldPtr = UnsafeMutablePointer<b2World>.allocate(capacity: 1)
        self.worldPtr.initialize(to: b2World.CreateWorld(gravity.b2Vec))
        
        self.world.SetContactListener(self.contactListner.contactListener)
    }
    
    deinit {
        self.worldPtr.deallocate()
    }
    
    public nonisolated convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gravity = try container.decode(Vector2.self, forKey: .gravity)

        self.init(gravity: gravity)

        self.velocityIterations = try container.decode(Int.self, forKey: .velocityIterations)
        self.positionIterations = try container.decode(Int.self, forKey: .positionIterations)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.gravity, forKey: .gravity)
        try container.encode(self.velocityIterations, forKey: .velocityIterations)
        try container.encode(self.positionIterations, forKey: .positionIterations)
    }
    
    // MARK: - Public
    
    /// Clear all forces in physics world.
    public func clearForces() {
        self.world.ClearForces()
    }
    
    // MARK: - Raycasting
    
    /// An array of collision cast hit results.
    /// Each hit indicates where the ray, starting at a given point and traveling in a given direction, hit a particular entity in the scene.
    public func raycast(
        from startPoint: Vector2,
        to endPoint: Vector2,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [Raycast2DHit] {
        let callback = _Raycast2DCallback(startPoint: startPoint, endPoint: endPoint, query: query, mask: mask)
        
        let userData = Unmanaged.passUnretained(callback)
        let listenerPointer = UnsafeMutablePointer<SwiftRayCastCallback>.allocate(capacity: 1)
        listenerPointer.initialize(to: SwiftRayCastCallback.CreateListener(userData.toOpaque()))
        
        listenerPointer.pointee.m_ReportFixture = { userData, fixture, point, normal, fraction in
            let raycast = Unmanaged<_Raycast2DCallback>.fromOpaque(userData!).takeUnretainedValue()
            return raycast.reportFixture(fixture!, point: point, normal: normal, fraction: fraction)
        }
        
        let raycastCallback = UnsafeMutableRawPointer(listenerPointer).assumingMemoryBound(to: b2RayCastCallback.self)
        world.RayCast(raycastCallback, startPoint.b2Vec, endPoint.b2Vec)
        
        listenerPointer.deallocate()
        
        return callback.results
    }
    
    /// An array of collision cast hit results.
    /// Each hit indicates where the ray, starting at a given point and traveling in a given direction, hit a particular entity in the scene.
    public func raycast(
        from ray: Ray,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [Raycast2DHit] {
        return self.raycast(from: ray.origin.xy, to: ray.direction.xy, query: query, mask: mask)
    }
    
    // MARK: - Internal
    
    internal func updateSimulation(_ delta: Float) {
        self.world.Step(
            delta, /* timeStep */
            int32(self.velocityIterations), /* velocityIterations */
            int32(self.positionIterations) /* positionIterations */
        )
    }
    
    internal func destroyBody(_ body: Body2D) {
        self.world.DestroyBody(body.ref)
    }
    
    internal func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
        var bodyDef = b2BodyDef()
        bodyDef.angle = definition.angle
        bodyDef.position = definition.position.b2Vec
        bodyDef.type = definition.bodyMode.b2Type
        bodyDef.gravityScale = definition.gravityScale
        bodyDef.allowSleep = definition.allowSleep
        bodyDef.fixedRotation = definition.fixedRotation
        bodyDef.bullet = definition.bullet
        bodyDef.awake = definition.awake
        
        bodyDef.angularDamping = definition.angularDamping
        bodyDef.angularVelocity = definition.angularVelocity
        bodyDef.linearDamping = definition.linearDamping
        bodyDef.linearVelocity = definition.linearVelocity.b2Vec
        
        guard let body = self.world.CreateBody(&bodyDef) else {
            fatalError("Failed to create body")
        }
        
        let body2d = Body2D(world: self, ref: body, entity: entity)
        let pointer = Unmanaged.passUnretained(body2d).toOpaque()
        body.GetUserDataMutating().pointee.pointer = UInt(bitPattern: OpaquePointer(pointer))
        
        return body2d
    }
}

// MARK: - Casting

extension Vector2 {
    var b2Vec: b2Vec2 {
        get {
            return unsafeBitCast(self, to: b2Vec2.self)
        }
        
        set {
            self = unsafeBitCast(newValue, to: Vector2.self)
        }
    }
}

extension b2Vec2 {
    var asVector2: Vector2 {
        return unsafeBitCast(self, to: Vector2.self)
    }
}

extension PhysicsBodyMode {
    var b2Type: b2BodyType {
        switch self {
        case .static: return b2_staticBody
        case .dynamic: return b2_dynamicBody
        case .kinematic: return b2_kinematicBody
        }
    }

    init(b2BodyType: b2BodyType) {
        switch b2BodyType {
        case b2_staticBody: self = .static
        case b2_dynamicBody: self = .dynamic
        case b2_kinematicBody: self = .kinematic
        default:
            self = .static
        }
    }
}

// MARK: - b2RaycastCallback

/// A hit result of a collision cast.
public struct Raycast2DHit {
    
    /// The entity that was hit.
    public let entity: Entity
    
    /// The point of the hit.
    public let point: Vector2
    
    /// The normal of the hit.
    public let normal: Vector2
    
    /// The distance from the ray origin to the hit, or the convex shape travel distance.
    public let distance: Float
}

fileprivate final class _Raycast2DCallback {
    
    var results: [Raycast2DHit] = []
    
    let startPoint: Vector2
    let endPoint: Vector2
    let query: CollisionCastQueryType
    let mask: CollisionGroup
    
    enum RaycastReporting {
        static let `continue`: Float = 1.0
        static let terminate: Float = 0.0
    }
    
    init(startPoint: Vector2, endPoint: Vector2, query: CollisionCastQueryType, mask: CollisionGroup) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.query = query
        self.mask = mask
    }
    
    func reportFixture(_ fixture: b2Fixture, point: b2Vec2, normal: b2Vec2, fraction: Float) -> Float {
        let fixtureBody = fixture.GetBody()!
        let userData = fixtureBody.GetUserData().pointee
        
        let filterData = fixture.GetFilterData().pointee
        
        if !(filterData.maskBits == self.mask.rawValue) {
            return RaycastReporting.continue
        }
        
        let pointer = UnsafeRawPointer(OpaquePointer(bitPattern: userData.pointer)!)
        let body = Unmanaged<Body2D>.fromOpaque(pointer).takeUnretainedValue()
        
        guard let entity = body.entity else {
            return RaycastReporting.continue
        }
        
        // FIXME: Check distance
        let distance = (self.startPoint - self.endPoint).squaredLength * fraction
        
        let result = Raycast2DHit(
            entity: entity,
            point: point.asVector2,
            normal: normal.asVector2,
            distance: distance
        )
        
        self.results.append(result)
        
        if query == .first {
            return RaycastReporting.terminate
        } else {
            return RaycastReporting.continue
        }
    }
}

// MARK: - b2ContactListener

final class _Physics2DContactListener {

    lazy var contactListener: UnsafeMutablePointer<b2ContactListener> = {
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let listener = SwiftContactListener2D.CreateListener(userData)
        
        listener.m_BeginContact = { userData, contact in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.beginContact(contact!)
        }
        
        listener.m_EndContact = { userData, contact in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.endContact(contact!)
        }
        
        listener.m_PreSolve = { userData, contact, manifold in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.preSolve(contact!, oldManifold: manifold)
        }
        
        listener.m_PostSolve = { userData, contact, impulse in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.postSolve(contact!, impulse: impulse!)
        }
        
        return Unmanaged.passRetained(listener).toOpaque().assumingMemoryBound(to: b2ContactListener.self)
    }()

    deinit {
        self.contactListener.deallocate()
    }

    func beginContact(_ contact: b2Contact) {
        let fixtureA = contact.GetFixtureA()!
        let fixtureB = contact.GetFixtureB()!
        
        let bodyFixtureA = fixtureA.GetBody()!
        let bodyFixtureB = fixtureB.GetBody()!
        
        let userDataA = bodyFixtureA.GetUserData()
        let userDataB = bodyFixtureB.GetUserData()
        
        let userDataAPtr = OpaquePointer(bitPattern: userDataA.pointee.pointer)!
        let userDataBPtr = OpaquePointer(bitPattern: userDataB.pointee.pointer)!
        
        // FIXME: We should get correct impulse of contact
        let manifold = contact.GetManifold()

        let bodyA = Unmanaged<Body2D>.fromOpaque(UnsafeRawPointer(userDataAPtr)).takeUnretainedValue()
        let bodyB = Unmanaged<Body2D>.fromOpaque(UnsafeRawPointer(userDataBPtr)).takeUnretainedValue()

//        let impulse = contact.GetManifold().pointee.points.0.normalImpulse
        
        guard let entityA = bodyA.entity, let entityB = bodyB.entity else {
            return
        }
        
        let event = CollisionEvents.Began(
            entityA: entityA,
            entityB: entityB,
            impulse: 0
        )

        bodyA.world.scene?.eventManager.send(event)
    }
    
    func endContact(_ contact: b2Contact) {
        let fixtureA = contact.GetFixtureA()!
        let fixtureB = contact.GetFixtureB()!
        
        let bodyFixtureA = fixtureA.GetBody()!
        let bodyFixtureB = fixtureB.GetBody()!
        
        let userDataA = bodyFixtureA.GetUserData()
        let userDataB = bodyFixtureB.GetUserData()
        
        let userDataAPtr = OpaquePointer(bitPattern: userDataA.pointee.pointer)!
        let userDataBPtr = OpaquePointer(bitPattern: userDataB.pointee.pointer)!

        let bodyA = Unmanaged<Body2D>.fromOpaque(UnsafeRawPointer(userDataAPtr)).takeUnretainedValue()
        let bodyB = Unmanaged<Body2D>.fromOpaque(UnsafeRawPointer(userDataBPtr)).takeUnretainedValue()
        
        guard let entityA = bodyA.entity, let entityB = bodyB.entity else {
            return
        }
        
        let event = CollisionEvents.Ended(
            entityA: entityA,
            entityB: entityB
        )

        bodyA.world.scene?.eventManager.send(event)
    }

    func postSolve(_ contact: b2Contact, impulse: UnsafePointer<b2ContactImpulse>?) {
        return
    }

    func preSolve(_ contact: b2Contact, oldManifold: UnsafePointer<b2Manifold>?) {
        return
    }
}

extension OpaquePointer {
    
    // TODO: Should we deallocate it in this place?
    func deallocate() {
        UnsafeRawPointer(self).deallocate()
    }
}
