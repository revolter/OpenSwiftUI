//
//  ViewGraph.swift
//  OpenSwiftUI
//
//  Audited for RELEASE_2021
//  Status: WIP
//  ID: D63C4EB7F2B205694B6515509E76E98B

internal import OpenGraphShims
import Foundation

final class ViewGraph: GraphHost {
    @inline(__always)
    static var current: ViewGraph { GraphHost.currentHost as! ViewGraph }
    
    let rootViewType: Any.Type
    let makeRootView: (OGAttribute, _ViewInputs) -> _ViewOutputs
    weak var delegate: ViewGraphDelegate?
    var centersRootView: Bool = true
    let rootView: OGAttribute
    @Attribute var rootTransform: ViewTransform
    @Attribute var zeroPoint: ViewOrigin
    // TODO
    @Attribute var proposedSize: ViewSize
    // TODO
    @Attribute var rootGeometry: ViewGeometry
    @Attribute var position: ViewOrigin
    @Attribute var dimensions: ViewSize
    @Attribute var updateSeed: UInt32
    // TODO
    @Attribute var defaultLayoutComputer: LayoutComputer
    // TODO
    var cachedSizeThatFits: CGSize = .invalidValue
    var sizeThatFitsObserver: SizeThatFitsObserver? {
        didSet {
            guard let _ = sizeThatFitsObserver else {
                return
            }
            guard requestedOutputs.contains(.layout) else {
                fatalError("Cannot use sizeThatFits without layout output")
            }
        }
    }
    var requestedOutputs: Outputs
    var disabledOutputs: Outputs = []
    var mainUpdates: Int = 0
    var needsFocusUpdate: Bool = false
    var nextUpdate: (views: NextUpdate, gestures: NextUpdate) = (NextUpdate(time: .infinity), NextUpdate(time: .infinity))
    private weak var _preferenceBridge: PreferenceBridge?
    var preferenceBridge: PreferenceBridge? {
        get { _preferenceBridge }
        // FIXME: TO BE CONFIRMED
        set { setPreferenceBridge(to: newValue, isInvalidating: newValue == nil) }
    }
    #if canImport(Darwin) // FIXME: See #39
    var bridgedPreferences: [(AnyPreferenceKey.Type, OGAttribute)] = []
    #endif
    // TODO
    
    init<Body: View>(rootViewType: Body.Type, requestedOutputs: Outputs) {
        #if canImport(Darwin)
        self.rootViewType = rootViewType
        self.requestedOutputs = requestedOutputs
        
        let data = GraphHost.Data()
        OGSubgraph.current = data.globalSubgraph
        rootView = Attribute(type: Body.self).identifier
        _rootTransform = Attribute(RootTransform())
        _zeroPoint = Attribute(value: .zero)
        // TODO
        _proposedSize = Attribute(value: .zero)
        // TODO
        _rootGeometry = Attribute(RootGeometry(proposedSize: _proposedSize))
        _position = _rootGeometry.origin()
        _dimensions = _rootGeometry.size()
        _updateSeed = Attribute(value: .zero)
        // TODO
        _defaultLayoutComputer = Attribute(value: .defaultValue)
        // FIXME
        makeRootView = { view, inputs in
            let rootView = _GraphValue<Body>(view.unsafeCast(to: Body.self))
            return Body._makeView(view: rootView, inputs: inputs)
        }
        super.init(data: data)
        OGSubgraph.current = nil
        #else
        fatalError("TOOD")
        #endif
    }
    
    @inline(__always)
    func updateOutputs(at time: Time) {
        beginNextUpdate(at: time)
        updateOutputs()
    }
    
    private func beginNextUpdate(at time: Time) {
        setTime(time)
        updateSeed &+= 1
        mainUpdates = graph.mainUpdates
    }
    
    private func updateOutputs() {
        #if canImport(Darwin)
        instantiateIfNeeded()
        
        let oldCachedSizeThatFits = cachedSizeThatFits
        
        var preferencesChanged = false
        var observedSizeThatFitsChanged = false
        var updatedOutputs: Outputs = []
        
        var counter1 = 0
        repeat {
            counter1 &+= 1
            inTransaction = true
            var counter2 = 0
            repeat {
                let conts = continuations
                continuations = []
                for continuation in conts {
                    continuation()
                }
                counter2 &+= 1
                data.globalSubgraph.update(flags: .active)
            } while (continuations.count != 0 && counter2 != 8)
            inTransaction = false
            preferencesChanged = preferencesChanged || updatePreferences()
            observedSizeThatFitsChanged = observedSizeThatFitsChanged || updateObservedSizeThatFits()
            updatedOutputs.formUnion(updateRequestedOutputs())
        } while (data.globalSubgraph.isDirty(1) && counter1 != 8)
        
        guard preferencesChanged || observedSizeThatFitsChanged || !updatedOutputs.isEmpty || needsFocusUpdate else {
            return
        }
        if Thread.isMainThread {
            if preferencesChanged {
                delegate?.preferencesDidChange()
            }
            if observedSizeThatFitsChanged {
                sizeThatFitsObserver?.callback(oldCachedSizeThatFits, self.cachedSizeThatFits)
            }
            if !requestedOutputs.isEmpty {
                delegate?.outputsDidChange(outputs: updatedOutputs)
            }
            if needsFocusUpdate {
                needsFocusUpdate = false
                delegate?.focusDidChange()
            }
        } else {
            fatalError("TODO")
        }
        mainUpdates &-= 1
        #endif
    }
    
