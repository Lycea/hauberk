import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import '../attack.dart';
import '../element.dart';
import '../game.dart';
import 'action.dart';
import 'element.dart';

/// Creates a swath of damage that radiates out from a point.
class RayAction extends Action with DestroyItemMixin {
  /// The centerpoint that the cone is radiating from.
  final Vec _from;

  /// The tile being targeted. The arc of the cone will center on a line from
  /// [_from] to this.
  final Vec _to;

  final Hit _hit;

  /// The tiles that have already been touched by the effect. Used to make sure
  /// we don't hit the same tile multiple times.
  final _hitTiles = new Set<Vec>();

  /// The cone incrementally spreads outward. This is how far we currently are.
  var _radius = 1;

  // We "fill" the cone by tracing a number of rays, each of which can get
  // obstructed. This is the angle of each ray still being traced.
  final _rays = <double>[];

  /// A 45° cone of [attack] centered on the line from [from] to [to].
  factory RayAction.cone(Vec from, Vec to, Hit hit) =>
      new RayAction._(from, to, hit, 1 / 8);

  /// A complete ring of [attack] radiating outwards from [center].
  factory RayAction.ring(Vec center, Hit hit) =>
      new RayAction._(center, center, hit, 1.0);

  /// Creates a [RayAction] radiating from [_from] centered on [_to] (which
  /// may be the same as [_from] if the ray is a full circle. It applies
  /// [_hit] to each touched tile. The rays cover a chord whose width is
  /// [fraction] which varies from 0 (an infinitely narrow line) to 1.0 (a full
  /// circle.
  RayAction._(this._from, this._to, this._hit, double fraction) {
    // We "fill" the cone by tracing a number of rays. We need enough of them
    // to ensure there are no gaps when the cone is at its maximum extent.
    var circumference = math.PI * 2 * _hit.range;
    var numRays = (circumference * fraction).ceil();

    // Figure out the center angle of the cone.
    var offset = _to - _from;
    // TODO: Make atan2 getter on Vec?
    var centerTheta = 0.0;
    if (_from != _to) {
      centerTheta = math.atan2(offset.x, offset.y);
    }

    // Create the rays.
    for (var i = 0; i < numRays; i++) {
      var range = (i / (numRays - 1)) - 0.5;
      _rays.add(centerTheta + range * (math.PI * 2 * fraction));
    }
  }

  ActionResult onPerform() {
    // See which new tiles each ray hit now.
    _rays.removeWhere((ray) {
      var pos = new Vec(
          _from.x + (math.sin(ray) * _radius).round(),
          _from.y + (math.cos(ray) * _radius).round());

      // Kill the ray if it's obstructed.
      if (!game.stage[pos].isTransparent) return true;

      // Don't hit the same tile twice.
      if (_hitTiles.contains(pos)) return false;

      addEvent(EventType.cone, element: _hit.element, pos: pos);
      _hitTiles.add(pos);

      // See if there is an actor there.
      var target = game.stage.actorAt(pos);
      if (target != null && target != actor) {
        // TODO: Modify damage based on range?
        _hit.perform(this, actor, target, canMiss: false);
      }

      // Hit stuff on the floor too.
      _hitFloor(pos);

      return false;
    });

    _radius++;
    if (_radius > _hit.range || _rays.isEmpty) return ActionResult.success;

    // Still going.
    return ActionResult.notDone;
  }

  /// Applies element-specific effects to items on the floor.
  void _hitFloor(Vec pos) {
    switch (_hit.element) {
      case Element.none:
        // No effect.
        break;

      case Element.air:
        // TODO: Teleport items.
        break;

      case Element.earth:
        break;

      case Element.fire:
        _destroyFloorItems(pos, 3, "flammable", "burns up");
        break;

      case Element.water:
        // TODO: Move items.
        break;

      case Element.acid:
        // TODO: Destroy items.
        break;

      case Element.cold:
        _destroyFloorItems(pos, 6, "freezable", "shatters");
        break;

      case Element.lightning:
        // TODO: Break glass. Recharge some items?
        break;

      case Element.poison:
        break;

      case Element.dark:
        // TODO: Blind.
        break;

      case Element.light:
        break;

      case Element.spirit:
        break;
    }

    return null;
  }

  void _destroyFloorItems(Vec pos, int chance, String flag, String message) {
    var destroyed = destroyItems(
        game.stage.itemsAt(pos), chance, flag, message);
    for (var item in destroyed) {
      game.stage.removeItem(item, pos);
    }
  }
}

/// Creates an expanding ring of damage centered on the [Actor].
///
/// This class mainly exists as an [Action] that [Item]s can use.
class RingSelfAction extends Action {
  final Attack _attack;

  RingSelfAction(this._attack);

  ActionResult onPerform() {
    return alternate(new RayAction.ring(actor.pos, _attack.createHit()));
  }
}

class RingAtAction extends Action {
  final Attack _attack;
  final Vec _pos;

  RingAtAction(this._attack, this._pos);

  ActionResult onPerform() {
    return alternate(new RayAction.ring(_pos, _attack.createHit()));
  }
}
