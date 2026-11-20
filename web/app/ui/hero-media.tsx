import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import { motion } from './tokens.ts'

const heroFrame = css({
  position: 'absolute',
  inset: 0,
  width: '100%',
  height: '100%',
  objectFit: 'cover',
  animation: `bbInkReveal ${motion.inkReveal} both`,
  '@media (prefers-reduced-motion: reduce)': { animation: 'none' },
})

/** Bundled canopy ships AVIF + WebP (+ JPG fallback). Custom config URLs render as-is. */
export function HeroMedia(handle: Handle<{ src: string; alt?: string }>) {
  return () => {
    let { src, alt = '' } = handle.props
    let bundled = /careers-canopy\.(avif|webp|jpe?g)(\?|$)/i.test(src) || src === '/careers-canopy'

    if (bundled) {
      return (
        <picture>
          <source srcSet="/careers-canopy.avif" type="image/avif" />
          <source srcSet="/careers-canopy.webp" type="image/webp" />
          <img src="/careers-canopy.jpg" alt={alt} mix={heroFrame} />
        </picture>
      )
    }

    return <img src={src} alt={alt} mix={heroFrame} />
  }
}
