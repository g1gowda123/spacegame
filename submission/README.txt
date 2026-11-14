ORBIT & OUTPLAY — Exoplanet Survey
NASA Space Apps Challenge 2026 · Space Mission Design Game

Contents
  orbit_outplay_web.zip     Static WebGL 2 game (unzip, then serve over HTTP)
  orbit_outplay_demo.mp4    27.0 s demo video (1280x720, H.264, no audio track)
  orbit_outplay_deck.pdf    Alternative 7-slide deck
  PROJECT_PAGE_COPY.md      Text for the NASA Space Apps project page

Run the game locally
  unzip orbit_outplay_web.zip -d orbit_outplay
  cd orbit_outplay
  python3 -m http.server 8060
  open http://localhost:8060

Hosting
  The unzipped folder is a plain static site. Upload it to itch.io (HTML5),
  GitHub Pages, Netlify, Cloudflare Pages, or any HTTP(S) host.
  WebGL 2 is required. No server-side code or build step.

Data
  NASA Exoplanet Archive — Planetary Systems Composite Parameters (PSCompPars).
  Derived game values are documented in the project README and SUBMISSION copy.
