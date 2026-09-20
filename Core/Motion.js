.pragma library

// Motion curves for the island.
//
// Every size change on the island is a spring, not an ease. The difference is
// legible: an ease-out decelerates into its target and stops dead, while a
// spring carries a little past it and settles back. That overshoot is most of
// what makes the shape feel like it has mass rather than like a div being
// resized.
//
// QML can express this two ways. `SpringAnimation` integrates real physics but
// its `spring`/`damping` numbers do not map onto anything a designer reasons
// about, and it cannot be used inside a `Behavior` that also needs a duration.
// `NumberAnimation` with `Easing.Bezier` takes a spline, so here we solve the
// damped-spring step response analytically and fit a bezier spline to it. That
// keeps the designer-facing knobs — response and damping — while still
// producing a curve QML can run natively on the render thread.
//
// The two knobs, matching the vocabulary Apple uses:
//   response  seconds for the shape to reach its target the first time.
//             Smaller is snappier.
//   damping   0..1. 1.0 settles with no overshoot at all; 0.8 gives a gentle
//             pop; below ~0.5 it visibly bounces.

// Step response of a unit second-order system, and its derivative, in
// normalised time. Returns { y, dy } where dy is d(y)/d(t) in seconds.
function _response(t, omega, zeta) {
    if (zeta < 1) {
        // Underdamped: overshoots, then rings down.
        var wd = omega * Math.sqrt(1 - zeta * zeta);
        var decay = Math.exp(-zeta * omega * t);
        var y = 1 - decay * (Math.cos(wd * t) + (zeta * omega / wd) * Math.sin(wd * t));
        var dy = decay * (omega * omega / wd) * Math.sin(wd * t);
        return { y: y, dy: dy };
    }
    // Critically damped: the fastest approach that never crosses the target.
    var e = Math.exp(-omega * t);
    return {
        y: 1 - e * (1 + omega * t),
        dy: omega * omega * t * e
    };
}

// How long until the spring is close enough to its target that no one can see
// the remaining error. Derived from the decay envelope rather than fixed, so a
// bouncier spring is correctly given more time to finish ringing.
function _settleTime(omega, zeta) {
    var tolerance = 0.004;
    if (zeta < 1) {
        var envelope = Math.sqrt(1 - zeta * zeta);
        return -Math.log(tolerance * envelope) / (zeta * omega);
    }
    return 6 / omega;
}

// Fit a bezier spline to the spring's step response.
//
// Each sample pair becomes one cubic segment. Control points come from the
// analytic derivative at the sample (a Hermite-to-bezier conversion), so the
// spline matches the spring's slope as well as its position — which is what
// keeps the overshoot's shape intact rather than rounding it off.
//
// Returns the flat [c1x,c1y, c2x,c2y, px,py, ...] list `easing.bezierCurve`
// expects, always terminating exactly at (1,1) as Qt requires.
function springCurve(response, damping, segments) {
    var res = Math.max(0.05, Number(response) || 0.4);
    var zeta = Math.max(0.05, Math.min(1.5, Number(damping) || 0.8));
    // Qt's BezierEase preallocates exactly 10 curve slots and never bounds-checks
    // them (_curves(10)/_intervals(10) in qeasingcurve.cpp), so a spline with more
    // than 10 cubic segments writes past the end of both lists and corrupts the
    // heap. 10 is a hard ceiling of the format, not a tuning knob.
    var count = Math.min(10, Math.max(2, Math.round(segments || 10)));

    var omega = 2 * Math.PI / res;
    var duration = _settleTime(omega, zeta);

    var samples = [];
    for (var i = 0; i <= count; i++) {
        var u = i / count;              // normalised time, 0..1
        var t = u * duration;           // real time, seconds
        var r = _response(t, omega, zeta);
        samples.push({
            u: u,
            y: r.y,
            // Chain rule: the spline is parameterised on normalised time, so
            // the slope has to be scaled by the duration it was sampled over.
            m: r.dy * duration
        });
    }

    // Pin the tail to the target. The analytic curve is still a hair short at
    // the settle time, and Qt rejects a spline that does not end at 1.
    samples[count].y = 1;
    samples[count].m = 0;

    var curve = [];
    for (var s = 0; s < count; s++) {
        var a = samples[s];
        var b = samples[s + 1];
        var h = b.u - a.u;
        curve.push(a.u + h / 3, a.y + a.m * h / 3);
        curve.push(b.u - h / 3, b.y - b.m * h / 3);
        curve.push(b.u, b.y);
    }
    // Guard against float drift in the final endpoint.
    curve[curve.length - 2] = 1;
    curve[curve.length - 1] = 1;

    return {
        duration: Math.round(duration * 1000),
        bezierCurve: curve
    };
}

// Cache: the curve only depends on its two knobs, and re-solving it on every
// property change would put this maths in the middle of an animation frame.
var _cache = {};

function curveFor(response, damping) {
    var key = response + ":" + damping;
    if (!_cache[key])
        _cache[key] = springCurve(response, damping);
    return _cache[key];
}

function clearCache() {
    _cache = {};
}
