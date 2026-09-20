.pragma library

// Outline geometry for the island surface.
//
// The island is not a rounded rectangle. A rounded rectangle joins a straight
// edge to a circular arc, and curvature jumps from zero to 1/r at that seam —
// the eye reads the discontinuity as a slightly "pinched" corner. Apple's
// shapes ramp curvature in continuously instead, which is why the notch reads
// as one flowing outline rather than four arcs bolted onto a box.
//
// We approximate that with a superellipse quarter per corner:
//
//     |x/r|^n + |y/r|^n = 1
//
// n = 2 is a circle; larger n pushes the curve toward the corner and flattens
// its approach to the edges. n = 5 sits close to Apple's shape. Corners are
// sampled into a polyline rather than fitted with beziers: the island resizes
// every frame during a morph, and re-sampling a few dozen points in JS is
// cheaper and far less fiddly than re-solving control points for a radius that
// is itself animating.
//
// The shoulders that blend the island into the screen edge use the very same
// curve. The only difference is where the centre of curvature sits: inside the
// body for a corner (the outline bends away from the centre), outside it for a
// shoulder (the outline bends toward the body). Nothing else changes, which is
// why there is one curve routine here rather than two.

// The unit superellipse, sampled once per exponent and segment count. Sizes
// change constantly during a morph but the *shape* of the curve does not, so
// the expensive pow() work is cached and each corner just scales the result.
var _unitCache = {};

function unitCorner(exponent, segments) {
    var key = exponent + ":" + segments;
    var cached = _unitCache[key];
    if (cached)
        return cached;

    var power = 2 / exponent;
    var points = [];
    for (var i = 0; i <= segments; i++) {
        var t = (i / segments) * (Math.PI / 2);
        points.push({
            x: Math.pow(Math.cos(t), power),
            y: Math.pow(Math.sin(t), power)
        });
    }
    _unitCache[key] = points;
    return points;
}

// One quarter-curve, appended to `out`.
//
// `cx`/`cy` is the centre of curvature and `sx`/`sy` the direction from it
// toward the curve. Walking starts at the (r, 0) end of the unit curve and
// ends at (0, r); `reverse` swaps that, which is how consecutive quarters are
// chained into a single path that never backtracks.
function quarter(out, cx, cy, r, sx, sy, exponent, segments, reverse) {
    if (r <= 0) {
        out.push({ x: cx, y: cy });
        return;
    }
    var unit = unitCorner(exponent, segments);
    for (var i = 0; i <= segments; i++) {
        var p = unit[reverse ? segments - i : i];
        out.push({
            x: cx + sx * r * p.x,
            y: cy + sy * r * p.y
        });
    }
}

// Build the island outline.
//
// `opts`:
//   width, height   body size, excluding the shoulders
//   radiusTop       corner radius along the top edge; ignored when fillet > 0,
//                   since the shoulder already owns that transition
//   radiusBottom    corner radius along the bottom edge
//   fillet          concave shoulder width; 0 for a detached pill
//   exponent        superellipse exponent (2 = circular, ~5 = Apple-like)
//   segments        samples per quarter
//   originX         left edge of the body within the item
//
// Returns points in item coordinates, walking the top edge left-to-right, down
// the left side, along the bottom, and back up the right — so the fill closes
// along the screen edge, where there is nothing to draw anyway.
function islandOutline(opts) {
    var w = Math.max(1, opts.width);
    var h = Math.max(1, opts.height);
    var fillet = Math.max(0, opts.fillet || 0);
    var exponent = opts.exponent || 5;
    var segments = Math.max(2, opts.segments || 12);
    var x0 = opts.originX === undefined ? fillet : opts.originX;
    var x1 = x0 + w;

    // A radius can never exceed half the box, and two radii on the same side
    // must share that side between them, or the corners overlap and the
    // outline crosses itself mid-animation.
    var maxR = Math.min(w / 2, h / 2);
    var rTop = fillet > 0 ? 0 : Math.max(0, Math.min(opts.radiusTop || 0, maxR));
    var rBottom = Math.max(0, Math.min(opts.radiusBottom || 0, maxR));
    if (rTop + rBottom > h) {
        var scale = h / (rTop + rBottom);
        rTop *= scale;
        rBottom *= scale;
    }
    // A shoulder deeper than the body is taller, or wider than half the body,
    // would fold back through the outline.
    fillet = Math.min(fillet, h, w / 2);

    var pts = [];

    // Top-left: comes in along the screen edge and turns down into the left
    // side. With a shoulder the centre of curvature sits outside the body, so
    // the curve hugs the join; without one it is an ordinary corner.
    if (fillet > 0)
        quarter(pts, x0 - fillet, fillet, fillet, 1, -1, exponent, segments, true);
    else
        quarter(pts, x0 + rTop, rTop, rTop, -1, -1, exponent, segments, true);

    // Left side down into the bottom edge.
    quarter(pts, x0 + rBottom, h - rBottom, rBottom, -1, 1, exponent, segments, false);
    // Bottom edge up into the right side.
    quarter(pts, x1 - rBottom, h - rBottom, rBottom, 1, 1, exponent, segments, true);

    // Top-right, mirroring the left.
    if (fillet > 0)
        quarter(pts, x1 + fillet, fillet, fillet, -1, -1, exponent, segments, false);
    else
        quarter(pts, x1 - rTop, rTop, rTop, 1, -1, exponent, segments, false);

    return pts;
}

// Convert to the QPointF list QtQuick.Shapes' PathPolyline wants. Kept
// separate so callers that only want the maths (hit testing, input masks) do
// not pay for the object churn.
function toPath(points, qtPoint) {
    var out = [];
    for (var i = 0; i < points.length; i++)
        out.push(qtPoint(points[i].x, points[i].y));
    return out;
}