    private func updateObservedSizeThatFits() -> Bool {
        // TODO
        return false
    }
    
    private func updateRequestedOutputs() -> Outputs {
        // TODO
        return []
    }
    
    func clearPreferenceBridge() {
        setPreferenceBridge(to: nil, isInvalidating: true)
    }
    
    private func setPreferenceBridge(to bridge: PreferenceBridge?, isInvalidating: Bool) {
        // TODO
    }
    
    private func makePreferenceOutlets(outputs: _ViewOutputs) {
        // TODO
    }
    
    private func removePreferenceOutlets(isInvalidating: Bool) {
        // TODO
    }
    
    
    // MARK: - Override Methods
    
    override var graphDelegate: GraphDelegate? { delegate }
    override var parentHost: GraphHost? {
        // TODO: _preferenceBridge
        nil
    }
    
    override func instantiateOutputs() {
        #if canImport(Darwin)
        let outputs = self.data.globalSubgraph.apply {
            let graphInputs = graphInputs
            var inputs = _ViewInputs(
                base: graphInputs,
                preferences: PreferencesInputs(hostKeys: data.$hostPreferenceKeys),
                transform: $rootTransform,
                position: $position,
                containerPosition: $zeroPoint,
                size: $dimensions,
                safeAreaInsets: OptionalAttribute()
            )
            if requestedOutputs.contains(.layout) {
                // FIXME
                // inputs.base.options.formUnion(.init(rawValue: 0xe2))
            }
            requestedOutputs.addRequestedPreferences(to: &inputs)
            _preferenceBridge?.wrapInputs(&inputs)
            _ViewDebug.instantiateIfNeeded()
            delegate?.modifyViewInputs(&inputs)
            // TODO
            $rootGeometry.mutateBody(
                as: RootGeometry.self,
                invalidating: true
            ) { rootGeometry in
                inputs.withMutableCachedEnviroment {
                    rootGeometry.$layoutDirection = $0.attribute(keyPath: \.layoutDirection)
                }
            }
            // TOOD
            return makeRootView(rootView, inputs)
        }
        $rootGeometry.mutateBody(
            as: RootGeometry.self,
            invalidating: true
        ) { rootGeometry in
            rootGeometry.$childLayoutComputer = outputs.$layoutComputer
        }
        // TODO
        hostPreferenceValues.projectedValue = outputs.hostPreferences
        makePreferenceOutlets(outputs: outputs)
        #endif
    }
    
    override func uninstantiateOutputs() {
        #if canImport(Darwin)
        removePreferenceOutlets(isInvalidating: false)
        $rootGeometry.mutateBody(
            as: RootGeometry.self,
            invalidating: true
        ) { rootGeometry in
            rootGeometry.$layoutDirection = nil
            rootGeometry.$childLayoutComputer = nil
        }
//        $rootPlatformList = nil
//        $rootResponders = nil
//        $rootAccessibilityNodes = nil
//        $rootLayoutComputer = nil
//        $rootDisplayList = nil
        hostPreferenceValues = OptionalAttribute()
        #endif
    }
    
    override func timeDidChange() {
        nextUpdate.views = NextUpdate(time: .infinity)
    }
    
    override func isHiddenForReuseDidChange() {
        // TODO
    }
}

extension ViewGraph {
    struct NextUpdate {
        var time: Time
        var _interval: Double
        var reasons: Set<UInt32>
        
        @inline(__always)
        init(time: Time) {
            self.time = time
            _interval = .infinity
            reasons = []
        }
        
        // TODO: AnimatorState.nextUpdate
        mutating func interval(_ value: Double, reason: UInt32?) {
            if value == .zero {
                if _interval > 1 / 60 {
                    _interval = .infinity
                }
            } else {
                _interval = min(value, _interval)
            }
            if let reason {
                reasons.insert(reason)
            }
        }
    }
}

extension ViewGraph {
    struct Outputs: OptionSet {
        let rawValue: UInt8
        
