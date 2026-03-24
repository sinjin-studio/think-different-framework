/**
 * GSAP ScrollTrigger animations for Think Different presentations.
 * Loaded via CDN in the template - gsap and ScrollTrigger are globals.
 *
 * Animation philosophy: cinematic typography reveals, pinned sequences,
 * 3D transforms, clipPath wipes. Inspired by gsap.com craft level.
 */

declare const gsap: any;
declare const ScrollTrigger: any;

// ── Utilities ──

/**
 * Split an element's text into individual character spans.
 * Falls back to word-level splitting if text exceeds maxChars.
 */
function splitText(el: Element, maxChars = 150): HTMLSpanElement[] {
  const text = el.textContent || '';
  el.textContent = '';
  const spans: HTMLSpanElement[] = [];

  if (text.length > maxChars) {
    // Word-level fallback for long strings
    for (const word of text.split(/\s+/)) {
      if (!word) continue;
      const span = document.createElement('span');
      span.className = 'char-word';
      span.textContent = word;
      span.style.display = 'inline-block';
      span.style.marginRight = '0.25em';
      el.appendChild(span);
      spans.push(span);
    }
  } else {
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const span = document.createElement('span');
      span.className = 'char';
      span.textContent = char === ' ' ? '\u00A0' : char;
      span.style.display = 'inline-block';
      if (char === ' ') span.style.width = '0.3em';
      el.appendChild(span);
      spans.push(span);
    }
  }
  return spans;
}

/**
 * Set the active nav dot, removing active from others.
 */
function setActiveNav(activeLi: HTMLElement) {
  const nav = document.querySelector('.section-nav');
  if (!nav) return;
  nav.querySelectorAll('li').forEach((li: Element) => li.classList.remove('active'));
  activeLi.classList.add('active');
}

// ── Main ──

