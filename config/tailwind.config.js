// Tailwind CSS v4 uses CSS-first configuration via @theme in CSS files.
// This config file supplements the CSS with additional JavaScript-level
// extensions that can't be expressed in CSS alone.

const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  theme: {
    extend: {
      // Font family — mirrors --font-sans in CSS
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
        display: ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
        body: ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
      },

      // Custom background colors (3-layer depth system)
      colors: {
        'bg-base': '#161619',
        'bg-surface': '#161619',
        'bg-elevated': '#1a1a1e',
        'bg-card': '#1e1e22',
        'bg-dropdown': '#222226',
      },

      // Custom text colors
      colors: {
        content: '#f0f0f0',
        'content-secondary': '#bbb',
        'content-muted': '#888',
      },

      // Status colors
      success: '#34d399',
      warning: '#fbbf24',
      error: '#ef4444',
      info: '#60a5fa',

      // Agent color
      agent: '#fbbf24',

      // Project colors
      project: {
        red: '#ef4444',
        green: '#34d399',
        amber: '#fbbf24',
        blue: '#60a5fa',
        purple: '#a78bfa',
      },

      // Animation utilities — reference @theme values in CSS
      animation: {
        'fade-up': 'fadeUp 0.3s ease both',
        'slide-in': 'slideIn 0.2s ease both',
        'drop-in': 'dropIn 0.12s ease both',
        'cmd-in': 'cmdIn 0.2s ease both',
        'pulse-dot': 'pulse 2s ease-in-out infinite',
        'dot-bounce': 'dotBounce 1s ease infinite',
      },

      // Keyframes are defined in CSS via @keyframes
      // This config references them for Tailwind utility generation
    },
  },
  plugins: [],
}
