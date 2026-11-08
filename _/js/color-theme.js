/* Run before stylesheets so the saved preference applies before first paint. */
(() => {
  const key = 'dot-docs-color-theme'
  const root = document.documentElement
  const media = typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-color-scheme: dark)') : null
  const normalize = (value) => value === 'light' || value === 'dark' ? value : 'system'
  const read = () => {
    try { return normalize(window.localStorage.getItem(key)) } catch { return 'system' }
  }
  let preference = read()
  let control

  const apply = () => {
    root.dataset.theme = preference === 'system' ? (media?.matches ? 'dark' : 'light') : preference
    root.dataset.themePreference = preference
    if (control) control.value = root.dataset.theme
  }

  apply()
  if (media?.addEventListener) media.addEventListener('change', apply)
  else if (media?.addListener) media.addListener(apply)

  window.addEventListener('storage', (event) => {
    if (event.key !== key && event.key !== null) return
    preference = read()
    apply()
  })

  const bind = () => {
    control = document.getElementById('color-theme')
    if (!control) return
    apply()
    control.addEventListener('change', () => {
      preference = normalize(control.value)
      apply()
      try {
        if (preference === 'system') window.localStorage.removeItem(key)
        else window.localStorage.setItem(key, preference)
      } catch { /* A blocked preference store must not disable the current page's control. */ }
    })
    control.closest('.theme-control').hidden = false
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind, {once: true})
  else bind()
})()