export function initScrollAnimations() {
  gsap.registerPlugin(ScrollTrigger);

  // Respect reduced motion preference
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReduced) {
    gsap.set('.word-reveal, .para-reveal, .subsection-title, .brief-card, .manifesto-para, .brand-lockup, .section-divider', {
      opacity: 1, x: 0, y: 0, scale: 1, rotationX: 0, rotationY: 0, skewY: 0,
      clipPath: 'none', filter: 'none', letterSpacing: '0em',
    });
    const nav = document.querySelector('.section-nav');
    if (nav) nav.classList.add('visible');
    return;
  }

  // ── Hero: cinematic character reveal ──
  const hero = document.querySelector('[data-section="hero"]');
  if (hero) {
    const title = hero.querySelector('.hero-title');
    const accent = hero.querySelector('.accent-line');
    const indicator = hero.querySelector('.scroll-indicator');
    const brandLockup = hero.querySelector('.brand-lockup');

    // Brand lockup: char-split with letterSpacing compression
    if (brandLockup) {
      const brandText = brandLockup.querySelector('.brand-name-text');
      if (brandText) {
        const brandChars = splitText(brandText);
        gsap.fromTo(brandChars,
          { opacity: 0, letterSpacing: '0.4em' },
          {
            opacity: 1, letterSpacing: '0.15em',
            stagger: 0.03, duration: 0.8, ease: 'power3.out', delay: 0.1
          }
        );
      }
      const brandAccent = brandLockup.querySelector('.brand-accent');
      if (brandAccent) {
        gsap.to(brandAccent, { scaleX: 1, duration: 0.6, ease: 'power2.inOut', delay: 0.6 });
      }
    }

    // Title: 3D character flip from above
    if (title) {
      const chars = splitText(title);
      gsap.set(title, { perspective: 1200 });
      gsap.fromTo(chars,
        { opacity: 0, rotationX: -90, transformOrigin: 'top center' },
        {
          opacity: 1, rotationX: 0,
          stagger: 0.02, duration: 0.9, ease: 'power4.out',
          delay: brandLockup ? 0.8 : 0.3
        }
      );

      // Fade + parallax out on scroll
      gsap.to(title, {
        opacity: 0, y: -60,
        scrollTrigger: { trigger: hero, start: '50% top', end: 'bottom top', scrub: true }
      });
    }

    // Accent line: expand with green glow
    if (accent) {
      gsap.to(accent, {
        scaleX: 1, duration: 0.8, ease: 'power2.inOut',
        delay: brandLockup ? 1.2 : 1.0,
        onComplete: () => {
          gsap.to(accent, {
            boxShadow: '0 0 20px rgba(22, 155, 98, 0.6)',
            duration: 0.6, ease: 'power2.out',
          });
          gsap.to(accent, {
            boxShadow: '0 0 8px rgba(22, 155, 98, 0.2)',
            duration: 1.2, ease: 'power2.in', delay: 0.6,
          });
        }
      });
    }

    // Scroll indicator chevron: fade out on scroll
    if (indicator) {
      gsap.to(indicator, {
        opacity: 0,
        scrollTrigger: { trigger: hero, start: '10% top', end: '30% top', scrub: true }
      });
    }

    // Brand lockup fades with hero
    if (brandLockup) {
      gsap.to(brandLockup, {
        opacity: 0, y: -40,
        scrollTrigger: { trigger: hero, start: '40% top', end: 'bottom top', scrub: true }
      });
    }
  }

  // ── Section dividers: gradient line draw ──
  document.querySelectorAll('.section-divider').forEach((divider: Element) => {
    ScrollTrigger.create({
      trigger: divider,
      start: 'top 80%',
      onEnter: () => divider.classList.add('active'),
      onLeaveBack: () => divider.classList.remove('active'),
    });
  });

  // ── The Line: pinned timeline with word-by-word reveal ──
  const lineSection = document.querySelector('[data-section="the-line"]');
  if (lineSection) {
    const lines = lineSection.querySelectorAll('.line-container');

    if (lines.length > 0) {
      // More scroll distance per line so each one stays readable
      const totalScroll = Math.max(lines.length * 120, 200);

      // Single timeline pinned to the section - canonical GSAP pattern
      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: lineSection,
          start: 'top top',
          end: `+=${totalScroll}vh`,
          pin: true,
          pinSpacing: true,
          scrub: 0.5,
        }
      });

      // Segment timing: reveal (20%) + hold (50%) + dim/buffer (30%)
      const lineCount = lines.length;
      const segDuration = 1 / lineCount;
      const revealPortion = 0.2;
      const holdPortion = 0.5;

      lines.forEach((lineEl: Element, lineIndex: number) => {
        const words = lineEl.querySelectorAll('.word-reveal');
        const segStart = lineIndex * segDuration;

        // Dim + blur previous lines when a new one begins
        if (lineIndex > 0) {
          tl.to(Array.from(lines).slice(0, lineIndex), {
            opacity: 0.2,
            filter: 'blur(3px)',
            duration: segDuration * 0.1,
          }, segStart);
        }

        // Reveal words: clipPath horizontal wipe + letterSpacing compression
        tl.fromTo(words,
          {
            opacity: 0,
            y: 15,
            clipPath: 'inset(0 100% 0 0)',
            letterSpacing: '0.2em',
          },
          {
            opacity: 1,
            y: 0,
            clipPath: 'inset(0 0% 0 0)',
            letterSpacing: '0em',
            stagger: segDuration * 0.04,
            duration: segDuration * revealPortion,
            ease: 'power2.out',
          },
          segStart + segDuration * 0.03
        );

        // Add glow shortly after reveal starts
        tl.to(lineEl, {
          textShadow: '0 0 40px rgba(255, 130, 0, 0.3)',
          duration: segDuration * 0.1,
        }, segStart + segDuration * 0.1);

        // Hold: explicit spacer so the line stays fully visible
        // This runs from end-of-reveal to end-of-hold
        const holdStart = segStart + segDuration * (revealPortion + 0.05);
        tl.to({}, {
          duration: segDuration * holdPortion,
        }, holdStart);

        // Remove glow near end of segment (except last line which keeps it)
        if (lineIndex < lineCount - 1) {
          tl.to(lineEl, {
            textShadow: '0 0 0px rgba(255, 130, 0, 0)',
            duration: segDuration * 0.08,
          }, segStart + segDuration * (revealPortion + holdPortion + 0.05));
        }
      });

      // Hold the final line pinned for a comfortable read
      tl.to({}, { duration: 0.15 });
    }
  }

  // ── Insight sections: cinematic panel reveals ──
  const insightPanels = document.querySelectorAll('[data-section="insight"] .section-panel');
  insightPanels.forEach((panel: Element, panelIndex: number) => {
    const isEven = panelIndex % 2 === 0;

    // Subsection title: char-split with subtle 3D rotation
    const subTitle = panel.querySelector('.subsection-title');
    if (subTitle) {
      const titleChars = splitText(subTitle);
      gsap.set(subTitle, { perspective: 800 });
      gsap.fromTo(titleChars,
        { opacity: 0, rotationY: isEven ? 15 : -15, y: 10 },
        {
          opacity: 1, rotationY: 0, y: 0,
          stagger: 0.02, duration: 0.6, ease: 'power3.out',
          scrollTrigger: { trigger: panel, start: 'top 75%', toggleActions: 'play none none reverse' }
        }
      );
    }

    // Paragraphs: clipPath curtain wipe from alternating sides
    const paras = panel.querySelectorAll('.para-reveal');
    if (paras.length > 0) {
      const fromSide = isEven
        ? 'polygon(0 0, 0 0, 0 100%, 0 100%)'
        : 'polygon(100% 0, 100% 0, 100% 100%, 100% 100%)';
      const toSide = 'polygon(0 0, 100% 0, 100% 100%, 0 100%)';

      gsap.fromTo(paras,
        { opacity: 0, clipPath: fromSide },
        {
          opacity: 1, clipPath: toSide,
          stagger: 0.12, duration: 0.8, ease: 'power2.out',
          scrollTrigger: { trigger: panel, start: 'top 65%', toggleActions: 'play none none reverse' }
        }
      );
    }

    // Special treatment for "The Insight" panel - brief pin + scale
    const insightTitle = subTitle?.textContent?.trim().toLowerCase();
    if (insightTitle === 'the insight') {
      const insightParas = panel.querySelectorAll('.para-reveal');
      if (insightParas.length > 0) {
        gsap.fromTo(insightParas,
          { scale: 0.95 },
          {
            scale: 1,
            scrollTrigger: {
              trigger: panel,
              start: 'top 40%',
              end: 'bottom 60%',
              scrub: true,
            }
          }
        );
      }

      // Green left border that draws down
      gsap.fromTo(panel,
        { borderLeftWidth: '3px', borderLeftColor: '#169B62', borderLeftStyle: 'solid', borderImageSlice: 1, backgroundSize: '3px 0%' },
        {
          backgroundSize: '3px 100%',
          scrollTrigger: {
            trigger: panel,
            start: 'top 50%',
            end: 'bottom 50%',
            scrub: true,
          }
        }
      );
    }
  });

  // ── Brief: 3D card flips ──
  const briefSection = document.querySelector('[data-section="brief"]');
  if (briefSection) {
    // Section heading
    const briefHeading = briefSection.querySelector('h2');
    if (briefHeading) {
      const headingChars = splitText(briefHeading);
      gsap.set(briefHeading, { perspective: 800 });
      gsap.fromTo(headingChars,
        { opacity: 0, rotationX: -60 },
        {
          opacity: 1, rotationX: 0,
          stagger: 0.025, duration: 0.7, ease: 'power3.out',
          scrollTrigger: { trigger: briefSection, start: 'top 75%', toggleActions: 'play none none reverse' }
        }
      );
    }

    // Cards: 3D flip with perspective
    const briefCards = briefSection.querySelectorAll('.brief-card');
    briefCards.forEach((card: Element) => {
      gsap.set(card, { transformStyle: 'preserve-3d' });
      gsap.fromTo(card,
        { opacity: 0, rotationY: 60, transformOrigin: 'left center' },
        {
          opacity: 1, rotationY: 0, x: 0,
          duration: 0.8, ease: 'power3.out',
          scrollTrigger: { trigger: card, start: 'top 80%', toggleActions: 'play none none reverse' }
        }
      );
    });

    // Proposition: circle expand from center
    const proposition = briefSection.querySelector('.proposition-block');
    if (proposition) {
      gsap.fromTo(proposition,
        { opacity: 0, scale: 0.85, clipPath: 'circle(0% at 50% 50%)' },
        {
          opacity: 1, scale: 1, clipPath: 'circle(100% at 50% 50%)',
          duration: 1.0, ease: 'power2.out',
          scrollTrigger: { trigger: proposition, start: 'top 75%', toggleActions: 'play none none reverse' }
        }
      );
    }
  }

  // ── Manifesto: dramatic typography ──
  const manifestoSection = document.querySelector('[data-section="manifesto"]');
  if (manifestoSection) {
    const manifestoParas = manifestoSection.querySelectorAll('.manifesto-para');
    manifestoParas.forEach((para: Element, i: number) => {
      const isFirst = i === 0;
      const isLast = i === manifestoParas.length - 1;
      const hasBold = para.querySelector('strong');

      if (isFirst && hasBold) {
        // Bold opener: char-split, dramatic stagger, scale settle
        const chars = splitText(para);
        gsap.set(para, { perspective: 1000 });
        gsap.fromTo(chars,
          { opacity: 0, scale: 1.15, y: 20 },
          {
            opacity: 1, scale: 1, y: 0,
            stagger: 0.015, duration: 0.8, ease: 'power4.out',
            scrollTrigger: { trigger: para, start: 'top 75%', toggleActions: 'play none none reverse' }
          }
        );
      } else if (isLast) {
        // Final CTA: scale up, green accent line draws underneath
        gsap.fromTo(para,
          { opacity: 0, y: 30, scale: 0.9 },
          {
            opacity: 1, y: 0, scale: 1,
            duration: 1.0, ease: 'power2.out',
            scrollTrigger: { trigger: para, start: 'top 75%', toggleActions: 'play none none reverse' }
          }
        );
      } else {
        // Body paragraphs: skewY lean-in effect
        gsap.fromTo(para,
          { opacity: 0, y: 30, skewY: 2 },
          {
            opacity: 1, y: 0, skewY: 0,
            duration: 0.8, ease: 'power2.out',
            scrollTrigger: { trigger: para, start: 'top 75%', toggleActions: 'play none none reverse' }
          }
        );
      }
    });
  }

  // ── SVG Diagrams: draw-in animation with interactivity ──
  document.querySelectorAll('.diagram-container').forEach((container: Element) => {
    const nodes = container.querySelectorAll('.diagram-node');
    const edges = container.querySelectorAll('.diagram-edge');
    const labels = container.querySelectorAll('.diagram-label');

    // Set initial states
    gsap.set(nodes, { opacity: 0, scale: 0, transformOrigin: 'center center' });
    gsap.set(labels, { opacity: 0 });

    // Calculate stroke lengths for draw-in
    edges.forEach((edge: Element) => {
      const svgEdge = edge as SVGGeometryElement;
      if (svgEdge.getTotalLength) {
        const length = svgEdge.getTotalLength();
        gsap.set(edge, { strokeDasharray: length, strokeDashoffset: length });
      }
    });

    // Animated reveal timeline
    const diagTl = gsap.timeline({
      scrollTrigger: {
        trigger: container,
        start: 'top 70%',
        toggleActions: 'play none none reverse',
      }
    });

    diagTl.to(nodes, {
      opacity: 1, scale: 1,
      stagger: 0.12, duration: 0.5, ease: 'back.out(1.5)',
    });
    diagTl.to(edges, {
      strokeDashoffset: 0,
      stagger: 0.08, duration: 0.7, ease: 'power2.inOut',
    }, '-=0.3');
    diagTl.to(labels, {
      opacity: 1,
      stagger: 0.06, duration: 0.4,
    }, '-=0.3');

    // Hover interactivity: highlight connected elements
    nodes.forEach((node: Element) => {
      node.addEventListener('mouseenter', () => {
        const nodeId = node.getAttribute('data-node-id');
        if (!nodeId) return;

        // Dim all, highlight connected
        gsap.to(nodes, { opacity: 0.3, duration: 0.3 });
        gsap.to(labels, { opacity: 0.3, duration: 0.3 });
        gsap.to(node, { opacity: 1, scale: 1.1, duration: 0.3 });

        // Highlight edges connected to this node
        edges.forEach((edge: Element) => {
          const from = edge.getAttribute('data-from');
          const to = edge.getAttribute('data-to');
          if (from === nodeId || to === nodeId) {
            gsap.to(edge, { opacity: 1, strokeWidth: '+=1', duration: 0.3 });
            // Highlight connected node
            const connectedId = from === nodeId ? to : from;
            const connectedNode = container.querySelector(`[data-node-id="${connectedId}"]`);
            if (connectedNode) gsap.to(connectedNode, { opacity: 1, duration: 0.3 });
            const connectedLabel = container.querySelector(`[data-label-for="${connectedId}"]`);
            if (connectedLabel) gsap.to(connectedLabel, { opacity: 1, duration: 0.3 });
          }
        });

        // Show this node's label
        const label = container.querySelector(`[data-label-for="${nodeId}"]`);
        if (label) gsap.to(label, { opacity: 1, duration: 0.3 });
      });

      node.addEventListener('mouseleave', () => {
        // Reset all
        gsap.to(nodes, { opacity: 1, scale: 1, duration: 0.3 });
        gsap.to(edges, { opacity: 1, strokeWidth: '-=0', duration: 0.3 });
        gsap.to(labels, { opacity: 1, duration: 0.3 });
      });

      // Click to scroll to related section
      node.addEventListener('click', () => {
        const target = node.getAttribute('data-scroll-to');
        if (target) {
          const targetEl = document.querySelector(target);
          if (targetEl) {
            gsap.to(window, {
              duration: 1,
              scrollTo: { y: targetEl, offsetY: 50 },
              ease: 'power2.inOut',
            });
          }
        }
      });
    });
  });

  // ── Footer: subtle rise ──
  const footer = document.querySelector('[data-section="footer"]');
  if (footer) {
    // Footer accent line
    const footerAccent = footer.querySelector('.accent-line');
    if (footerAccent) {
      gsap.to(footerAccent, {
        scaleX: 1, duration: 0.8, ease: 'power2.inOut',
        scrollTrigger: { trigger: footer, start: 'top 90%', toggleActions: 'play none none none' }
      });
    }

    gsap.fromTo(footer.querySelectorAll('.footer-meta, .footer-credit'),
      { y: 20, opacity: 0 },
      {
        y: 0, opacity: 1,
        stagger: 0.15, duration: 0.8, ease: 'power2.out',
        scrollTrigger: { trigger: footer, start: 'top 90%', toggleActions: 'play none none reverse' }
      }
    );
  }

  // ── Section Navigation ──
  buildNav();
}