        static var _0: Outputs { .init(rawValue: 1 << 0) }
        static var _1: Outputs { .init(rawValue: 1 << 1) }
        static var _2: Outputs { .init(rawValue: 1 << 2) }
        static var _3: Outputs { .init(rawValue: 1 << 3) }
        static var layout: Outputs { .init(rawValue: 1 << 4) }
        
        fileprivate func addRequestedPreferences(to inputs: inout _ViewInputs) {
            inputs.preferences.add(HostPreferencesKey.self)
            if contains(._0) {
                inputs.preferences.add(DisplayList.Key.self)
            }
            if contains(._2) {
//                inputs.preferences.add(ViewRespondersKey.self)
            }
            if contains(._1) {
//                inputs.preferences.add(PlatformItemList.Key.self)
            }
            if contains(._3) {
//                inputs.preferences.add(AccessibilityNodesKe.self)
            }
        }
    }
}

private struct RootTransform: Rule {
    var value: ViewTransform {
        guard let delegate = ViewGraph.current.delegate else {
            return ViewTransform()
        }
        return delegate.rootTransform()
    }
}

struct RootGeometry: Rule, AsyncAttribute {
    @OptionalAttribute var layoutDirection: LayoutDirection?
    @Attribute var proposedSize: ViewSize
    @OptionalAttribute var safeAreaInsets: _SafeAreaInsetsModifier?
    @OptionalAttribute var childLayoutComputer: LayoutComputer?
    
    // |←--------------------------proposedSize.value.width--------------------------→|  (0, 0)
    // ┌──────────────────────────────────────────────────────────────────────────────┐  ┌─────────> x
    // │     (x: insets.leading, y: insets.top)                                       |  │
    // │     ↓                                                                        |  |
    // |     |←--------------------------proposal.width--------------------------→|   |  |
    // │     ┌────────────┬───────────────────────────────────────────────────────┐   |  |
    // │     |████████████|                                                       |   │  ↓ y
    // │     |████████████|                                                       |   │  eg.
    // │     ├────────────┘                                                       │   |  proposedSize = (width: 80, height: 30)
    // |     |←----------→|                                                       |   |  insets = (
    // │     |fittingSize.width                                                   |   |    top: 4,
    // │     |                                                                    |   │    leading: 6,
    // |     | (x: insets.leading + (proposal.width  - fittingSize.width ) * 0.5, |   |    bottom: 2,
    // |     |  y: insets.top     + (proposal.height - fittingSize.height) * 0.5) |   |    trailing: 4
    // |     |                           ↓                                        |   |  )
    // │     |                           ┌────────────┐                           │   |  proposal = (width: 70, height: 24)
    // │     |                           |████████████|                           │   |  fitting = (width: 14, height: 4)
    // │     |                           |████████████|                           |   │
    // │     |                           └────────────┘                           |   │  Result:
    // │     |                                                                    |   │  center: false + left
    // │     |                                                                    |   │  x: insets.leading = 6
    // │     |                                                                    |   │  y: insets.top = 4
    // │     |                                                                    |   │
    // │     |                                                                    |   │  center: false + right
    // │     |                                                                    |   │  x: insets.leading = proposedSize.width-(i.l+f.w)
    // │     |                                                                    |   │  y: insets.top = 4
    // │     |                                                                    |   │
    // │     |                                                                    |   │  center: true + left
    // │     └────────────────────────────────────────────────────────────────────┘   |  x: i.l+(p.width-f.width)*0.5=34
    // |                                                                              |  y: i.t+(p.height-f.height)*0.5=14
    // └──────────────────────────────────────────────────────────────────────────────┘
    var value: ViewGeometry {
        let layoutComputer = childLayoutComputer ?? .defaultValue
        let insets = safeAreaInsets?.insets ?? EdgeInsets()
        let proposal = proposedSize.value.inset(by: insets)
        let fittingSize = layoutComputer.delegate.sizeThatFits(_ProposedSize(size: proposal))
        
        var x = insets.leading
        var y = insets.top
        if ViewGraph.current.centersRootView {
            x += (proposal.width - fittingSize.width) * 0.5
            y += (proposal.height - fittingSize.height) * 0.5
        }
        
        let layoutDirection = layoutDirection ?? .leftToRight
        switch layoutDirection {
        case .leftToRight:
            break
        case .rightToLeft:
            x = proposedSize.value.width - CGRect(origin: CGPoint(x: x, y: y), size: fittingSize).maxX
        }
        return ViewGeometry(
            origin: ViewOrigin(value: CGPoint(x: x, y: y)),
            dimensions: ViewDimensions(
                guideComputer: layoutComputer,
                size: ViewSize(value: fittingSize, _proposal: proposal)
            )
        )
    }
}
