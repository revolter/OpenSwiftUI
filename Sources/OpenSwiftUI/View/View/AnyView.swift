//
//  AnyView.swift
//  OpenSwiftUI
//
//  Audited for RELEASE_2021
//  Status: WIP
//  ID: A96961F3546506F21D8995C6092F15B5

internal import OpenGraphShims
internal import COpenSwiftUI

@frozen
public struct AnyView: PrimitiveView {
    var storage: AnyViewStorageBase

    public init<V>(_ view: V) where V: View {
        self.init(view, id: nil)
    }

    @_alwaysEmitIntoClient
    public init<V>(erasing view: V) where V : View {
        self.init(view)
    }

    public init?(_fromValue value: Any) {
        struct Visitor: ViewTypeVisitor {
            var value: Any
            var view: AnyView?
            
            mutating func visit<V: View>(type: V.Type) {
                view = AnyView(value as! V)
            }
        }
        guard let conformace = TypeConformance<ViewDescriptor>(type(of: value)) else {
            return nil
        }
        // FIXME: pass a structure like the following to _OpenSwiftUI_callVisitViewType1 and remove _OpenSwiftUI_callVisitViewType
        // x0 = pointer
        // x1 = View.self
        // x2 = PWT V: View.self
        // pointer+0x0 -> pointer+0x18
        // pointer+0x8 -> Visitor.self
        // pointer+0x10 -> PWT Visitor: ViewTypeVisitor
        // pointer+0x18~0x37 -> visitor.value
        // pointer+0x38 -> visitor.view
        var visitor: any ViewTypeVisitor = Visitor(value: value)
        withUnsafeMutablePointer(to: &visitor) { value in
            _OpenSwiftUI_callVisitViewType1(value, conformace.metadata, conformace.conformance)
        }
        self = (visitor as! Visitor).view!
    }
    
    init<V: View>(_ view: V, id: UniqueID?) {
        if let anyView = view as? AnyView {
            storage = anyView.storage
        } else {
            storage = AnyViewStorage(view: view, id: id)
        }
    }
    
    func visitContent<Visitor: ViewVisitor>(_ visitor: inout Visitor) {
        storage.visitContent(&visitor)
    }
    
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        #if canImport(Darwin)
        let outputs = inputs.makeIndirectOutputs()
        let parent = OGSubgraph.current!
        let container = AnyViewContainer(view: view.value, inputs: inputs, outputs: outputs, parentSubgraph: parent)
        let containerAttribute = Attribute(container)
        outputs.forEach { key, value in
            value.indirectDependency = containerAttribute.identifier
        }
        if let layoutComputer = outputs.$layoutComputer {
            layoutComputer.identifier.indirectDependency = containerAttribute.identifier
        }
        return outputs
        #else
        fatalError("See #39")
        #endif
    }
    
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        // TODO
        .init()
    }
}

@usableFromInline
class AnyViewStorageBase {
    let id: UniqueID?
    
    init(id: UniqueID?) {
        self.id = id
    }
    
    fileprivate var type: Any.Type { fatalError() }
    fileprivate var canTransition: Bool { fatalError() }
    fileprivate func matches(_ other: AnyViewStorageBase) -> Bool { fatalError() }
    fileprivate func makeChild(
        uniqueId: UInt32,
        container: Attribute<AnyViewInfo>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        fatalError()
    }
    func child<Value>() -> Value { fatalError() }
    fileprivate func makeViewList(
        view: _GraphValue<AnyView>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        fatalError()
    }
    fileprivate func visitContent<Vistor: ViewVisitor>(_ visitor: inout Vistor) {
        fatalError()
    }
}

private final class AnyViewStorage<V: View>: AnyViewStorageBase {
    let view: V
    
    init(view: V, id: UniqueID?) {
        self.view = view
        super.init(id: id)
    }
    
    override var type: Any.Type { V.self }
    
    override var canTransition: Bool { id != nil }
    
