// Inert Arena 9 authoring contract. No registry, Scene, draft or save consumer.
import Foundation
import CoreGraphics

/// Configuration deliberately contains no authored route or tuning defaults.
/// Content must supply its own finite stage and resolve gameplay policy first.
struct Arena9StageDefinition {
    struct Encounter: Equatable {
        let id: String
        let triggerX: CGFloat
    }

    enum DefinitionError: Error, Equatable {
        case invalidWorld, invalidStart, invalidEncounter, duplicateEncounter
    }

    let world: CGRect
    let start: CGPoint
    let encounters: [Encounter]

    init(world: CGRect, start: CGPoint, encounters: [Encounter]) throws {
        guard Self.finite(world), world.size.width > 0, world.size.height > 0,
              world.minX < world.maxX, world.minY < world.maxY else {
            throw DefinitionError.invalidWorld
        }
        guard Self.finite(start), Self.containsClosed(start, in: world) else {
            throw DefinitionError.invalidStart
        }
        var ids = Set<String>()
        var previous = world.minX
        for encounter in encounters {
            guard !encounter.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  encounter.triggerX.isFinite,
                  encounter.triggerX >= previous, encounter.triggerX <= world.maxX else {
                throw DefinitionError.invalidEncounter
            }
            guard ids.insert(encounter.id).inserted else { throw DefinitionError.duplicateEncounter }
            previous = encounter.triggerX
        }
        self.world = world
        self.start = start
        self.encounters = encounters
    }

    static func finite(_ point: CGPoint) -> Bool { point.x.isFinite && point.y.isFinite }
    static func finite(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
            && rect.minX.isFinite && rect.maxX.isFinite && rect.minY.isFinite && rect.maxY.isFinite
    }
    static func containsClosed(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
}
