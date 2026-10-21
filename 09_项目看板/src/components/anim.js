import {Easing, interpolate, spring} from "remotion";

export const clamp01 = (v) => Math.max(0, Math.min(1, v));

const easeOut = Easing.out(Easing.cubic);

export const enter = (frame, start, distance = 22, duration = 20) => {
  const p = interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: easeOut,
  });
  return {
    opacity: p,
    transform: `translateY(${(1 - p) * distance}px)`,
  };
};

export const slideX = (frame, start, distance = 28, duration = 22) => {
  const p = interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: easeOut,
  });
  return {
    opacity: p,
    transform: `translateX(${(1 - p) * distance}px)`,
  };
};

export const scaleIn = (frame, start, fps, config = {}) => {
  const p = spring({
    frame: frame - start,
    fps,
    config: {damping: 200, mass: 0.55, stiffness: 120, ...config},
  });
  return {
    opacity: clamp01(p),
    transform: `scale(${0.88 + 0.12 * p})`,
  };
};

export const countUp = (frame, start, target, duration = 42) => {
  const p = interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: easeOut,
  });
  return Math.round(target * p);
};

export const progress = (frame, start, duration = 60) =>
  interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: easeOut,
  });

export const pulse = (frame, speed = 9) => 0.5 + 0.5 * Math.sin(frame / speed);
