import React, {createContext, useContext, useEffect, useRef, useState} from "react";

const LiveClockContext = createContext({
  frame: 0,
  duration: 0,
  playing: false,
  replay: () => {},
});

/**
 * A tiny requestAnimationFrame clock for live dashboard motion.
 *
 * This intentionally does not use @remotion/player: the chapters are real DOM
 * sections, animated with Remotion's interpolate/spring/Easing math. The clock
 * supplies the frame number that Remotion compositions would normally receive.
 */
export const LiveClockProvider = ({duration, children, autoPlay = true}) => {
  const reduceMotion =
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const [frame, setFrame] = useState(reduceMotion ? duration : 0);
  const [playing, setPlaying] = useState(reduceMotion ? false : autoPlay);
  const startTime = useRef(null);
  const raf = useRef(0);

  const replay = () => {
    startTime.current = null;
    setFrame(0);
    setPlaying(true);
  };

  useEffect(() => {
    if (!playing) return undefined;
    let mounted = true;

    const tick = (now) => {
      if (!mounted) return;
      if (startTime.current === null) startTime.current = now;
      const elapsed = (now - startTime.current) / 1000;
      const next = Math.min(duration, elapsed * 30);
      setFrame(next);
      if (next < duration) {
        raf.current = requestAnimationFrame(tick);
      } else {
        setPlaying(false);
      }
    };

    raf.current = requestAnimationFrame(tick);
    return () => {
      mounted = false;
      cancelAnimationFrame(raf.current);
    };
  }, [playing, duration]);

  return (
    <LiveClockContext.Provider value={{frame, duration, playing, replay}}>
      {children}
    </LiveClockContext.Provider>
  );
};

export const useLiveFrame = () => useContext(LiveClockContext).frame;
export const useLiveClock = () => useContext(LiveClockContext);
