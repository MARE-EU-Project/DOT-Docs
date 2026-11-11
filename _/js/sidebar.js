(() => {
  'use strict'
  const navigation = document.querySelector('.nav-container')
  const toggle = document.querySelector('.nav-toggle')
  if (!navigation || !toggle) return

  const root = document.documentElement
  const desktop = window.matchMedia('(min-width: 1024px)')
  let collapsed = false
  navigation.id ||= 'docs-navigation'
  toggle.type = 'button'
  toggle.setAttribute('aria-controls', navigation.id)
  root.classList.add('has-sidebar-toggle')

  const update = () => {
    const expanded = desktop.matches ? !collapsed : navigation.classList.contains('is-active')
    root.classList.toggle('is-sidebar-collapsed', desktop.matches && collapsed)
    toggle.setAttribute('aria-expanded', String(expanded))
    toggle.setAttribute('aria-label', expanded ? 'Hide navigation' : 'Show navigation')
    toggle.title = expanded ? 'Hide navigation' : 'Show navigation'
  }

  // Preserve the default Antora overlay on mobile; desktop collapses its column.
  toggle.addEventListener('click', event => {
    if (!desktop.matches) return
    event.stopImmediatePropagation()
    collapsed = !collapsed
    update()
  }, true)
  navigation.addEventListener('click', event => {
    const link = event.target.closest('a.nav-link')
    if (!link || desktop.matches || !navigation.classList.contains('is-active') ||
      event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
    if (link.origin === location.origin && link.pathname === location.pathname &&
      link.search === location.search && link.hash && (!link.target || link.target === '_self')) {
      // Let the browser follow the fragment after the native overlay closes.
      toggle.click()
    }
  })
  new MutationObserver(update).observe(navigation, {attributes: true, attributeFilter: ['class']})
  desktop.addEventListener('change', () => {
    navigation.querySelector('.nav')?.style.removeProperty('height')
    update()
  })
  update()
})()