    override func matches(_ other: AnyViewStorageBase) -> Bool {
        other is AnyViewStorage<V>
    }
    
    override func makeChild(
        uniqueId: UInt32,
        container: Attribute<AnyViewInfo>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        let child = AnyViewChild<V>(info: container, uniqueId: uniqueId)
        let graphValue = _GraphValue(Attribute(child))
        return _ViewDebug.makeView(
            view: graphValue,
            inputs: inputs
        ) { view, inputs in
            V._makeView(view: view, inputs: inputs)
        }
    }
    
    override func child<Value>() -> Value { view as! Value }
    
    // TODO
//    override func makeViewList(
//        view: _GraphValue<AnyView>,
//        inputs: _ViewListInputs
//    ) -> _ViewListOutputs {
//    }
    
    override func visitContent<Vistor>(_ visitor: inout Vistor) where Vistor : ViewVisitor {
        visitor.visit(view)
    }
}

private struct AnyViewInfo {
    var item: AnyViewStorageBase
    var subgraph: OGSubgraph
    var uniqueID: UInt32
}

private struct AnyViewContainer: StatefulRule, AsyncAttribute {
    @Attribute var view: AnyView
    let inputs: _ViewInputs
    let outputs: _ViewOutputs
    let parentSubgraph: OGSubgraph
    
    typealias Value = AnyViewInfo
    
    func updateValue() {
        let view = view
        let newInfo: AnyViewInfo
        if hasValue {
            let oldInfo = value
            if oldInfo.item.matches(view.storage) {
                newInfo = oldInfo
            } else {
                eraseItem(info: oldInfo)
                newInfo = makeItem(view.storage, uniqueId: oldInfo.uniqueID + 1)
            }
        } else {
            newInfo = makeItem(view.storage, uniqueId: 0)
        }
        value = newInfo
    }
    
    func makeItem(_ storage: AnyViewStorageBase, uniqueId: UInt32) -> AnyViewInfo {
        #if canImport(Darwin)
        let current = OGAttribute.current!
        let childGraph = OGSubgraph(graph: parentSubgraph.graph)
        parentSubgraph.addChild(childGraph)
        return childGraph.apply {
            let childInputs = inputs.detechedEnvironmentInputs()
            let childOutputs = storage.makeChild(
                uniqueId: uniqueId,
                container: current.unsafeCast(to: AnyViewInfo.self),
                inputs: childInputs
            )
            outputs.attachIndirectOutputs(to: childOutputs)
            return AnyViewInfo(item: storage, subgraph: childGraph, uniqueID: uniqueId)
        }
        #else
        fatalError("#See #39")
        #endif
    }
    
    func eraseItem(info: AnyViewInfo) {
        outputs.detachIndirectOutputs()
        let subgraph = info.subgraph
        subgraph.willInvalidate(isInserted: true)
        subgraph.invalidate()
    }
}

private struct AnyViewChild<V: View>: StatefulRule, AsyncAttribute {
    @Attribute var info: AnyViewInfo
    let uniqueId: UInt32
    
    typealias Value = V
    
    func updateValue() {
        guard uniqueId == info.uniqueID else {
            return
        }
        value = info.item.child()
    }
}

extension AnyViewChild: CustomStringConvertible {
    var description: String { "\(V.self)" }
}

// TODO
private struct AnyViewChildList<V: View> {
    @Attribute var view: AnyView
    var id: UniqueID?
}

@_silgen_name("_OpenSwiftUI_callVisitViewType1")
func visitViewType(_ visitor: UnsafeMutablePointer<any ViewTypeVisitor>, type: UnsafeRawPointer, pwt: UnsafeRawPointer)

// Called by _OpenSwiftUI_callVisitViewType2 as a temporary workaround implementation
@_silgen_name("_OpenSwiftUI_callVisitViewType")
func visit<V: View>(_ visitor: UnsafeMutablePointer<any ViewTypeVisitor>, type: V.Type) {
    visitor.pointee.visit(type: V.self)
}