// ── Navigation Builder ──

function buildNav() {
  const nav = document.querySelector('.section-nav');
  if (!nav) return;
  const ul = nav.querySelector('.nav-dots');
  if (!ul) return;

  const sectionMap = [
    { selector: '[data-section="hero"]', label: 'Top', id: 'hero' },
    { selector: '[data-section="the-line"]', label: 'The Line', id: 'the-line' },
    { selector: '[data-section="insight"]', label: 'Insight', id: 'insight' },
    { selector: '[data-section="brief"]', label: 'Brief', id: 'brief' },
    { selector: '[data-section="manifesto"]', label: 'Manifesto', id: 'manifesto' },
  ];

  sectionMap.forEach(({ selector, label }) => {
    const el = document.querySelector(selector);
    if (!el) return;

    const li = document.createElement('li');
    li.innerHTML = `
      <button data-nav-target="${selector}" aria-label="Jump to ${label}">
        <span class="nav-dot"></span>
        <span class="nav-label">${label}</span>
      </button>`;
    ul.appendChild(li);

    // ScrollTrigger to highlight active dot
    ScrollTrigger.create({
      trigger: el,
      start: 'top center',
      end: 'bottom center',
      onEnter: () => setActiveNav(li),
      onEnterBack: () => setActiveNav(li),
    });
  });

  // Click handlers for smooth scroll
  ul.addEventListener('click', (e: Event) => {
    const btn = (e.target as Element).closest('button');
    if (!btn) return;
    const targetSelector = btn.getAttribute('data-nav-target');
    if (!targetSelector) return;
    const target = document.querySelector(targetSelector);
    if (target) {
      gsap.to(window, {
        duration: 1,
        scrollTo: { y: target, offsetY: 0 },
        ease: 'power2.inOut',
      });
    }
  });

  // Show nav after hero exits
  const hero = document.querySelector('[data-section="hero"]');
  if (hero) {
    ScrollTrigger.create({
      trigger: hero,
      start: 'bottom top',
      onEnter: () => nav.classList.add('visible'),
      onLeaveBack: () => nav.classList.remove('visible'),
    });
  }
}

// Auto-init when DOM is ready
if (typeof document !== 'undefined') {
  document.addEventListener('DOMContentLoaded', initScrollAnimations);
}
