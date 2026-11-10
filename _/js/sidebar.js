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
  new MutationObserver(update).observe(navigation, {attributes: true, attributeFilter: ['class']})
  desktop.addEventListener('change', () => {
    navigation.querySelector('.nav')?.style.removeProperty('height')
    update()
  })
  update()
})()
