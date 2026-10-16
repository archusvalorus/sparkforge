#!/usr/bin/env python3
"""Compile actual scene steering/spawning/config selection; fake only SpriteKit containers."""
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
scene = (root/'Sparkforge/Scenes/GameScene.swift').read_text()
def block(source, marker):
    start = source.index(marker)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]
parts = [block(scene, marker).replace('private ', '') for marker in [
    '    private static func resolveArenaConfig()',
    '    private var isTwinChannelsPreview:',
    '    private func routeSteerTarget(',
    '    private func twinChannelsSpawnPoint()',
    '    private func spawnTwinChannelsBody()']]
dev = block((root/'Sparkforge/Utils/GeometryDebug.swift').read_text(), 'enum DevSeams {')
head = """import Foundation
import CoreGraphics
final class GameScene {
 var arenaConfig = GameScene.resolveArenaConfig()
 var arenaGeometry: ArenaGeometry { arenaConfig.geometry }
 var geometryDebug = GeometryDebug()
 var routeOccupancy: [Int: Int] = [:]
 var channelSpawnWestNext = true
 var player = EnemyNode(health: 1, moveSpeed: 250, xpValue: 0)
 var enemies: [EnemyNode] = []
 var worldNode = WorldNode()
"""
(out/'Seams.swift').write_text(head + '\n'.join(parts) + '\n}\n' + dev + '\n')

enemy = (root/'Sparkforge/Nodes/EnemyNode.swift').read_text()
chase = block(enemy, '    func chase(target:')
(out/'Chase.swift').write_text('import Foundation\nimport CoreGraphics\nextension EnemyNode {\n' + chase + '\n}\n')
device = (root/'Sparkforge/Utils/DeviceScale.swift').read_text()
expressions = [block(device, marker) for marker in ['    static var gameplay:', '    static var arenaRadius:']]
(out/'DeviceScale.swift').write_text('import Foundation\nimport CoreGraphics\nenum DeviceScale {\n static var isIPad = false\n static var screenShort: CGFloat = 390\n' + '\n'.join(expressions) + '\n}\n')
