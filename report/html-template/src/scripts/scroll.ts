/**
 * GSAP ScrollTrigger animations for Think Different presentations.
 * Loaded via CDN in the template - gsap and ScrollTrigger are globals.
 */

declare const gsap: any;
declare const ScrollTrigger: any;

export function initScrollAnimations() {
  gsap.registerPlugin(ScrollTrigger);

  // ── Hero: fade in on load, fade out on scroll ──
  const hero = document.querySelector('[data-section="hero"]');
  if (hero) {
    const title = hero.querySelector('.hero-title');
    const accent = hero.querySelector('.accent-line');
    const indicator = hero.querySelector('.scroll-indicator');

    // Title: start invisible, fade in on load (no scale - text can be long)
    if (title) {
      gsap.fromTo(title,
        { opacity: 0, y: 30 },
        { opacity: 1, y: 0, duration: 1.2, ease: 'power2.out', delay: 0.2 }
      );
      // Fade out as user scrolls away
      gsap.to(title, {
        opacity: 0, y: -30,
        scrollTrigger: { trigger: hero, start: '60% top', end: 'bottom top', scrub: true }
      });
    }

    // Accent line: expand from center after title appears
    if (accent) {
      gsap.to(accent, {
        scaleX: 1, duration: 0.8, ease: 'power2.inOut', delay: 1.0
      });
    }

    // Scroll indicator: fade out as user scrolls
    if (indicator) {
      gsap.to(indicator, {
        opacity: 0,
        scrollTrigger: { trigger: hero, start: '10% top', end: '30% top', scrub: true }
      });
    }
  }

  // ── The Line: word-by-word reveal, pinned ──
  const lineSection = document.querySelector('[data-section="the-line"]');
  if (lineSection) {
    const lines = lineSection.querySelectorAll('.line-container');

    if (lines.length > 0) {
      // Pin the section - scale duration to number of lines
      const totalScroll = Math.max(lines.length * 80, 150);
      ScrollTrigger.create({
        trigger: lineSection,
        start: 'top top',
        end: `+=${totalScroll}%`,
        pin: true,
        pinSpacing: true,
      });

      lines.forEach((lineEl: Element, lineIndex: number) => {
        const words = lineEl.querySelectorAll('.word-reveal');
        const segmentSize = 100 / lines.length;
        const startPct = lineIndex * segmentSize;

        // Dim previous lines when a new one begins
        if (lineIndex > 0) {
          Array.from(lines).slice(0, lineIndex).forEach((prev: Element) => {
            gsap.to(prev, {
              opacity: 0.25,
              scrollTrigger: {
                trigger: lineSection,
                start: `top+=${startPct}% top`,
                end: `top+=${startPct + 5}% top`,
                scrub: true,
              }
            });
          });
        }

        // Reveal words with stagger
        gsap.to(words, {
          opacity: 1, y: 0, stagger: 0.05, ease: 'power2.out',
          scrollTrigger: {
            trigger: lineSection,
            start: `top+=${startPct + 5}% top`,
            end: `top+=${startPct + segmentSize - 10}% top`,
            scrub: true,
          }
        });
      });
    }
  }

  // ── Insight sections: simple fade-up reveals ──
  const insightPanels = document.querySelectorAll('[data-section="insight"] .section-panel');
  insightPanels.forEach((panel: Element) => {
    // Subsection title fades in
    const subTitle = panel.querySelector('.subsection-title');
    if (subTitle) {
      gsap.to(subTitle, {
        opacity: 1, y: 0, duration: 0.7, ease: 'power2.out',
        scrollTrigger: { trigger: panel, start: 'top 75%', toggleActions: 'play none none reverse' }
      });
    }

    // Paragraphs stagger in
    const paras = panel.querySelectorAll('.para-reveal');
    if (paras.length > 0) {
      gsap.to(paras, {
        opacity: 1, y: 0, duration: 0.6, stagger: 0.12, ease: 'power2.out',
        scrollTrigger: { trigger: panel, start: 'top 65%', toggleActions: 'play none none reverse' }
      });
    }
  });

  // ── Brief: card slides ──
  const briefCards = document.querySelectorAll('[data-section="brief"] .brief-card');
  briefCards.forEach((card: Element) => {
    gsap.to(card, {
      opacity: 1, x: 0, duration: 0.7, ease: 'power2.out',
      scrollTrigger: { trigger: card, start: 'top 80%', toggleActions: 'play none none reverse' }
    });
  });

  // Proposition special treatment
  const proposition = document.querySelector('[data-section="brief"] .proposition-block');
  if (proposition) {
    gsap.from(proposition, {
      opacity: 0, y: 20, duration: 0.8, ease: 'power2.out',
      scrollTrigger: { trigger: proposition, start: 'top 75%', toggleActions: 'play none none reverse' }
    });
  }

  // ── Manifesto: paragraph reveals ──
  const manifestoParas = document.querySelectorAll('[data-section="manifesto"] .manifesto-para');
  manifestoParas.forEach((para: Element) => {
    gsap.from(para, {
      opacity: 0, y: 30, duration: 0.8, ease: 'power2.out',
      scrollTrigger: {
        trigger: para,
        start: 'top 75%',
        toggleActions: 'play none none reverse',
      }
    });
  });

  // ── Footer: subtle rise ──
  const footer = document.querySelector('[data-section="footer"]');
  if (footer) {
    gsap.from(footer, {
      y: 20, opacity: 0, duration: 0.8, ease: 'power2.out',
      scrollTrigger: { trigger: footer, start: 'top 90%', toggleActions: 'play none none reverse' }
    });
  }
}

// Auto-init when DOM is ready
if (typeof document !== 'undefined') {
  document.addEventListener('DOMContentLoaded', initScrollAnimations);
}
